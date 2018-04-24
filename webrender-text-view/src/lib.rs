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
extern crate core_text;
extern crate euclid;
extern crate gleam;
extern crate libc;
extern crate pilcrow;
extern crate webrender;
extern crate webrender_api;

#[macro_use]
extern crate lazy_static;

use app_units::Au;
use core_text::font as ct_font;
use euclid::{Length, Point2D, Transform2D, TypedScale, TypedSideOffsets2D};
use euclid::{TypedTransform2D, TypedVector2D};
use gleam::gl;
use libc::c_char;
use pilcrow::{Color, FontFaceId, FontId, Format, Framesetter, Section, TextBuf, TextLocation};
use std::collections::HashMap;
use std::collections::hash_map::Entry;
use std::f32;
use std::ffi::CString;
use std::mem;
use std::ops::Range;
use std::os::raw::c_void;
use std::sync::mpsc::{self, Receiver, Sender};
use webrender::{Renderer, RendererOptions};
use webrender_api::{BuiltDisplayList, ColorF, DeviceIntPoint, DevicePixel, DevicePoint, DeviceUintPoint};
use webrender_api::{DeviceUintRect, DeviceUintSize, DocumentId, Epoch, FontInstanceKey, FontKey};
use webrender_api::{LayoutPoint, LayoutPixel, LayoutRect, LayoutSize, NativeFontHandle};
use webrender_api::{PipelineId, RenderApi, RenderNotifier, ResourceUpdates, Transaction};
use webrender_api::{ZoomFactor};

use scene_builder::SceneBuilder;

pub mod ffi;
mod scene_builder;

const DEFAULT_SELECTION_BACKGROUND_COLOR: ColorF = ColorF {
    r: 0.75,
    g: 0.75,
    b: 0.75,
    a: 1.0,
};

const DEFAULT_LINK_COLOR: ColorF = ColorF {
    r: 0.0,
    g: 0.0,
    b: 1.0,
    a: 1.0,
};

const DEFAULT_LINK_ACTIVE_COLOR: ColorF = ColorF {
    r: 1.0,
    g: 0.0,
    b: 0.0,
    a: 1.0,
};

lazy_static! {
    static ref DEFAULT_PAGE_MARGIN: TypedSideOffsets2D<f32, LayoutPixel> = {
        TypedSideOffsets2D::new(0.0, 6.0, 0.0, 6.0)
    };
}

pub const PIPELINE_ID: PipelineId = PipelineId(0, 0);

pub type GetProcAddressFn = unsafe extern "C" fn(*const c_char) -> *const c_void;

type WrDisplayList = (PipelineId, LayoutSize, BuiltDisplayList);

type FontKeyMap = HashMap<FontFaceId, FontInfo>;

pub struct View {
    text: TextBuf,
    available_width: Length<f32, LayoutPixel>,
    viewport_size: DeviceUintSize,
    device_pixel_ratio: TypedScale<f32, LayoutPixel, DevicePixel>,
    transform: TypedTransform2D<f32, LayoutPixel, LayoutPixel>,
    section: Section,

    page_margin: TypedSideOffsets2D<f32, LayoutPixel>,
    selection_background_color: ColorF,

    selection: Option<Range<TextLocation>>,
    active_link_id: Option<usize>,

    wr_renderer: Renderer,
    wr_sender_api: RenderApi,
    wr_document_id: DocumentId,
    wr_display_list: WrDisplayList,
    wr_new_frame_ready_rx: Receiver<()>,
}

