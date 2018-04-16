//
//  WRTextRendererView.h
//  WRTextView Example
//
//  Created by Patrick Walton on 4/11/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Document.h"
#include <pilcrow.h>
#include <wr-text-view.h>

@class WRTextView;

@interface WRTextRendererView : NSOpenGLView {
    wrtv_view_t *_wrView;
}

@property(nonatomic, strong) WRTextView *textView;

@end