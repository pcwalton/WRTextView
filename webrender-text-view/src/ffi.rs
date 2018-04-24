// WRTextView/webrender-text-view/src/ffi.rs
//
// Copyright © 2018 The Pathfinder Project Developers.
//
// Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
// http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
// <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
// option. This file may not be copied, modified, or distributed
// except according to those terms.

use euclid::{Length, TypedScale, TypedVector2D};
use pilcrow::{Color, TextBuf};
use std::cmp;
use std::ptr;
use webrender_api::{DevicePoint, DeviceUintSize, LayoutPoint};
use {EventResult, GetProcAddressFn, MouseCursor, MouseEventKind, View};

pub const WRTV_EVENT_RESULT_NONE: u8 = 0;
pub const WRTV_EVENT_RESULT_OPEN_URL: u8 = 1;

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_new(text: *mut TextBuf,
                                       viewport_width: u32,
                                       viewport_height: u32,
                                       device_pixel_ratio: f32,
                                       available_width: f32,
                                       get_proc_address: GetProcAddressFn)
                                       -> *mut View {
    let text = Box::from_raw(text);
    let viewport = DeviceUintSize::new(viewport_width, viewport_height);
    let device_pixel_ratio = TypedScale::new(device_pixel_ratio);
    let available_width = Length::new(available_width);
    Box::into_raw(Box::new(View::new(*text,
                                     &viewport,
                                     device_pixel_ratio,
                                     available_width,
                                     get_proc_address)))
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
pub unsafe extern "C" fn wrtv_view_get_mouse_cursor(view: *mut View, x: f32, y: f32)
                                                    -> MouseCursor {
    (*view).get_mouse_cursor(&LayoutPoint::new(x, y))
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_mouse_down(view: *mut View,
                                              x: f32,
                                              y: f32,
                                              kind: MouseEventKind) {
    (*view).mouse_down(&LayoutPoint::new(x, y), kind)
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_mouse_up(view: *mut View, x: f32, y: f32) -> *mut EventResult {
    Box::into_raw(Box::new((*view).mouse_up(&LayoutPoint::new(x, y))))
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_get_available_width(view: *mut View) -> f32 {
    (*view).available_width().get()
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_set_available_width(view: *mut View, new_available_width: f32) {
    (*view).set_available_width(Length::new(new_available_width))
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_set_translation(view: *mut View, x: f32, y: f32) {
    (*view).set_translation(&TypedVector2D::new(x, y))
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_set_viewport_size(view: *mut View, width: u32, height: u32) {
    (*view).set_viewport_size(&DeviceUintSize::new(width, height))
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_set_scale(view: *mut View, scale: f32) {
    (*view).set_scale(scale)
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_set_selection_background_color(view: *mut View,
                                                                  r: u8,
                                                                  g: u8,
                                                                  b: u8,
                                                                  a: u8) {
    (*view).set_selection_background_color(Color::new(r, g, b, a))
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_select_all(view: *mut View) {
    (*view).select_all()
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_event_result_destroy(event_result: *mut EventResult) {
    drop(Box::from_raw(event_result))
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_event_result_get_type(event_result: *const EventResult) -> u8 {
    match *event_result {
        EventResult::None => WRTV_EVENT_RESULT_NONE,
        EventResult::OpenUrl(_) => WRTV_EVENT_RESULT_OPEN_URL,
    }
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_event_result_get_string_len(event_result: *const EventResult)
                                                          -> usize {
    match *event_result {
        EventResult::None => 0,
        EventResult::OpenUrl(ref url) => url.len(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_event_result_get_string(event_result: *const EventResult,
                                                      buffer: *mut u8,
                                                      buffer_len: usize) {
    match *event_result {
        EventResult::None => {}
        EventResult::OpenUrl(ref url) => {
            ptr::copy_nonoverlapping(url.as_ptr(), buffer, cmp::min(url.len(), buffer_len))
        }
    }
}
