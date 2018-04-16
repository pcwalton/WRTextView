// WRTextView/webrender-text-view/src/ffi.rs
//
// Copyright © 2018 The Pathfinder Project Developers.
//
// Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
// http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
// <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
// option. This file may not be copied, modified, or distributed
// except according to those terms.

use euclid::Length;
use pilcrow::TextBuf;
use webrender_api::{DevicePixel, DevicePoint, DeviceRect, DeviceSize, DeviceUintPoint, DeviceUintRect, DeviceUintSize};
use webrender_api::{LayoutPoint, LayoutSize};
use {GetProcAddressFn, View};

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_new(text: *mut TextBuf,
                                       viewport_width: u32,
                                       viewport_height: u32,
                                       available_width: f32,
                                       get_proc_address: GetProcAddressFn)
                                       -> *mut View {
    let text = Box::from_raw(text);
    let viewport = DeviceUintSize::new(viewport_width, viewport_height);
    let available_width = Length::new(available_width);
    Box::into_raw(Box::new(View::new(*text, &viewport, available_width, get_proc_address)))
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_destroy(view: *mut View) {
    drop(Box::from_raw(view))
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_get_layout_size(view: *mut View,
                                                   width: *mut f32,
                                                   height: *mut f32) {
    let size = (*view).layout_size();
    *width = size.width;
    *height = size.height;
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_repaint(view: *mut View) {
    (*view).repaint()
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_resize(view: *mut View, new_available_width: f32) {
    (*view).resize(Length::new(new_available_width))
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_set_viewport(view: *mut View,
                                                x: f32,
                                                y: f32,
                                                width: f32,
                                                height: f32) {
    (*view).set_viewport(&DeviceRect::new(DevicePoint::new(x, y), DeviceSize::new(width, height)))
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_zoom(view: *mut View, factor: f32) {
    (*view).zoom(factor)
}
