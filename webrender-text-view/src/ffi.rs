// WRTextView/webrender-text-view/src/ffi.rs
//
// Copyright © 2018 The Pathfinder Project Developers.
//
// Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
// http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
// <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
// option. This file may not be copied, modified, or distributed
// except according to those terms.

use pilcrow::TextBuf;
use {GetProcAddressFn, View};

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_new(text: *mut TextBuf, get_proc_address: GetProcAddressFn)
                                       -> *mut View {
    Box::into_raw(Box::new(View::new(*Box::from_raw(text), get_proc_address)))
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_destroy(view: *mut View) {
    drop(Box::from_raw(view))
}

#[no_mangle]
pub unsafe extern "C" fn wrtv_view_repaint(view: *mut View) {
    (*view).repaint()
}
