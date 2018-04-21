// WRTextView/webrender-text-view/src/lib.rs
//
// Copyright © 2018 The Pathfinder Project Developers.
//
// Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
// http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
// <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
// option. This file may not be copied, modified, or distributed
// except according to those terms.

extern crate app_units;
extern crate euclid;
extern crate gleam;
extern crate libc;
extern crate pilcrow;
extern crate webrender;
extern crate webrender_api;

use app_units::Au;
use euclid::{Length, Transform2D, Vector2D};
use gleam::gl::{self, Gl};
use libc::c_char;
use pilcrow::{Color, FontFaceId, FontId, Format, Frame, Framesetter, ParagraphBuf, ParagraphStyle};
use pilcrow::{Section, TextBuf};
use std::cmp::{self, Ordering};
use std::collections::HashMap;
use std::collections::hash_map::Entry;
use std::f32;
use std::ffi::CString;
use std::fs::File;
use std::io::Read;
use std::mem;
use std::ops::Range;
use std::os::raw::c_void;
use std::rc::Rc;
use std::sync::mpsc::{self, Receiver, Sender};
use webrender::{Renderer, RendererOptions};
use webrender_api::{BuiltDisplayList, ColorF, DeviceIntPoint, DeviceIntSize, DevicePixel};
use webrender_api::{DevicePoint, DeviceRect, DeviceUintPoint, DeviceUintRect, DeviceUintSize};
use webrender_api::{DisplayListBuilder, DocumentId, Epoch, FontInstanceKey, FontKey};
use webrender_api::{GlyphInstance, IdNamespace, LayoutPoint, LayoutPrimitiveInfo, LayoutPixel};
use webrender_api::{LayoutRect, LayoutSize, LineOrientation, LineStyle, MixBlendMode};
use webrender_api::{NativeFontHandle, NormalBorder, PipelineId, RenderApi, RenderApiSender};
use webrender_api::{RenderNotifier, ResourceUpdates, ScrollPolicy, Transaction};
use webrender_api::{TransformStyle, ZoomFactor};

pub mod ffi;

const BLACK_COLOR: ColorF = ColorF {
    r: 0.0,
    g: 0.0,
    b: 0.0,
    a: 1.0,
};

const DEFAULT_SELECTION_BACKGROUND_COLOR: ColorF = ColorF {
    r: 0.75,
    g: 0.75,
    b: 0.75,
    a: 1.0,
};

const PIPELINE_ID: PipelineId = PipelineId(0, 0);

pub type GetProcAddressFn = unsafe extern "C" fn(*const c_char) -> *const c_void;

type WrDisplayList = (PipelineId, LayoutSize, BuiltDisplayList);

type FontKeyMap = HashMap<FontFaceId, (FontKey, HashMap<FontId, FontInstanceKey>)>;

pub struct View {
    text: TextBuf,
    gl: Rc<Gl>,
    available_width: Length<f32, LayoutPixel>,
    viewport_size: DeviceUintSize,
    transform: Transform2D<f32>,
    section: Section,
    selection: Option<Range<Location>>,
    selection_background_color: ColorF,

    wr_renderer: Renderer,
    wr_sender: RenderApiSender,
    wr_sender_api: RenderApi,
    wr_document_id: DocumentId,
    wr_display_list: WrDisplayList,
    wr_new_frame_ready_rx: Receiver<()>,
}

