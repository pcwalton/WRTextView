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
    NSTrackingArea *_trackingArea;
    wrtv_view_t *_wrView;
}

@property(nonatomic, strong) WRTextView *textView;

- (void)reloadText;
- (void)setDebuggerEnabled:(BOOL)enabled;
- (void)setImage:(NSImage *)image forID:(uint32_t)imageID;

@end
