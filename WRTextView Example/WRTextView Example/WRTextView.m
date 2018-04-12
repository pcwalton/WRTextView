//
//  WRTextView.m
//  WRTextView Example
//
//  Created by Patrick Walton on 4/11/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

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
    if (textBuffer != nil)
        self->wrView = wrtv_view_new(textBuffer, getGLProcAddress);
}

- (void)_surfaceNeedsUpdate:(NSNotification *)notification {
    [self update];
}

- (void)update {
    [self->_openGLContext update];
}

- (void)clearGLContext {
    [self->_openGLContext clearDrawable];
    self->_openGLContext = nil;
}

+ (NSOpenGLPixelFormat *)defaultPixelFormat {
    NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAStencilSize, 8,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated,
        0, 0
    };
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    if (pixelFormat == nil)
        abort();
    return pixelFormat;
}

- (void)lockFocus {
    [super lockFocus];
    if ([self->_openGLContext view] != self) {
        NSLog(@"setting view!");
        [self->_openGLContext setView:self];
    }
}

- (BOOL)isOpaque {
    return YES;
}

- (void)drawFrame:(id)unused {
    [self->_openGLContext makeCurrentContext];
    CGLLockContext([self->_openGLContext CGLContextObj]);
    /*glClearColor(0.0, 0.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);*/
    if (self->wrView != NULL)
        wrtv_view_repaint(self->wrView);
    CGLUnlockContext([self->_openGLContext CGLContextObj]);
    [self->_openGLContext flushBuffer];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    [self lockFocus];
    [self performSelectorInBackground:@selector(drawFrame:) withObject:nil];
}

@end