impl View {
    pub fn new(text: TextBuf,
               viewport_size: &DeviceUintSize,
               available_width: Length<f32, LayoutPixel>,
               get_proc_address: GetProcAddressFn)
               -> View {
        let gl = unsafe {
            gl::GlFns::load_with(|symbol| {
                let symbol = CString::new(symbol).unwrap();
                get_proc_address(symbol.as_ptr())
            })
        };

        let transform = Transform2D::identity();

        let (wr_new_frame_ready_tx, wr_new_frame_ready_rx) = mpsc::channel();
        let wr_options = RendererOptions::default();
        let notifier = Box::new(Notifier::new(wr_new_frame_ready_tx));
        let (renderer, sender) = Renderer::new(gl.clone(), notifier, wr_options).unwrap();
        let sender_api = sender.create_api();

        let available_layout_size = LayoutSize::new(available_width.get(), 1000000.0);
        let available_device_size = DeviceUintSize::new(available_layout_size.width as u32,
                                                        available_layout_size.height as u32);
        let document_id = sender_api.add_document(available_device_size, 0);

        let mut display_list_builder = init_display_list_builder(&available_layout_size);
        let mut resource_updates = ResourceUpdates::new();
        let section = layout_text(&text, available_width);
        let selection = None;
        let selection_background_color = DEFAULT_SELECTION_BACKGROUND_COLOR;
        build_display_list(&mut display_list_builder,
                           &sender_api,
                           &mut resource_updates,
                           &section,
                           &selection,
                           &selection_background_color);
        let display_list = finalize_display_list(display_list_builder);

        let mut transaction = Transaction::new();
        transaction.update_resources(resource_updates);
        sender_api.send_transaction(document_id, transaction);

        View {
            text,
            gl,
            available_width,
            viewport_size: *viewport_size,
            transform,
            section,
            selection,
            selection_background_color,

            wr_renderer: renderer,
            wr_sender: sender,
            wr_sender_api: sender_api,
            wr_document_id: document_id,
            wr_display_list: display_list,
            wr_new_frame_ready_rx,
        }
    }

    pub fn layout_size(&self) -> LayoutSize {
        LayoutSize::new(self.available_width.get(), match self.section.frames().last() {
            None => 0.0,
            Some(frame) => {
                match frame.lines().last() {
                    None => 0.0,
                    Some(line) => line.origin.y + line.typographic_bounds().descent,
                }
            }
        })
    }

    pub fn repaint(&mut self) {
        let mut transaction = Transaction::new();
        transaction.set_display_list(Epoch(0),
                                     None,
                                     self.layout_size(),
                                     self.wr_display_list.clone(),
                                     true);
        transaction.set_root_pipeline(PIPELINE_ID);
        let inner_rect = DeviceUintRect::new(DeviceUintPoint::zero(), self.viewport_size);
        transaction.set_window_parameters(self.viewport_size, inner_rect, 1.0);
        transaction.set_pan(DeviceIntPoint::new(self.transform.m31 as i32,
                                                self.transform.m32 as i32));
        transaction.set_pinch_zoom(ZoomFactor::new(self.transform.m11));
        transaction.generate_frame();
        self.wr_sender_api.send_transaction(self.wr_document_id, transaction);
        self.wr_new_frame_ready_rx.recv().unwrap();

        self.wr_renderer.update();
        self.wr_renderer.render(self.viewport_size).unwrap();
    }

    pub fn get_mouse_cursor(&self, point: &LayoutPoint) -> MouseCursor {
        let point = point.to_untyped();
        match self.section
                  .frame_at_point(&point)
                  .and_then(|frame| frame.line_index_at_point(&point)) {
            None => MouseCursor::Default,
            Some(_) => MouseCursor::Text,
        }
    }

    pub fn available_width(&self) -> Length<f32, LayoutPixel> {
        self.available_width
    }

    pub fn set_available_width(&mut self, available_width: Length<f32, LayoutPixel>) {
        self.available_width = available_width;
        self.layout();
    }

    pub fn set_translation(&mut self, origin: &DevicePoint) {
        self.transform.m31 = -origin.x;
        self.transform.m32 = -origin.y;
    }

    pub fn set_viewport_size(&mut self, viewport_size: &DeviceUintSize) {
        self.viewport_size = *viewport_size
    }

    pub fn set_scale(&mut self, factor: f32) {
        self.transform.m11 = factor;
        self.transform.m22 = factor;
    }

    pub fn set_selection_background_color(&mut self, color: Color) {
        self.selection_background_color = color.to_colorf()
    }

    pub fn select_all(&mut self) {
        {
            let paragraphs = self.text.paragraphs();
            let paragraph_index = match paragraphs.len() {
                0 => 0,
                paragraph_count => paragraph_count - 1,
            };
            let character_index = match paragraphs.get(paragraph_index) {
                None => 0,
                Some(paragraph) => paragraph.char_len(),
            };
            let end = Location::new(paragraph_index, character_index);
            self.selection = Some(Location::beginning()..end);
        }

        eprintln!("select_all(): new selection={:?}", self.selection);
        self.rebuild_display_list();
    }

