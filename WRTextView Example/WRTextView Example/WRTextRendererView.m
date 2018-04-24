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
    return CFBundleGetFunctionPointerForName(bundle, (__bridge CFStringRef)symbolString);
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

- (void)updateTrackingAreas {
    if (self->_trackingArea != nil) {
        [self removeTrackingArea:self->_trackingArea];
        self->_trackingArea = nil;
    }
    
    NSTrackingAreaOptions trackingAreaOptions = NSTrackingActiveInKeyWindow |
        NSTrackingInVisibleRect | NSTrackingMouseMoved;
    self->_trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds]
                                                       options:trackingAreaOptions
                                                         owner:self
                                                      userInfo:nil];
    [self addTrackingArea:self->_trackingArea];
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
    
    float devicePixelRatio = (float)[[self window] backingScaleFactor];
    if (devicePixelRatio == 0.0) {
        // This is what AppKit does if there's no current window (which happens during awakening
        // from the nib).
        devicePixelRatio = [[NSScreen mainScreen] backingScaleFactor];
    }

    self->_wrView = wrtv_view_new(textBuffer,
                                  (uint32_t)ceil(backingFrame.size.width),
                                  (uint32_t)ceil(backingFrame.size.height),
                                  devicePixelRatio,
                                  frame.size.width,
                                  getGLProcAddress);

    CGFloat r, g, b, a;
    [[[NSColor selectedTextBackgroundColor]
      colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]] getRed:&r
                                                                green:&g
                                                                 blue:&b
                                                                alpha:&a];
    wrtv_view_set_selection_background_color(self->_wrView,
                                             (uint8_t)round(r * 255.0),
                                             (uint8_t)round(g * 255.0),
                                             (uint8_t)round(b * 255.0),
                                             (uint8_t)round(a * 255.0));

    float newWidth, newHeight;
    wrtv_view_get_layout_size(self->_wrView, &newWidth, &newHeight);
    NSSize newFrameSize = [self convertSizeFromBacking:NSMakeSize(newWidth, newHeight)];
    [self->_textView setFrameSize:newFrameSize];
    [self->_textView scrollToBeginningOfDocument:self];
    NSLog(@"layout size: %f,%f", newWidth, newHeight);

    [self setNeedsDisplay:YES];
}

- (void)reshape {
    [super reshape];

    if (self->_wrView == NULL)
        return;
    
    float newAvailableWidth = [self frame].size.width;
    if (wrtv_view_get_available_width(self->_wrView) == newAvailableWidth)
        return;
    NSLog(@"reshape(), setting available width");
    wrtv_view_set_available_width(self->_wrView, newAvailableWidth);
    [self setNeedsDisplay:YES];
}

- (void)update {
    [super update];
    [self setNeedsDisplay:YES];
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
    
    if (self->_wrView == NULL)
        return;
    
    NSOpenGLContext *glContext = [self openGLContext];
    [glContext makeCurrentContext];
    
    CGAffineTransform transform = [self->_textView transform];
    NSRect frame = [self frame];
    NSRect backingFrame = [self convertRectToBacking:frame];

    wrtv_view_set_scale(self->_wrView, transform.a);
    wrtv_view_set_translation(self->_wrView, transform.tx, transform.ty);
    wrtv_view_set_viewport_size(self->_wrView,
                                (uint32_t)backingFrame.size.width,
                                (uint32_t)backingFrame.size.height);

    NSLog(@"text view scale:%f", (float)[self->_textView scale]);
    NSLog(@"frame:%f,%f for %f,%f",
          (float)frame.origin.x,
          (float)frame.origin.y,
          (float)frame.size.width,
          (float)frame.size.height);

    wrtv_view_repaint(self->_wrView);
    
    [glContext flushBuffer];
}

- (void)mouseDown:(NSEvent *)event {
    if (self->_wrView == NULL)
        return;
    NSPoint point = [self _convertEventLocationToTextViewCoordinateSystem:event];
    
    wrtv_view_mouse_down(self->_wrView, (float)point.x, (float)point.y);
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event {
    if (self->_wrView == NULL)
        return;
    NSPoint point = [self _convertEventLocationToTextViewCoordinateSystem:event];
    
    wrtv_event_result_t *eventResult = wrtv_view_mouse_up(self->_wrView,
                                                          (float)point.x,
                                                          (float)point.y);
    switch (wrtv_event_result_get_type(eventResult)) {
    case WRTV_EVENT_RESULT_OPEN_URL: {
        size_t length = wrtv_event_result_get_string_len(eventResult);
        uint8_t *buffer = malloc(length + 1);
        wrtv_event_result_get_string(eventResult, buffer, length);
        buffer[length] = '\0';
        NSString *string = [NSString stringWithUTF8String:(char *)buffer];
        NSURL *url = [NSURL URLWithString:string];
        [[NSWorkspace sharedWorkspace] openURL:url];
        free(buffer);
        break;
    }
            
    case WRTV_EVENT_RESULT_NONE:
        break;
    }

    [self setNeedsDisplay:YES];
}

- (NSPoint)_convertEventLocationToTextViewCoordinateSystem:(NSEvent *)event {
    NSView *clipView = [[self superview] superview];
    NSView *scrollView = [clipView superview];
    return [scrollView convertPoint:[event locationInWindow] fromView:nil];
}

- (void)mouseMoved:(NSEvent *)event {
    if (self->_wrView == NULL)
        return;
    NSPoint point = [self _convertEventLocationToTextViewCoordinateSystem:event];

    NSCursor *cursor = nil;
    switch (wrtv_view_get_mouse_cursor(self->_wrView, (float)point.x, (float)point.y)) {
    case WRTV_MOUSE_CURSOR_T_POINTER:
        cursor = [NSCursor pointingHandCursor];
        break;
    case WRTV_MOUSE_CURSOR_T_TEXT:
        cursor = [NSCursor IBeamCursor];
        break;
    default:
        cursor = [NSCursor arrowCursor];
    }

    [cursor set];
}

- (void)mouseExited:(NSEvent *)event {
    [[NSCursor arrowCursor] set];
}

- (void)selectAll:(id)sender {
    wrtv_view_select_all(self->_wrView);
    [self setNeedsDisplay:YES];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

@end