impl View {
    pub fn new(text: TextBuf,
               viewport_size: &DeviceUintSize,
               device_pixel_ratio: TypedScale<f32, LayoutPixel, DevicePixel>,
               available_width: Length<f32, LayoutPixel>,
               get_proc_address: GetProcAddressFn)
               -> View {
        let gl = unsafe {
            gl::GlFns::load_with(|symbol| {
                let symbol = CString::new(symbol).unwrap();
                get_proc_address(symbol.as_ptr())
            })
        };

        let transform = TypedTransform2D::identity();
        let wr_options = RendererOptions {
            enable_subpixel_aa: true,
            ..RendererOptions::default()
        };

        let (wr_new_frame_ready_tx, wr_new_frame_ready_rx) = mpsc::channel();
        let notifier = Box::new(Notifier::new(wr_new_frame_ready_tx));
        let (renderer, sender) = Renderer::new(gl.clone(), notifier, wr_options).unwrap();
        let sender_api = sender.create_api();

        let available_layout_size = LayoutSize::new(available_width.get(), 1000000.0);
        let available_device_size = DeviceUintSize::new(available_layout_size.width as u32,
                                                        available_layout_size.height as u32);
        let document_id = sender_api.add_document(available_device_size, 0);

        let page_margin = *DEFAULT_PAGE_MARGIN;
        let section = layout_text(&text, available_width, &page_margin);

        let (selection, active_link_id) = (None, None);
        let selection_background_color = DEFAULT_SELECTION_BACKGROUND_COLOR;
        let mut scene_builder = SceneBuilder::new(&available_layout_size,
                                                  &selection,
                                                  &active_link_id,
                                                  &selection_background_color);
        let mut resource_updates = ResourceUpdates::new();
        scene_builder.build_display_list(&sender_api, &mut resource_updates, &section);
        let display_list = scene_builder.finalize();

        let mut transaction = Transaction::new();
        transaction.update_resources(resource_updates);
        sender_api.send_transaction(document_id, transaction);

        View {
            text,
            available_width,
            device_pixel_ratio,
            viewport_size: *viewport_size,
            transform,
            section,

            page_margin: *DEFAULT_PAGE_MARGIN,
            selection_background_color,

            selection,
            active_link_id,

            wr_renderer: renderer,
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
        transaction.set_window_parameters(self.viewport_size,
                                          inner_rect,
                                          self.device_pixel_ratio.get());
        let pan_vector = LayoutPoint::new(self.transform.m31, self.transform.m32);
        let pan_vector = pan_vector * self.device_pixel_ratio;
        transaction.set_pan(DeviceIntPoint::new(pan_vector.x as i32, pan_vector.y as i32));
        transaction.set_pinch_zoom(ZoomFactor::new(self.transform.m11));
        transaction.generate_frame();
        self.wr_sender_api.send_transaction(self.wr_document_id, transaction);
        self.wr_new_frame_ready_rx.recv().unwrap();

        self.wr_renderer.update();
        self.wr_renderer.render(self.viewport_size).unwrap();
    }

    pub fn get_mouse_cursor(&self, point: &LayoutPoint) -> MouseCursor {
        let HitTestResult {
            point,
            frame_index,
            line_index,
        } = match self.hit_test_point(point) {
            None => return MouseCursor::Default,
            Some(hit_test_result) => hit_test_result,
        };
        let frame = &self.section.frames()[frame_index];
        let lines = frame.lines();
        let line = &lines[line_index];
        let char_index = match line.char_index_for_position(&point.to_untyped()) {
            None => return MouseCursor::Text,
            Some(char_index) => char_index,
        };
        let runs = line.runs();
        let run = match runs.iter().find(|run| run.char_range().has(char_index)) {
            None => return MouseCursor::Text,
            Some(run) => run,
        };
        for format in run.formatting().iter() {
            if format.link().is_some() {
                return MouseCursor::Pointer
            }
        }
        MouseCursor::Text
    }

    pub fn mouse_down(&mut self, point: &LayoutPoint, kind: MouseEventKind) {
        let mut active_link_id = None;
        let mut dirty = false;

        {
            let HitTestResult {
                point,
                frame_index,
                line_index,
            } = match self.hit_test_point(point) {
                None => return,
                Some(hit_test_result) => hit_test_result,
            };
            let frame = &self.section.frames()[frame_index];
            let lines = frame.lines();
            let line = &lines[line_index];
            let char_index = match line.char_index_for_position(&point.to_untyped()) {
                None => return,
                Some(char_index) => char_index,
            };

            if kind == MouseEventKind::LeftDouble {
                let paragraph = &self.text.paragraphs()[frame_index];
                let char_range = paragraph.word_range_at_char_index(char_index);
                let start_location = TextLocation::new(frame_index, char_range.start);
                let end_location = TextLocation::new(frame_index, char_range.end);
                self.selection = Some(start_location..end_location);
                dirty = true;
            }

            let runs = line.runs();
            let run = match runs.iter().find(|run| run.char_range().has(char_index)) {
                None => return,
                Some(run) => run,
            };
            for format in run.formatting().iter() {
                if let Some((id, _url)) = format.link() {
                    active_link_id = Some(id);
                    dirty = true;
                }
            }
        }

        if dirty {
            self.active_link_id = active_link_id;
            self.rebuild_display_list();
        }
    }

    pub fn mouse_up(&mut self, point: &LayoutPoint) -> EventResult {
        let mut event_result = EventResult::None;
        let dirty = self.active_link_id.is_some();

        {
            let HitTestResult {
                point,
                frame_index,
                line_index,
            } = match self.hit_test_point(point) {
                None => return EventResult::None,
                Some(hit_test_result) => hit_test_result,
            };
            let frame = &self.section.frames()[frame_index];
            let lines = frame.lines();
            let line = &lines[line_index];
            let char_index = match line.char_index_for_position(&point.to_untyped()) {
                None => return EventResult::None,
                Some(char_index) => char_index,
            };
            let runs = line.runs();
            let run = match runs.iter().find(|run| run.char_range().has(char_index)) {
                None => return EventResult::None,
                Some(run) => run,
            };
            for format in run.formatting().iter() {
                if let Some((link_id, url)) = format.link() {
                    if Some(link_id) == self.active_link_id {
                        event_result = EventResult::OpenUrl(url)
                    }
                }
            }
        }

        if dirty {
            self.active_link_id = None;
            self.rebuild_display_list();
        }

        event_result
    }

    pub fn available_width(&self) -> Length<f32, LayoutPixel> {
        self.available_width
    }

    pub fn set_available_width(&mut self, available_width: Length<f32, LayoutPixel>) {
        self.available_width = available_width;
        self.layout();
    }

    pub fn set_translation(&mut self, origin: &TypedVector2D<f32, LayoutPixel>) {
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
            let end = TextLocation::new(paragraph_index, character_index);
            self.selection = Some(TextLocation::beginning()..end);
        }

        eprintln!("select_all(): new selection={:?}", self.selection);
        self.rebuild_display_list();
    }

