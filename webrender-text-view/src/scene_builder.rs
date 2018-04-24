// WRTextView/webrender-text-view/src/scene_builder.rs
//
// Copyright © 2018 The Pathfinder Project Developers.
//
// Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
// http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
// <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
// option. This file may not be copied, modified, or distributed
// except according to those terms.

use pilcrow::{Frame, Line, ParagraphStyle, Run, Section};
use std::cmp;
use std::collections::HashMap;
use std::ops::Range;
use webrender_api::{ColorF, DisplayListBuilder, FontRenderMode, GlyphInstance, GlyphOptions, LayoutPrimitiveInfo, LayoutPoint};
use webrender_api::{LayoutRect, LayoutSize, LineOrientation, LineStyle, MixBlendMode, RenderApi};
use webrender_api::{ResourceUpdates, ScrollPolicy, TransformStyle};
use {ComputedStyle, FontInstanceInfo, PIPELINE_ID, TextLocation, WrDisplayList};

const BLACK_COLOR: ColorF = ColorF {
    r: 0.0,
    g: 0.0,
    b: 0.0,
    a: 1.0,
};

pub struct SceneBuilder {
    display_list_builder: DisplayListBuilder,
    selection: Option<Range<TextLocation>>,
    active_link_id: Option<usize>,
    selection_background_color: ColorF,
}

impl SceneBuilder {
    pub fn new(layout_size: &LayoutSize,
               selection: &Option<Range<TextLocation>>,
               active_link_id: &Option<usize>,
               selection_background_color: &ColorF)
               -> SceneBuilder {
        let mut display_list_builder = DisplayListBuilder::new(PIPELINE_ID, *layout_size);
        let root_stacking_context_bounds = LayoutRect::new(LayoutPoint::zero(), *layout_size);
        let root_layout_primitive_info = LayoutPrimitiveInfo::new(root_stacking_context_bounds);
        display_list_builder.push_stacking_context(&root_layout_primitive_info,
                                                   None,
                                                   ScrollPolicy::Scrollable,
                                                   None,
                                                   TransformStyle::Flat,
                                                   None,
                                                   MixBlendMode::Normal,
                                                   vec![]);
        SceneBuilder {
            display_list_builder,
            selection: (*selection).clone(),
            active_link_id: *active_link_id,
            selection_background_color: *selection_background_color,
        }
    }

    pub fn finalize(mut self) -> WrDisplayList {
        self.display_list_builder.pop_stacking_context();
        self.display_list_builder.finalize()
    }

    pub fn build_display_list(&mut self,
                              render_api: &RenderApi,
                              resource_updates: &mut ResourceUpdates,
                              section: &Section) {
        let mut font_keys = HashMap::new();

        for (frame_index, frame) in section.frames().iter().enumerate() {
            let frame_char_len = frame.char_len();

            for line in frame.lines() {
                if self.selection.is_some() {
                    self.add_selection_background_for_line_if_necessary(frame_index,
                                                                        frame_char_len,
                                                                        &line)
                }

                let typo_bounds = line.typographic_bounds();
                let line_origin = LayoutPoint::from_untyped(&line.origin);
                let line_size = LayoutSize::new(typo_bounds.width,
                                                typo_bounds.ascent + typo_bounds.descent);
                let line_bounds = LayoutRect::new(LayoutPoint::new(line_origin.x,
                                                                line_origin.y - typo_bounds.ascent),
                                                line_size);
                let line_layout_primitive_info = LayoutPrimitiveInfo::new(line_bounds);

                for run in line.runs() {
                    let mut glyphs = vec![];
                    for (index, position) in run.glyphs()
                                                .into_iter()
                                                .zip(run.positions().into_iter()) {
                        glyphs.push(GlyphInstance {
                            index: index as u32,
                            point: LayoutPoint::from_untyped(&position) + line_origin.to_vector(),
                        })
                    }

                    let computed_style = ComputedStyle::from_formatting(run.formatting(),
                                                                        &self.active_link_id,
                                                                        &mut font_keys,
                                                                        &render_api,
                                                                        resource_updates);

                    if let Some((computed_font_face_id, computed_font_id)) = computed_style.font {
                        let font_instance_info = font_keys.get(&computed_font_face_id)
                                                          .unwrap()
                                                          .instance_infos
                                                          .get(&computed_font_id)
                                                          .unwrap();

                        let text_color = computed_style.color.unwrap_or(BLACK_COLOR);
                        let glyph_options = GlyphOptions {
                            render_mode: FontRenderMode::Subpixel,
                            ..GlyphOptions::default()
                        };
                        self.display_list_builder.push_text(&line_layout_primitive_info,
                                                            &glyphs,
                                                            font_instance_info.key.clone(),
                                                            text_color,
                                                            Some(glyph_options));

                        if computed_style.underline {
                            let origin = match glyphs.get(0) {
                                None => line_origin,
                                Some(ref glyph) => glyph.point,
                            };
                            self.add_underline(&font_instance_info, &run, &origin, &text_color);
                        }
                    }
                }
            }

            self.add_frame_decorations(&frame)
        }
    }

