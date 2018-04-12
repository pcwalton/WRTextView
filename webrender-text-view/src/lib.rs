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
extern crate gleam;
extern crate libc;
extern crate pilcrow;
extern crate webrender;
extern crate webrender_api;

use app_units::Au;
use gleam::gl::{self, Gl};
use libc::c_char;
use pilcrow::TextBuf;
use std::ffi::CString;
use std::fs::File;
use std::io::Read;
use std::os::raw::c_void;
use std::rc::Rc;
use webrender::{Renderer, RendererOptions};
use webrender_api::{BuiltDisplayList, ColorF, DeviceSize, DeviceUintSize, DisplayListBuilder, DocumentId, Epoch};
use webrender_api::{FontInstanceKey, FontKey, GlyphInstance, IdNamespace, LayoutPoint, LayoutPrimitiveInfo, LayoutRect, LayoutSize};
use webrender_api::{MixBlendMode, PipelineId, RenderApi, RenderApiSender, RenderNotifier};
use webrender_api::{ResourceUpdates, ScrollPolicy, Transaction, TransformStyle};

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

    wr_renderer: Renderer,
    wr_sender: RenderApiSender,
    wr_sender_api: RenderApi,
    wr_document_id: DocumentId,
    wr_font_key: FontKey,
    wr_font_instance_key: FontInstanceKey,
    wr_display_list: WrDisplayList,
}

impl View {
    pub fn new(text: TextBuf, get_proc_address: GetProcAddressFn) -> View {
        let gl = unsafe {
            gl::GlFns::load_with(|symbol| {
                let symbol = CString::new(symbol).unwrap();
                get_proc_address(symbol.as_ptr())
            })
        };

        let wr_options = RendererOptions::default();
        let notifier = Box::new(Notifier::new());
        let (mut renderer, sender) = Renderer::new(gl.clone(), notifier, wr_options).unwrap();
        let sender_api = sender.create_api();

        let framebuffer_size = DeviceUintSize::new(320, 240);
        let document_id = sender_api.add_document(framebuffer_size, 0);

        let font_key = sender_api.generate_font_key();
        let font_instance_key = sender_api.generate_font_instance_key();
        let font_bytes =
            load_file("/Users/pcwalton/Source/webrender/wrench/reftests/text/FreeSans.ttf");
        let mut resource_updates = ResourceUpdates::new();
        resource_updates.add_raw_font(font_key, font_bytes, 0);
        resource_updates.add_font_instance(font_instance_key,
                                           font_key,
                                           Au::from_px(32),
                                           None,
                                           None,
                                           vec![]);

        let mut transaction = Transaction::new();
        transaction.update_resources(resource_updates);
        sender_api.send_transaction(document_id, transaction);

        let display_list = build_display_list(&text, &font_instance_key);

        View {
            text: text,
            gl: gl,

            wr_renderer: renderer,
            wr_sender: sender,
            wr_sender_api: sender_api,
            wr_document_id: document_id,
            wr_font_key: font_key,
            wr_font_instance_key: font_instance_key,
            wr_display_list: display_list,
        }
    }

    pub fn repaint(&mut self) {
        // TODO(pcwalton)
        let layout_size = LayoutSize::new(320.0, 240.0);
        let framebuffer_size = DeviceUintSize::new(320, 240);

        let mut transaction = Transaction::new();
        transaction.set_display_list(Epoch(0),
                                     None,
                                     layout_size,
                                     self.wr_display_list.clone(),
                                     true);
        transaction.set_root_pipeline(PIPELINE_ID);
        transaction.generate_frame();
        self.wr_sender_api.send_transaction(self.wr_document_id, transaction);

        self.wr_renderer.update();
        self.wr_renderer.render(framebuffer_size).unwrap();
    }
}

fn build_display_list(text: &TextBuf, font_instance_key: &FontInstanceKey) -> WrDisplayList {
    let layout_size = LayoutSize::new(320.0, 240.0);
    let mut display_list_builder = DisplayListBuilder::new(PIPELINE_ID, layout_size);
    let root_stacking_context_bounds = LayoutRect::new(LayoutPoint::zero(), layout_size);
    let root_layout_primitive_info = LayoutPrimitiveInfo::new(root_stacking_context_bounds);
    display_list_builder.push_stacking_context(&root_layout_primitive_info,
                                                None,
                                                ScrollPolicy::Scrollable,
                                                None,
                                                TransformStyle::Flat,
                                                None,
                                                MixBlendMode::Normal,
                                                vec![]);

    let glyphs = vec![
        GlyphInstance { index: 48, point: LayoutPoint::new(100.0, 100.0), },
        GlyphInstance { index: 68, point: LayoutPoint::new(150.0, 100.0), },
        GlyphInstance { index: 80, point: LayoutPoint::new(200.0, 100.0), },
        GlyphInstance { index: 82, point: LayoutPoint::new(250.0, 100.0), },
        GlyphInstance { index: 81, point: LayoutPoint::new(300.0, 100.0), },
        GlyphInstance { index: 3,  point: LayoutPoint::new(350.0, 100.0), },
        GlyphInstance { index: 86, point: LayoutPoint::new(400.0, 100.0), },
        GlyphInstance { index: 79, point: LayoutPoint::new(450.0, 100.0), },
        GlyphInstance { index: 72, point: LayoutPoint::new(500.0, 100.0), },
        GlyphInstance { index: 83, point: LayoutPoint::new(550.0, 100.0), },
        GlyphInstance { index: 87, point: LayoutPoint::new(600.0, 100.0), },
        GlyphInstance { index: 17, point: LayoutPoint::new(650.0, 100.0), },
    ];

    display_list_builder.push_text(&root_layout_primitive_info,
                                   &glyphs,
                                   *font_instance_key,
                                   BLACK_COLOR,
                                   None);

    display_list_builder.pop_stacking_context();
    display_list_builder.finalize()
}

fn load_file(name: &str) -> Vec<u8> {
    let mut file = File::open(name).unwrap();
    let mut buffer = vec![];
    file.read_to_end(&mut buffer).unwrap();
    buffer
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
