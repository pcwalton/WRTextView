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
    self->_scale = 1.0;
    
    NSScrollView *scrollView = [self _scrollView];
    if (scrollView == nil)
        return;

    NSRect rendererViewFrame;
    rendererViewFrame.origin = NSZeroPoint;
    rendererViewFrame.size = [scrollView frame].size;
    self->_rendererView =
        [[WRTextRendererView alloc] initWithFrame:rendererViewFrame
                                      pixelFormat:[WRTextRendererView defaultPixelFormat]];
    [self->_rendererView setTextView:self];
    [self addSubview:self->_rendererView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(_scrolled:)
                                                name:NSScrollViewDidLiveScrollNotification
                                              object:scrollView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(_resized:)
                                                name:NSViewFrameDidChangeNotification
                                              object:scrollView];
}

- (void)awakeFromNib {
    [self _setup];
}

- (BOOL)isOpaque {
    return YES;
}

- (void)scrollToBeginningOfDocument:(id)sender {
    NSRect rendererFrame = [self->_rendererView frame];
    NSRect viewFrame = [self frame];
    CGFloat yOrigin = viewFrame.size.height - rendererFrame.size.height;
    [self->_rendererView setFrameOrigin:NSMakePoint(0.0, yOrigin)];
    [self->_rendererView setNeedsDisplay:YES];
}

- (void)magnifyWithEvent:(NSEvent *)event {
    [super magnifyWithEvent:event];
    
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    [self zoomBy:exp([event magnification]) atPoint:point];
}

- (CGAffineTransform)transform {
    NSRect viewportFrame = [self->_rendererView frame];
    NSRect textViewFrame = [self frame];
    CGFloat x = viewportFrame.origin.x, y = textViewFrame.size.height - NSMaxY(viewportFrame);
    return CGAffineTransformMake(self->_scale, 1.0, 1.0, self->_scale, x, y);
}

- (void)setTransform:(CGAffineTransform)transform {
    // newY = textViewFrame.size.height - (viewportFrame.origin.y + viewportFrame.size.height)
    // newY = textViewFrame.size.height - viewportFrame.origin.y - viewportFrame.size.height
    // newY + viewportFrame.size.height - textViewFrame.size.height = -viewportFrame.origin.y
    // -newY - viewportFrame.size.height + textViewFrame.size.height = viewportFrame.origin.y
    // textViewFrame.size.height - newY - viewportFrame.size.height = viewportFrame.origin.y

    self->_scale = transform.a;

    NSRect textViewFrame = [self frame];
    NSSize viewportSize = [self->_rendererView frame].size;
    CGFloat newViewportXOrigin = transform.tx;
    CGFloat newViewportYOrigin = textViewFrame.size.height - viewportSize.height - transform.ty;
    NSPoint newViewportOrigin = NSMakePoint(newViewportXOrigin, newViewportYOrigin);
    [self->_rendererView setFrameOrigin:newViewportOrigin];
    [self->_rendererView setNeedsDisplay:YES];
}

- (void)_scrolled:(NSNotification *)notification {
    NSScrollView *scrollView = [notification object];
    
    NSRect frame = [self frame];
    NSRect documentVisibleRect = [scrollView documentVisibleRect];

    CGAffineTransform transform = [self transform];
    transform.tx = documentVisibleRect.origin.x;
    transform.ty = frame.size.height - NSMaxY(documentVisibleRect);
    NSLog(@"new transform: %f,%f, DVR=%f,%f for %f,%f",
          transform.tx, transform.ty,
          documentVisibleRect.origin.x, documentVisibleRect.origin.y,
          documentVisibleRect.size.width, documentVisibleRect.size.height);
    [self setTransform:transform];
}

- (void)_resized:(NSNotification *)notification {
    NSView *scrollView = [notification object];
    NSSize newSize = [scrollView frame].size;
    NSLog(@"resized: %fx%f", newSize.width, newSize.height);
    [self->_rendererView setFrameSize:newSize];
    [self->_rendererView setNeedsDisplay:YES];
}

- (NSScrollView *)_scrollView {
    NSView *superview = [self superview];
    if (![superview isKindOfClass:[NSClipView class]])
        return nil;
    NSView *supersuperview = [superview superview];
    if (![supersuperview isKindOfClass:[NSScrollView class]])
        return nil;
    return (NSScrollView *)supersuperview;
}

- (void)zoomBy:(CGFloat)scale atPoint:(NSPoint)point {
    CGAffineTransform transform = [self transform];
    NSSize documentSize = [self frame].size;
    
    point.y = documentSize.height - point.y;

    transform = CGAffineTransformTranslate(transform, -point.x, -point.y);
    transform = CGAffineTransformScale(transform, scale, scale);
    transform = CGAffineTransformTranslate(transform, point.x / scale, point.y / scale);
    [self setTransform:transform];

    [self->_rendererView setNeedsDisplay:YES];
}

- (CGFloat)zoomLevel {
    return [self transform].a;
}

- (void)reloadText {
    [self->_rendererView reloadText];
}

- (void)setDebuggerEnabled:(BOOL)enabled {
    [self->_rendererView setDebuggerEnabled:enabled];
}

- (void)_zoomAtCenterBy:(CGFloat)factor {
    NSSize size = [self frame].size;
    [self zoomBy:factor atPoint:NSMakePoint(size.width * 0.5, size.height * 0.5)];
}

- (IBAction)zoom:(id)sender {
    if (![sender isKindOfClass:[NSSegmentedControl class]])
        return;
    if ([(NSSegmentedControl *)sender selectedSegment] == 0)
        [self zoomOut:sender];
    else
        [self zoomIn:sender];
}

- (IBAction)zoomIn:(id)sender {
    [self _zoomAtCenterBy:1.1];
}

- (IBAction)zoomOut:(id)sender {
    [self _zoomAtCenterBy:1./1.1];
}

- (IBAction)zoomToActualSize:(id)sender {
    [self _zoomAtCenterBy:1. / [self zoomLevel]];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)setImage:(NSImage *)image forID:(uint32_t)imageID {
    NSLog(@"-[WRTextView setImage:forID:]");
    [self->_rendererView setImage:image forID:imageID];
}

@end