    fn add_selection_background_for_line_if_necessary(&mut self,
                                                      frame_index: usize,
                                                      frame_char_len: usize,
                                                      line: &Line) {
        let typo_bounds = line.typographic_bounds();
        let line_origin = LayoutPoint::from_untyped(&line.origin);
        let line_size = LayoutSize::new(typo_bounds.width,
                                        typo_bounds.ascent + typo_bounds.descent);
        let line_bounds = LayoutRect::new(LayoutPoint::new(line_origin.x,
                                                        line_origin.y - typo_bounds.ascent),
                                          line_size);

        let selection = self.selection.clone().unwrap();
        let selected_char_range = match selection.char_range_for_paragraph(frame_index,
                                                                           frame_char_len) {
            None => return,
            Some(char_range) => char_range.intersect(&line.char_range()),
        };

        let start_offset = line.inline_position_for_char_index(selected_char_range.start);
        let end_offset = line.inline_position_for_char_index(selected_char_range.end);
        let selection_bounds =
            LayoutRect::new(LayoutPoint::new(line_bounds.origin.x + start_offset,
                                             line_bounds.origin.y),
                            LayoutSize::new(end_offset - start_offset, line_size.height));
        let layout_primitive_info = LayoutPrimitiveInfo::new(selection_bounds);
        self.display_list_builder.push_rect(&layout_primitive_info,
                                            self.selection_background_color)
    }

    fn add_underline(&mut self,
                     font_instance_info: &FontInstanceInfo,
                     run: &Run,
                     run_origin: &LayoutPoint,
                     color: &ColorF) {
        let typographic_bounds = run.typographic_bounds();
        let origin = LayoutPoint::new(run_origin.x,
                                      run_origin.y - font_instance_info.underline_position);
        let size = LayoutSize::new(typographic_bounds.width,
                                   font_instance_info.underline_thickness);
        let layout_primitive_info = LayoutPrimitiveInfo::new(LayoutRect::new(origin, size));
        self.display_list_builder.push_line(&layout_primitive_info,
                                            size.height,
                                            LineOrientation::Horizontal,
                                            color,
                                            LineStyle::Solid);
        eprintln!("added underline: origin={:?} size={:?}", origin, size);
    }

    fn add_frame_decorations(&mut self, frame: &Frame) {
        match frame.style() {
            ParagraphStyle::Plain => {}
            ParagraphStyle::Rule => {
                let frame_bounds = frame.bounds();
                let origin = LayoutPoint::new(frame_bounds.origin.x, frame_bounds.max_y() - 1.0);
                let size = LayoutSize::new(frame_bounds.size.width, 1.0);
                let rect = LayoutRect::new(origin, size);
                let layout_primitive_info = LayoutPrimitiveInfo::new(rect);
                self.display_list_builder.push_line(&layout_primitive_info,
                                                    1.0,
                                                    LineOrientation::Horizontal,
                                                    &BLACK_COLOR,
                                                    LineStyle::Solid)
            }
        }
    }
}

trait RangeExt {
    fn intersect(&self, other: &Self) -> Self;
}

impl RangeExt for Range<usize> {
    fn intersect(&self, other: &Range<usize>) -> Range<usize> {
        cmp::max(self.start, other.start)..cmp::min(self.end, other.end)
    }
}

trait TextLocationRangeExt {
    fn char_range_for_paragraph(&self, paragraph_index: usize, paragraph_char_len: usize)
                                -> Option<Range<usize>>;
}

impl TextLocationRangeExt for Range<TextLocation> {
    fn char_range_for_paragraph(&self, paragraph_index: usize, paragraph_char_len: usize)
                                -> Option<Range<usize>> {
        if paragraph_index < self.start.paragraph_index ||
                paragraph_index > self.end.paragraph_index {
            return None
        }

        let start_char_index = if self.start.paragraph_index == paragraph_index {
            self.start.character_index
        } else {
            0
        };
        let end_char_index = if self.end.paragraph_index == paragraph_index {
            self.end.character_index
        } else {
            paragraph_char_len
        };
        Some(start_char_index..end_char_index)
    }
}
