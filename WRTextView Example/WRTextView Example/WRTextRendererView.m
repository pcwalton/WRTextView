//
//  WRTextRendererView.m
//  WRTextView Example
//
//  Created by Patrick Walton on 4/11/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#include <pthread.h>
#import <OpenGL/gl.h>
#import "WRTextRendererView.h"
#import "WRTextView.h"

static const void *getGLProcAddress(const char *symbolName) {
    CFBundleRef bundle = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.opengl"));
    NSString *symbolString = [NSString stringWithUTF8String:symbolName];
    void *function = CFBundleGetFunctionPointerForName(bundle, (__bridge CFStringRef)symbolString);
    return function;
}

@implementation WRTextRendererView

- (id)initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat *)pixelFormat {
    self = [super initWithFrame:frameRect pixelFormat:pixelFormat];
    
    [self setPixelFormat:pixelFormat];
    NSOpenGLContext *glContext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat
                                                            shareContext:nil];
    [self setOpenGLContext:glContext];
    [self setWantsBestResolutionOpenGLSurface:YES];
    
    return self;
}

- (void)setTextView:(WRTextView *)textView {
    self->_textView = textView;

    pilcrow_text_buf_t *textBuffer = [[textView document] textBuffer];

    NSOpenGLContext *glContext = [self openGLContext];
    [glContext makeCurrentContext];
    GLint one = 1;
    CGLSetParameter([glContext CGLContextObj], kCGLCPSwapInterval, &one);

    if (textBuffer == NULL)
        return;

    NSRect frame = [self frame];
    NSRect backingFrame = [self convertRectToBacking:frame];
    self->_wrView = wrtv_view_new(textBuffer,
                                  (uint32_t)ceil(backingFrame.size.width),
                                  (uint32_t)ceil(backingFrame.size.height),
                                  backingFrame.size.width,
                                  getGLProcAddress);

    float newWidth, newHeight;
    wrtv_view_get_layout_size(self->_wrView, &newWidth, &newHeight);
    NSSize newFrameSize = [self convertSizeFromBacking:NSMakeSize(newWidth, newHeight)];
    [self->_textView setFrameSize:newFrameSize];
    NSLog(@"layout size: %f,%f", newWidth, newHeight);
    
    [self setNeedsDisplay:YES];
}

- (void)_surfaceNeedsUpdate:(NSNotification *)notification {
    [self update];
}

- (void)update {
    if (self->_wrView != NULL) {
        NSRect backingFrame = [self convertRectToBacking:[self frame]];
        wrtv_view_resize(self->_wrView, (uint32_t)ceil(backingFrame.size.width));
    }
}

/*
- (void)clearGLContext {
    [self->_openGLContext clearDrawable];
    self->_openGLContext = nil;
}*/

+ (NSOpenGLPixelFormat *)defaultPixelFormat {
    NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAStencilSize, 8,
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFANoRecovery,
        0, 0
    };
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    if (pixelFormat == nil)
        abort();
    return pixelFormat;
}

- (BOOL)isOpaque {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    if (self->_wrView == nil)
        return;

    NSRect textViewFrame = [self->_textView convertRectToBacking:[self->_textView frame]];
    NSRect frame = [self convertRectToBacking:[self frame]];
    
    NSOpenGLContext *glContext = [self openGLContext];
    [glContext makeCurrentContext];
    /*wrtv_view_resize(self->_wrView,
                     (uint32_t)self->_viewport.size.width,
                     (uint32_t)self->_viewport.size.height);*/
    wrtv_view_set_viewport(self->_wrView,
                           frame.origin.x,
                           (textViewFrame.size.height - NSMaxY(frame)),
                           frame.size.width,
                           frame.size.height);
    NSLog(@"text view frame rect:%f,%f for %f,%f",
          (float)textViewFrame.origin.x,
          (float)textViewFrame.origin.y,
          (float)textViewFrame.size.width,
          (float)textViewFrame.size.height);
    NSLog(@"frame:%f,%f for %f,%f",
          (float)frame.origin.x,
          (float)frame.origin.y,
          (float)frame.size.width,
          (float)frame.size.height);

    wrtv_view_repaint(self->_wrView);
    [glContext flushBuffer];
}

- (void)mouseDown:(NSEvent *)event {
    [self setNeedsDisplay:YES];
}

@end