    fn layout(&mut self) {
        let available_width = self.available_width;
        self.section = layout_text(&self.text, available_width, &self.page_margin);

        self.rebuild_display_list();
    }

    fn rebuild_display_list(&mut self) {
        let available_layout_size = LayoutSize::new(self.available_width.get(), 1000000.0);
        let mut scene_builder = SceneBuilder::new(&available_layout_size,
                                                  &self.selection,
                                                  &self.active_link_id,
                                                  &self.selection_background_color);
        let mut resource_updates = ResourceUpdates::new();
        scene_builder.build_display_list(&self.wr_sender_api,
                                         &mut resource_updates,
                                         &self.section);
        self.wr_display_list = scene_builder.finalize();

        let mut transaction = Transaction::new();
        transaction.update_resources(resource_updates);
        self.wr_sender_api.send_transaction(self.wr_document_id, transaction);
    }

    fn hit_test_point(&self, point: &LayoutPoint) -> Option<HitTestResult> {
        let inverse_transform = match self.transform.inverse() {
            None => return None,
            Some(inverse_transform) => inverse_transform,
        };
        let point = inverse_transform.transform_point(&point);
        let frame_index = match self.section.frame_index_at_point(&point.to_untyped()) {
            None => return None,
            Some(frame_index) => frame_index,
        };
        let frame = &self.section.frames()[frame_index];
        let line_index = match frame.line_index_at_point(&point.to_untyped()) {
            None => return None,
            Some(line_index) => line_index,
        };
        Some(HitTestResult {
            point,
            frame_index,
            line_index,
        })
    }
}

#[derive(Clone, Copy, PartialEq)]
#[repr(C)]
pub enum MouseCursor {
    Default = 0,
    Text,
    Pointer,
}