    fn layout(&mut self) {
        let available_width = self.available_width;
        self.section = layout_text(&self.text, available_width);

        self.rebuild_display_list();
    }

    fn rebuild_display_list(&mut self) {
        let available_layout_size = LayoutSize::new(self.available_width.get(), 1000000.0);
        let mut display_list_builder = init_display_list_builder(&available_layout_size);
        let mut resource_updates = ResourceUpdates::new();
        build_display_list(&mut display_list_builder,
                           &self.wr_sender_api,
                           &mut resource_updates,
                           &self.section,
                           &self.selection,
                           &self.selection_background_color);
        self.wr_display_list = finalize_display_list(display_list_builder);

        let mut transaction = Transaction::new();
        transaction.update_resources(resource_updates);
        self.wr_sender_api.send_transaction(self.wr_document_id, transaction);
    }
}

#[derive(Clone, Copy, PartialEq, PartialOrd, Debug)]
pub struct Location {
    pub paragraph_index: usize,
    pub character_index: usize,
}

impl Location {
    #[inline]
    pub fn new(paragraph_index: usize, character_index: usize) -> Location {
        Location {
            paragraph_index,
            character_index,
        }
    }

    #[inline]
    pub fn beginning() -> Location {
        Location::new(0, 0)
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

trait LocationRangeExt {
    fn char_range_for_paragraph(&self, paragraph_index: usize, paragraph_char_len: usize)
                                -> Option<Range<usize>>;
}

impl LocationRangeExt for Range<Location> {
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

#[derive(Clone, Copy, PartialEq)]
#[repr(C)]
pub enum MouseCursor {
    Default = 0,
    Text,
    Pointer,
}

fn init_display_list_builder(layout_size: &LayoutSize) -> DisplayListBuilder {
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
    display_list_builder
}

fn finalize_display_list(mut display_list_builder: DisplayListBuilder) -> WrDisplayList {
    display_list_builder.pop_stacking_context();
    display_list_builder.finalize()
}

fn load_file(name: &str) -> Vec<u8> {
    let mut file = File::open(name).unwrap();
    let mut buffer = vec![];
    file.read_to_end(&mut buffer).unwrap();
    buffer
}

fn layout_text(text: &TextBuf, available_width: Length<f32, LayoutPixel>) -> Section {
    let framesetter = Framesetter::new(text);
    let layout_size = LayoutSize::new(available_width.get(), 1000000.0);
    let layout_rect = LayoutRect::new(LayoutPoint::zero(), layout_size);
    framesetter.layout_in_rect(&layout_rect.to_untyped())
}

fn build_display_list(display_list_builder: &mut DisplayListBuilder,
                      render_api: &RenderApi,
                      resource_updates: &mut ResourceUpdates,
                      section: &Section,
                      selection: &Option<Range<Location>>,
                      selection_background_color: &ColorF) {
    let mut font_keys = HashMap::new();

    for (frame_index, frame) in section.frames().iter().enumerate() {
        let frame_char_len = frame.char_len();

        for line in frame.lines() {
            let typo_bounds = line.typographic_bounds();
            let line_origin = LayoutPoint::from_untyped(&line.origin);
            let line_size = LayoutSize::new(typo_bounds.width,
                                            typo_bounds.ascent + typo_bounds.descent);
            let line_bounds = LayoutRect::new(LayoutPoint::new(line_origin.x,
                                                               line_origin.y - typo_bounds.ascent),
                                              line_size);
            let line_layout_primitive_info = LayoutPrimitiveInfo::new(line_bounds);

            let selected_char_range = (*selection).clone().and_then(|selection| {
                selection.char_range_for_paragraph(frame_index, frame_char_len)
            }).map(|char_range| char_range.intersect(&line.char_range()));

            if let Some(selected_char_range) = selected_char_range {
                let start_offset = line.inline_position_for_char_index(selected_char_range.start);
                let end_offset = line.inline_position_for_char_index(selected_char_range.end);
                let selection_bounds =
                    LayoutRect::new(LayoutPoint::new(line_bounds.origin.x + start_offset,
                                                     line_bounds.origin.y),
                                    LayoutSize::new(end_offset - start_offset, line_size.height));
                let layout_primitive_info = LayoutPrimitiveInfo::new(selection_bounds);
                display_list_builder.push_rect(&layout_primitive_info, *selection_background_color)
            }

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
                                                                    &mut font_keys,
                                                                    &render_api,
                                                                    resource_updates);

                if let Some(computed_font_instance_key) = computed_style.font_instance_key {
                    display_list_builder.push_text(&line_layout_primitive_info,
                                                   &glyphs,
                                                   computed_font_instance_key,
                                                   computed_style.color.unwrap_or(BLACK_COLOR),
                                                   None);
                }
            }
        }

        add_frame_decorations(display_list_builder, &frame)
    }
}

fn add_frame_decorations(display_list_builder: &mut DisplayListBuilder, frame: &Frame) {
    match frame.style() {
        ParagraphStyle::Plain => {}
        ParagraphStyle::Rule => {
            let frame_bounds = frame.bounds();
            let origin = LayoutPoint::new(frame_bounds.origin.x, frame_bounds.max_y() - 1.0);
            let size = LayoutSize::new(frame_bounds.size.width, 1.0);
            let layout_primitive_info = LayoutPrimitiveInfo::new(LayoutRect::new(origin, size));
            display_list_builder.push_line(&layout_primitive_info,
                                           1.0,
                                           LineOrientation::Horizontal,
                                           &BLACK_COLOR,
                                           LineStyle::Solid)
        }
    }
}

struct Notifier {
    tx: Sender<()>,
}

impl Notifier {
    fn new(tx: Sender<()>) -> Notifier {
        Notifier {
            tx,
        }
    }
}

impl RenderNotifier for Notifier {
    fn clone(&self) -> Box<RenderNotifier> {
        Box::new(Notifier::new(self.tx.clone()))
    }

