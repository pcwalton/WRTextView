//
//  WRTextView.m
//  WRTextView Example
//
//  Created by Patrick Walton on 4/16/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "WRTextView.h"
#import "Document.h"
#import "WRTextRendererView.h"

@implementation WRTextView

- (void)_setup {
    NSView *superview = [self superview];
    
    NSRect rendererViewFrame;
    rendererViewFrame.origin = NSZeroPoint;
    rendererViewFrame.size = [superview frame].size;
    self->_rendererView =
        [[WRTextRendererView alloc] initWithFrame:rendererViewFrame
                                      pixelFormat:[WRTextRendererView defaultPixelFormat]];
    [self->_rendererView setTextView:self];
    [self addSubview:self->_rendererView];
    
    if (![superview isKindOfClass:[NSClipView class]])
        return;

    NSView *supersuperview = [superview superview];
    if (![supersuperview isKindOfClass:[NSScrollView class]])
        return;

    NSScrollView *scrollView = (NSScrollView *)supersuperview;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(_scrolled:)
                                                name:NSScrollViewDidLiveScrollNotification
                                              object:scrollView];
}

- (void)awakeFromNib {
    [self _setup];
}

- (void)_scrolled:(NSNotification *)notification {
    NSScrollView *scrollView = [notification object];
    NSRect documentVisibleRect = [scrollView documentVisibleRect];
    NSLog(@"scrolled: %f,%f by %f,%f",
          documentVisibleRect.origin.x,
          documentVisibleRect.origin.y,
          documentVisibleRect.size.width,
          documentVisibleRect.size.height);
    [self->_rendererView setFrameOrigin:documentVisibleRect.origin];
    [self->_rendererView setNeedsDisplay:YES];
}

@end