fn layout_text(text: &TextBuf,
               available_width: Length<f32, LayoutPixel>,
               page_margin: &TypedSideOffsets2D<f32, LayoutPixel>)
               -> Section {
    let framesetter = Framesetter::new(text);
    let layout_origin = LayoutPoint::new(page_margin.left, page_margin.top);
    let layout_width = available_width.get() - page_margin.horizontal();
    let layout_size = LayoutSize::new(layout_width, 1000000.0);
    framesetter.layout_in_rect(&LayoutRect::new(layout_origin, layout_size).to_untyped())
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

pub(crate) struct ComputedStyle {
    font: Option<(FontFaceId, FontId)>,
    color: Option<ColorF>,
    underline: bool,
}

impl ComputedStyle {
    pub fn from_formatting(formatting: Vec<Format>,
                           active_link_id: &Option<usize>,
                           font_keys: &mut FontKeyMap,
                           render_api: &RenderApi,
                           resource_updates: &mut ResourceUpdates)
                           -> ComputedStyle {
        let mut computed_style = ComputedStyle {
            font: None,
            color: None,
            underline: false,
        };

        for format in formatting.into_iter().rev() {
            if let Some(font) = format.font() {
                if computed_style.font.is_none() {
                    let font_info = font_keys.entry(font.face_id()).or_insert_with(|| {
                        let font_key = render_api.generate_font_key();
                        // FIXME(pcwalton): Workaround for version mismatch of `core-graphics`!
                        let native_handle = unsafe {
                            NativeFontHandle(mem::transmute(font.native_font()
                                                                .copy_to_CGFont()))
                        };
                        resource_updates.add_native_font(font_key, native_handle.clone());
                        FontInfo {
                            key: font_key,
                            instance_infos: HashMap::new(),
                            native_handle,
                        }
                    });
                    let font_key = font_info.key.clone();
                    let native_font_handle = font_info.native_handle.clone();
                    if let Entry::Vacant(entry) = font_info.instance_infos.entry(font.id()) {
                        let font_instance_key = render_api.generate_font_instance_key();
                        let font_size = Au::from_f32_px(font.size());
                        resource_updates.add_font_instance(font_instance_key,
                                                           font_key.clone(),
                                                           font_size,
                                                           None,
                                                           None,
                                                           vec![]);
                        // FIXME(pcwalton): Another workaround for version mismatch of
                        // `core-graphics`!
                        let ct_font = unsafe {
                            ct_font::new_from_CGFont(mem::transmute(&native_font_handle.0),
                                                     font.size() as f64)
                        };
                        entry.insert(FontInstanceInfo {
                            key: font_instance_key,
                            underline_position: ct_font.underline_position() as f32,
                            underline_thickness: ct_font.underline_thickness() as f32,
                        });
                    }
                    computed_style.font = Some((font.face_id(), font.id()))
                }
            }

            if let Some(color) = format.color() {
                if computed_style.color.is_none() {
                    computed_style.color = Some(color.to_colorf())
                }
            }

            if let Some((link_id, _)) = format.link() {
                computed_style.underline = true;
                if computed_style.color.is_none() {
                    let color = if *active_link_id == Some(link_id) {
                        DEFAULT_LINK_ACTIVE_COLOR
                    } else {
                        DEFAULT_LINK_COLOR
                    };
                    computed_style.color = Some(color)
                }
            }
        }

        computed_style
    }
}

struct FontInfo {
    key: FontKey,
    instance_infos: HashMap<FontId, FontInstanceInfo>,
    native_handle: NativeFontHandle,
}

struct FontInstanceInfo {
    key: FontInstanceKey,
    underline_position: f32,
    underline_thickness: f32,
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

trait RangeExt {
    fn has(&self, index: usize) -> bool;
}

impl RangeExt for Range<usize> {
    #[inline]
    fn has(&self, index: usize) -> bool {
        self.start <= index && index < self.end
    }
}

#[derive(Clone, Copy)]
struct HitTestResult {
    point: LayoutPoint,
    frame_index: usize,
    line_index: usize,
}

#[derive(Clone, Debug)]
pub enum EventResult {
    None,
    OpenUrl(String),
}

#[derive(Clone, Copy, Debug, PartialEq)]
#[repr(C)]
pub enum MouseEventKind {
    Left = 0,
    LeftDouble,
}
