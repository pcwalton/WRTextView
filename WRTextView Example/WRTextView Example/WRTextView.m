//
//  WRTextView.m
//  WRTextView Example
//
//  Created by Patrick Walton on 4/11/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#include <pthread.h>
#import <OpenGL/gl.h>
#import "WRTextView.h"

static const void *getGLProcAddress(const char *symbolName) {
    CFBundleRef bundle = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.opengl"));
    NSString *symbolString = [NSString stringWithUTF8String:symbolName];
    void *function = CFBundleGetFunctionPointerForName(bundle, (__bridge CFStringRef)symbolString);
    return function;
}

@implementation WRTextView

- (void)_initGLWithPixelFormat:(NSOpenGLPixelFormat *)format {
    [self setWantsBestResolutionOpenGLSurface:YES];
    self->_pixelFormat = format;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(_surfaceNeedsUpdate:)
                                                name:NSViewGlobalFrameDidChangeNotification
                                              object:self];
}

- (id)initWithFrame:(NSRect)frameRect
        pixelFormat:(nullable NSOpenGLPixelFormat *)format {
    self = [super initWithFrame:frameRect];
    [self _initGLWithPixelFormat:format];
    return self;
}

- (void)awakeFromNib {
    [self _initGLWithPixelFormat:[WRTextView defaultPixelFormat]];
    self->_openGLContext = [[NSOpenGLContext alloc] initWithFormat:self->_pixelFormat
                                                      shareContext:nil];
    
    pilcrow_text_buf_t *textBuffer = [self->document textBuffer];

    [self->_openGLContext makeCurrentContext];
    GLint one = 1;
    CGLSetParameter([self->_openGLContext CGLContextObj], kCGLCPSwapInterval, &one);

    if (textBuffer == nil)
        return;

    NSRect backingFrame = [self convertRectToBacking:[self frame]];
    self->_wrView = wrtv_view_new(textBuffer,
                                  (uint32_t)ceil(backingFrame.size.width),
                                  (uint32_t)ceil(backingFrame.size.height),
                                  getGLProcAddress);
}

- (void)_surfaceNeedsUpdate:(NSNotification *)notification {
    [self update];
}

- (void)update {
    if (self->_wrView != NULL) {
        NSRect backingFrame = [self convertRectToBacking:[self frame]];
        wrtv_view_resize(self->_wrView,
                         (uint32_t)ceil(backingFrame.size.width),
                         (uint32_t)ceil(backingFrame.size.height));
        NSLog(@"resized to: %f,%f", backingFrame.size.width, backingFrame.size.height);
    }

    [self->_openGLContext update];
    [self->_openGLContext setView:self];
}

- (void)clearGLContext {
    [self->_openGLContext clearDrawable];
    self->_openGLContext = nil;
}

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

    if ([self->_openGLContext view] != self)
        [self->_openGLContext setView:self];
    
    NSRect backingFrame = [self convertRectToBacking:[self frame]];

    CGLContextObj glContext = [self->_openGLContext CGLContextObj];
    CGLSetCurrentContext(glContext);
    CGLLockContext(glContext);
    wrtv_view_repaint(self->_wrView);
    CGLFlushDrawable(glContext);
    CGLUnlockContext(glContext);
}

- (void)scrollWheel:(NSEvent *)event {
    wrtv_view_pan(self->_wrView, (float)[event scrollingDeltaX], (float)[event scrollingDeltaY]);
    [self setNeedsDisplay:YES];
}

- (void)magnifyWithEvent:(NSEvent *)event {
    wrtv_view_zoom(self->_wrView, (float)[event magnification]);
    [self setNeedsDisplay:YES];
}

@end
