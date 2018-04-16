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
use pilcrow::{Frame, Framesetter, ParagraphBuf, TextBuf};
use std::collections::HashMap;
use std::collections::hash_map::Entry;
use std::f32;
use std::ffi::CString;
use std::fs::File;
use std::io::Read;
use std::mem;
use std::os::raw::c_void;
use std::rc::Rc;
use webrender::{Renderer, RendererOptions};
use webrender_api::{BuiltDisplayList, ColorF, DeviceIntPoint, DeviceIntSize, DevicePixel, DeviceRect};
use webrender_api::{DeviceUintPoint, DeviceUintRect, DeviceUintSize, DisplayListBuilder};
use webrender_api::{DocumentId, Epoch, FontInstanceKey, FontKey, GlyphInstance, IdNamespace};
use webrender_api::{LayoutPoint, LayoutPrimitiveInfo, LayoutPixel, LayoutRect, LayoutSize, MixBlendMode};
use webrender_api::{NativeFontHandle, PipelineId, RenderApi, RenderApiSender, RenderNotifier, ResourceUpdates};
use webrender_api::{ScrollPolicy, Transaction, TransformStyle, ZoomFactor};

pub mod ffi;

const BLACK_COLOR: ColorF = ColorF {
    r: 0.0,
    g: 0.0,
    b: 0.0,
    a: 1.0,
};

const PIPELINE_ID: PipelineId = PipelineId(0, 0);

pub type GetProcAddressFn = unsafe extern "C" fn(*const c_char) -> *const c_void;

type WrDisplayList = (PipelineId, LayoutSize, BuiltDisplayList);

pub struct View {
    text: TextBuf,
    gl: Rc<Gl>,
    available_width: Length<f32, LayoutPixel>,
    viewport_size: DeviceUintSize,
    transform: Transform2D<f32>,
    frames: Vec<Frame>,

    wr_renderer: Renderer,
    wr_sender: RenderApiSender,
    wr_sender_api: RenderApi,
    wr_document_id: DocumentId,
    wr_display_list: WrDisplayList,
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

        let wr_options = RendererOptions::default();
        let notifier = Box::new(Notifier::new());
        let (renderer, sender) = Renderer::new(gl.clone(), notifier, wr_options).unwrap();
        let sender_api = sender.create_api();

        let layout_size = LayoutSize::new(available_width.get(), 1000000.0);
        let device_size = DeviceUintSize::new(layout_size.width as u32, layout_size.height as u32);
        let document_id = sender_api.add_document(device_size, 0);

        let mut display_list_builder = init_display_list_builder(&layout_size);
        let mut resource_updates = ResourceUpdates::new();
        let frames = layout_text(&text, available_width);
        build_display_list(&mut display_list_builder, &sender_api, &mut resource_updates, &frames);
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
            frames,

            wr_renderer: renderer,
            wr_sender: sender,
            wr_sender_api: sender_api,
            wr_document_id: document_id,
            wr_display_list: display_list,
        }
    }

    pub fn layout_size(&self) -> LayoutSize {
        LayoutSize::new(self.available_width.get(), match self.frames.last() {
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

        self.wr_renderer.update();
        self.wr_renderer.render(self.viewport_size).unwrap();
    }

    pub fn resize(&mut self, available_width: Length<f32, LayoutPixel>) {
        self.available_width = available_width
    }

    pub fn set_viewport(&mut self, viewport: &DeviceRect) {
        self.transform.m31 = -viewport.origin.x;
        self.transform.m32 = -viewport.origin.y;
        self.viewport_size = DeviceUintSize::new(viewport.size.width as u32,
                                                 viewport.size.height as u32);
    }

    pub fn zoom(&mut self, factor: f32) {
        let factor = f32::exp(factor);
        self.transform.m11 *= factor;
        self.transform.m22 *= factor;
    }
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

fn layout_text(text: &TextBuf, available_width: Length<f32, LayoutPixel>) -> Vec<Frame> {
    let framesetter = Framesetter::new(text);
    let layout_size = LayoutSize::new(available_width.get(), 1000000.0);
    let layout_rect = LayoutRect::new(LayoutPoint::zero(), layout_size);
    framesetter.layout_in_rect(&layout_rect.to_untyped())
}

fn build_display_list(display_list_builder: &mut DisplayListBuilder,
                      render_api: &RenderApi,
                      resource_updates: &mut ResourceUpdates,
                      frames: &[Frame]) {
    let mut font_keys = HashMap::new();

    for frame in frames {
        for line in frame.lines() {
            let typo_bounds = line.typographic_bounds();
            let line_origin = LayoutPoint::from_untyped(&line.origin);
            let line_size = LayoutSize::new(typo_bounds.width,
                                            typo_bounds.ascent + typo_bounds.descent);
            let line_bounds = LayoutRect::new(LayoutPoint::new(line_origin.x,
                                                               line_origin.y - typo_bounds.ascent),
                                              line_size);
            let layout_primitive_info = LayoutPrimitiveInfo::new(line_bounds);

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

                let formatting = run.formatting();
                let mut font_instance_key = None;
                for format in formatting.into_iter().rev() {
                    if let Some(font) = format.font() {
                        if font_instance_key.is_none() {
                            let &mut (font_key,
                                    ref mut font_instance_keys) = font_keys.entry(font.face_id())
                                                                            .or_insert_with(|| {
                                let font_key = render_api.generate_font_key();
                                // FIXME(pcwalton): Workaround for version mismatch of
                                // `core-graphics`!
                                let native_font = unsafe {
                                    NativeFontHandle(mem::transmute(font.native_font()
                                                                        .copy_to_CGFont()))
                                };
                                resource_updates.add_native_font(font_key, native_font);
                                (font_key, HashMap::new())
                            });
                            font_instance_key = Some(*font_instance_keys.entry(font.id())
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
                }

                if let Some(font_instance_key) = font_instance_key {
                    display_list_builder.push_text(&layout_primitive_info,
                                                   &glyphs,
                                                   font_instance_key,
                                                   BLACK_COLOR,
                                                   None);
                }
            }
        }
    }
}

struct Notifier;

impl Notifier {
    fn new() -> Notifier {
        Notifier
    }
}

impl RenderNotifier for Notifier {
    fn clone(&self) -> Box<RenderNotifier> {
        Box::new(Notifier::new())
    }

    fn wake_up(&self) {}

    fn new_document_ready(&self, _: DocumentId, _: bool, _: bool) {}
}