    fn wake_up(&self) {}

    fn new_document_ready(&self, _: DocumentId, _: bool, _: bool) {
        drop(self.tx.send(()));
    }
}

struct ComputedStyle {
    font_instance_key: Option<FontInstanceKey>,
    color: Option<ColorF>,
}

impl ComputedStyle {
    pub fn from_formatting(formatting: Vec<Format>,
                           font_keys: &mut FontKeyMap,
                           render_api: &RenderApi,
                           resource_updates: &mut ResourceUpdates)
                           -> ComputedStyle {
        let mut computed_style = ComputedStyle {
            font_instance_key: None,
            color: None,
        };

        for format in formatting.into_iter().rev() {
            if let Some(font) = format.font() {
                if computed_style.font_instance_key.is_none() {
                    let &mut (font_key,
                              ref mut font_instance_keys) = font_keys.entry(font.face_id())
                                                                                .or_insert_with(|| {
                        let font_key = render_api.generate_font_key();
                        // FIXME(pcwalton): Workaround for version mismatch of `core-graphics`!
                        let native_font = unsafe {
                            NativeFontHandle(mem::transmute(font.native_font().copy_to_CGFont()))
                        };
                        resource_updates.add_native_font(font_key, native_font);
                        (font_key, HashMap::new())
                    });
                    computed_style.font_instance_key = Some(*font_instance_keys.entry(font.id())
                                                                               .or_insert_with(|| {
                        let font_instance_key = render_api.generate_font_instance_key();
                        let font_size = Au::from_f32_px(font.size());
                        resource_updates.add_font_instance(font_instance_key,
                                                           font_key,
                                                           font_size,
                                                           None,
                                                           None,
                                                           vec![]);
                        font_instance_key
                    }));
                }
            }

            if let Some(color) = format.color() {
                if computed_style.color.is_none() {
                    computed_style.color = Some(color.to_colorf())
                }
            }
        }

        computed_style
    }
}

trait ColorExt {
    fn to_colorf(&self) -> ColorF;
}

impl ColorExt for Color {
    fn to_colorf(&self) -> ColorF {
        ColorF {
            r: self.r_f32(),
            g: self.g_f32(),
            b: self.b_f32(),
            a: self.a_f32(),
        }
    }
}
