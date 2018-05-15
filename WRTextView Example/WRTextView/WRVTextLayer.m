//
//  WRVTextLayer.m
//  WRTextView Example
//
//  Created by Patrick Walton on 4/11/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#include <pthread.h>
#import <TargetConditionals.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
#import <OpenGL/gl.h>
#else
#import "WRVMobileGL.h"
#endif

#import "WRVTextLayer.h"
#import "WRVTextStorage.h"
#import "WRVTextView.h"

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
static const CFStringRef WRGLBundleIdentifier = CFSTR("com.apple.opengl");
#else
static const CFStringRef WRGLBundleIdentifier = CFSTR("com.apple.opengles");
#endif

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
static const void *getGLProcAddress(const char *symbolName) {
    CFBundleRef bundle = CFBundleGetBundleWithIdentifier(WRGLBundleIdentifier);
    NSString *symbolString = [NSString stringWithUTF8String:symbolName];
    return CFBundleGetFunctionPointerForName(bundle, (__bridge CFStringRef)symbolString);
}
#endif

static NSString *WRNSStringFromPilcrowString(pilcrow_string_t *pString) {
    if (pString == NULL)
        return nil;
    NSString *string = [[NSString alloc] initWithBytes:pilcrow_string_get_chars(pString)
                                                length:pilcrow_string_get_byte_len(pString)
                                              encoding:NSUTF8StringEncoding];
    pilcrow_string_destroy(pString);
    return string;
}

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
static const wrtv_mouse_event_kind_t WRMouseEventKindFromNSEvent(NSEvent *event) {
    switch ([event clickCount]) {
    case 2:
        return WRTV_MOUSE_EVENT_KIND_T_LEFT_DOUBLE;
    case 3:
        return WRTV_MOUSE_EVENT_KIND_T_LEFT_TRIPLE;
    }
    return WRTV_MOUSE_EVENT_KIND_T_LEFT;
}
#endif

@implementation WRVTextLayer

- (WRTextView *)_textView {
    id delegate = [self delegate];
    return [delegate isKindOfClass:[WRTextView class]] ? (WRTextView *)delegate : nil;
}

- (void)_clearGLErrors {
    while (true) {
        GLuint err = glGetError();
        if (err == GL_NO_ERROR)
            break;
        NSLog(@"warning: OpenGL ES error detected in WebRender: 0x%x", err);
    }
}

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (CGFloat)_backingScaleFactor {
    WRVTextView *textView = [self _textView];
    if (textView == nil)
        return 1.0;
    NSWindow *window = [textView window];
    return window == nil ? 1.0 : [window backingScaleFactor];
}
#else
- (CGFloat)_backingScaleFactor {
    UIView *textView = [self _textView];
    if (textView == nil)
        return 1.0;
    UIWindow *window = [textView window];
    if (window == nil)
        return 1.0;
    UIScreen *screen = [window screen];
    if (screen == nil)
        return 1.0;
    return [screen scale];
}
#endif

- (CGRect)_convertRectToBacking:(CGRect)rect {
    CGFloat factor = [self _backingScaleFactor];
    return CGRectMake(rect.origin.x * factor,
                      rect.origin.y * factor,
                      rect.size.width * factor,
                      rect.size.height * factor);
}

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (void)setDirty {
    [self setNeedsDisplay];
}
#else
- (void)setDirty {
    NSLog(@"-[WRTextLayer setDirty]");
    if (![self _ensureDisplayLink])
        return;

    if (!self->_isAsynchronous && !self->_isDirty)
        [self->_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

    self->_isDirty = YES;
}
#endif

- (void)_resizeDocument {
    float newWidth = 0, newHeight = 0;
    wrtv_view_get_layout_size(self->_webRenderView, &newWidth, &newHeight);
    CGSize newFrameSize = CGSizeMake(newWidth, newHeight);
    [[self _textView] setContentSize:newFrameSize];
}

- (void)setDelegate:(id<CALayerDelegate>)newDelegate {
    [super setDelegate:newDelegate];
    
    if (self->_webRenderView != NULL) {
        wrtv_view_destroy(self->_webRenderView);
        self->_webRenderView = NULL;
    }
    
    [self setDirty];
}

- (BOOL)_recreateWebRenderView {
    if (self->_webRenderView != NULL)
        return YES;

    CGRect frame = [self frame];
    CGRect backingFrame = [self _convertRectToBacking:frame];
    
    float devicePixelRatio = (float)[self contentsScale];
    
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
    if (devicePixelRatio == 0.0) {
        // This is what AppKit does if there's no current window (which happens during awakening
        // from the nib).
        devicePixelRatio = [[NSScreen mainScreen] backingScaleFactor];
    }
#endif

    id<WRTextStorage> textStorage = [[self _textView] textStorage];
    if (textStorage == nil) {
        NSLog(@"no text storage!");
        return NO;
    }

    pilcrow_document_t *document = [textStorage takeDocument];
    if (document == NULL)
        return NO;
    
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
    self->_webRenderView = wrtv_view_new(document,
                                         (uint32_t)ceil(backingFrame.size.width),
                                         (uint32_t)ceil(backingFrame.size.height),
                                         devicePixelRatio,
                                         frame.size.width,
                                         WRTV_API_T_OPENGL,
                                         getGLProcAddress,
                                         WRTV_VIEW_FLAGS_ENABLE_SUBPIXEL_AA);
#else
    [EAGLContext setCurrentContext:self->_glContext];
    GL(BindFramebuffer(GL_FRAMEBUFFER, self->_mainFramebuffer));
    
    self->_webRenderView = wrtv_view_new(document,
                                         (uint32_t)ceil(backingFrame.size.width),
                                         (uint32_t)ceil(backingFrame.size.height),
                                         devicePixelRatio,
                                         frame.size.width,
                                         WRTV_API_T_OPENGLES,
                                         getGLProcAddress,
                                         0);
#endif
    
    [self _clearGLErrors];

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
    CGFloat r, g, b, a;
    [[[NSColor selectedTextBackgroundColor]
      colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]] getRed:&r
                                                                green:&g
                                                                 blue:&b
                                                                alpha:&a];
    wrtv_view_set_selection_background_color(self->_webRenderView,
                                             (uint8_t)round(r * 255.0),
                                             (uint8_t)round(g * 255.0),
                                             (uint8_t)round(b * 255.0),
                                             (uint8_t)round(a * 255.0));
#endif

    [self _resizeDocument];
    [[self _textView] scrollToBeginningOfDocument:self];
    [[self _textView] processQueuedImages];

    return YES;
}

- (void)reloadText {
    NSLog(@"reloading text!");
    if (self->_webRenderView == NULL)
        return;

    pilcrow_document_t *newDocument = [[[self _textView] textStorage] takeDocument];
    if (newDocument == NULL)
        return;

    pilcrow_document_t *currentDocument = wrtv_view_get_document(self->_webRenderView);
    pilcrow_document_clear(currentDocument);
    pilcrow_document_style_copy(pilcrow_document_get_style(currentDocument),
                                pilcrow_document_get_style(newDocument));
    pilcrow_document_append_document(currentDocument, newDocument);
    wrtv_view_document_changed(self->_webRenderView);

    [self setDirty];
}

- (void)reshape {
    if (self->_webRenderView == NULL)
        return;

    CGRect newRect;
    newRect.origin = [self frame].origin;
    newRect.size = [[self _textView] frame].size;
    [self setFrame:newRect];

    if (wrtv_view_get_available_width(self->_webRenderView) == newRect.size.width)
        return;

    NSLog(@"reshape(), setting available width to %f", newRect.size.width);
    wrtv_view_set_available_width(self->_webRenderView, newRect.size.width);

    [self _resizeDocument];
}

- (BOOL)isOpaque {
    return YES;
}

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (CGLPixelFormatObj)copyCGLPixelFormatForDisplayMask:(uint32_t)displayMask {
    const CGLPixelFormatAttribute attributes[] = {
        kCGLPFADepthSize, 24,
        kCGLPFAStencilSize, 8,
        kCGLPFAColorSize, 32,
        kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute)kCGLOGLPVersion_GL4_Core,
        kCGLPFADoubleBuffer,
        kCGLPFAAccelerated,
        kCGLPFANoRecovery,
        0, 0
    };

    CGLPixelFormatObj pixelFormat = NULL;
    GLint pixelFormatCount = 0;
    CGLChoosePixelFormat(attributes, &pixelFormat, &pixelFormatCount);
    NSAssert(pixelFormatCount > 0, @"No pixel formats found!");
    return pixelFormat;
}
#endif

- (CGAffineTransform)_webrenderTransform {
    WRTextView *textView = [self _textView];

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
    CGRect viewportFrame = [textView documentVisibleRect];
    CGRect documentFrame = [[textView documentView] frame];
#else
    // TODO(pcwalton)
#endif
    
    CGAffineTransform transform = CATransform3DGetAffineTransform([self transform]);

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
    CGPoint origin = viewportFrame.origin;
    origin.y = documentFrame.size.height - viewportFrame.size.height - origin.y;
    transform = CGAffineTransformTranslate(transform, origin.x, origin.y);
#else
    CGPoint origin = [textView contentOffset];
    transform = CGAffineTransformTranslate(transform, origin.x, origin.y);

    CGFloat scale = [textView zoomScale];
    transform = CGAffineTransformScale(transform, scale, scale);
#endif

    NSLog(@"transform: scale %f, translation %f,%f", transform.a, transform.tx, transform.ty);
    return transform;
}

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (void)drawInCGLContext:(CGLContextObj)cglContext
             pixelFormat:(CGLPixelFormatObj)pixelFormat
            forLayerTime:(CFTimeInterval)layerTime
             displayTime:(const CVTimeStamp *)timestamp {
    [super drawInCGLContext:cglContext
                pixelFormat:pixelFormat
               forLayerTime:layerTime
                displayTime:timestamp];

    if (self->_webRenderView == NULL) {
        if (![self _recreateWebRenderView])
            return;
    }

    CGLSetCurrentContext(cglContext);

    CGAffineTransform transform = [self _webrenderTransform];
    NSRect frame = [self frame];
    NSRect backingFrame = [self _convertRectToBacking:frame];

    wrtv_view_set_scale(self->_webRenderView, transform.a);
    wrtv_view_set_translation(self->_webRenderView, transform.tx, transform.ty);
    wrtv_view_set_viewport_size(self->_webRenderView,
                                (uint32_t)backingFrame.size.width,
                                (uint32_t)backingFrame.size.height);

    NSLog(@"text view scale:%f content scale:%f",
          (float)transform.a,
          (float)[self contentsScale]);
    NSLog(@"frame:%f,%f for %f,%f",
          (float)frame.origin.x,
          (float)frame.origin.y,
          (float)frame.size.width,
          (float)frame.size.height);

    wrtv_view_repaint(self->_webRenderView);
    
    CGLFlushDrawable(cglContext);
    CGLSetCurrentContext(NULL);
}

- (CGPoint)_convertEventLocationToTextViewCoordinateSystem:(NSEvent *)event {
    NSView *scrollView = [[self _textView] superview];
    return [scrollView convertPoint:[event locationInWindow] fromView:nil];
}
#else
- (void)redraw {
    NSLog(@"redraw");
    
    if (self->_webRenderView == NULL)
        [self _recreateWebRenderView];

    if (self->_webRenderView != NULL) {
        [EAGLContext setCurrentContext:self->_glContext];
        GL(BindFramebuffer(GL_FRAMEBUFFER, self->_mainFramebuffer));
        
        GLint width, height;
        GL(GetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width));
        GL(GetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height));
        
        CGAffineTransform transform = [self _webrenderTransform];

        wrtv_view_set_scale(self->_webRenderView, transform.a);
        wrtv_view_set_translation(self->_webRenderView, transform.tx, transform.ty);
        wrtv_view_set_viewport_size(self->_webRenderView, (uint32_t)width, (uint32_t)height);
        
        wrtv_view_repaint(self->_webRenderView);
        [self _clearGLErrors];
        
        GL(BindRenderbuffer(GL_RENDERBUFFER, self->_colorRenderbuffer));
        [self->_glContext presentRenderbuffer:GL_RENDERBUFFER];
        [EAGLContext setCurrentContext:nil];
    } else {
        NSLog(@"no view yet!");
    }
    
    if (!self->_isAsynchronous) {
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [self->_displayLink removeFromRunLoop:runLoop forMode:NSDefaultRunLoopMode];
    }

    self->_isDirty = NO;
}
#endif

- (CGFloat)contentsScale {
    return [self _backingScaleFactor] * [self transform].m11;
}

- (NSString *)allText {
    pilcrow_string_t *string = pilcrow_document_copy_string(wrtv_view_get_document(self->_webRenderView));
    return WRNSStringFromPilcrowString(string);
}

- (NSString *)selectedText {
    if (self->_webRenderView == NULL)
        return nil;

    return WRNSStringFromPilcrowString(wrtv_view_copy_selected_text(self->_webRenderView));
}

- (void)setDebuggerEnabled:(BOOL)enabled {
    if (self->_webRenderView == NULL)
        return;

    wrtv_view_set_debugger_enabled(self->_webRenderView, enabled);
}

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (void)setImage:(NSImage *)image forID:(uint32_t)imageID {
#else
- (void)setImage:(UIImage *)image forID:(uint32_t)imageID {
#endif
    NSLog(@"-[WRTextLayer setImage:forID:]");
    NSAssert([self isReady], @"-[WRTextLayer setImage:forID:] called when not ready!");

    NSLog(@"... setting image OK");

    CGSize imageSize = [image size];
    uint32_t imageWidth = (uint32_t)imageSize.width, imageHeight = (uint32_t)imageSize.height;
    wrtv_view_set_image_size(self->_webRenderView, imageID, imageWidth, imageHeight);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef cgContext = CGBitmapContextCreate(NULL,
                                                   imageWidth,
                                                   imageHeight,
                                                   8,
                                                   imageWidth * 4,
                                                   colorSpace,
                                                   kCGImageAlphaPremultipliedLast);
    
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
    NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithCGContext:cgContext
                                                                            flipped:NO];
    [NSGraphicsContext setCurrentContext:nsContext];
#else
    // TODO(pcwalton)
#endif

    CGRect imageRect;
    imageRect.origin = CGPointZero;
    imageRect.size = imageSize;
    [image drawInRect:imageRect];

    const uint8_t *pixelData = (const uint8_t *)CGBitmapContextGetData(cgContext);
    size_t pixelDataSize = CGBitmapContextGetBytesPerRow(cgContext) * imageHeight;
    wrtv_view_set_image_data(self->_webRenderView, imageID, pixelData, pixelDataSize);
    
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
    [NSGraphicsContext setCurrentContext:nil];
#else
    // TODO(pcwalton)
#endif

    CGContextRelease(cgContext);
    CGColorSpaceRelease(colorSpace);
}

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (void)mouseDown:(NSEvent *)event {
    if (self->_webRenderView == NULL)
        return;

    NSPoint point = [self _convertEventLocationToTextViewCoordinateSystem:event];
    wrtv_mouse_event_kind_t mouseEventKind = WRMouseEventKindFromNSEvent(event);
    wrtv_view_mouse_down(self->_webRenderView, (float)point.x, (float)point.y, mouseEventKind);
}

- (void)mouseDragged:(NSEvent *)event {
    if (self->_webRenderView == NULL)
        return;
    
    NSPoint point = [self _convertEventLocationToTextViewCoordinateSystem:event];
    wrtv_view_mouse_dragged(self->_webRenderView, (float)point.x, (float)point.y);
}

- (void)mouseUp:(NSEvent *)event {
    if (self->_webRenderView == NULL)
        return;
    
    NSPoint point = [self _convertEventLocationToTextViewCoordinateSystem:event];
    wrtv_mouse_event_kind_t mouseEventKind = WRMouseEventKindFromNSEvent(event);
    wrtv_event_result_t *eventResult = wrtv_view_mouse_up(self->_webRenderView,
                                                          (float)point.x,
                                                          (float)point.y,
                                                          mouseEventKind);
    
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
}

- (void)mouseMoved:(NSEvent *)event {
    if (self->_webRenderView == NULL)
        return;
    
    NSPoint point = [self _convertEventLocationToTextViewCoordinateSystem:event];
    NSCursor *cursor = nil;
    switch (wrtv_view_get_mouse_cursor(self->_webRenderView, (float)point.x, (float)point.y)) {
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
#else
- (void)attachedToWindow {
    if (self->_glContext != nil)
        return;
    
    self->_glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext:self->_glContext];
    GL(GenFramebuffers(1, &self->_mainFramebuffer));
    GL(BindFramebuffer(GL_FRAMEBUFFER, self->_mainFramebuffer));
    GL(GenRenderbuffers(1, &self->_colorRenderbuffer));
    GL(BindRenderbuffer(GL_RENDERBUFFER, self->_colorRenderbuffer));
    [self->_glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:self];
    GL(FramebufferRenderbuffer(GL_FRAMEBUFFER,
                               GL_COLOR_ATTACHMENT0,
                               GL_RENDERBUFFER,
                               self->_colorRenderbuffer));
    GLint width, height;
    GL(GetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width));
    GL(GetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height));
    GL(GenRenderbuffers(1, &self->_depthStencilRenderbuffer));
    GL(BindRenderbuffer(GL_RENDERBUFFER, self->_depthStencilRenderbuffer));
    GL(RenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, (GLsizei)width, (GLsizei)height));
    GL(FramebufferRenderbuffer(GL_FRAMEBUFFER,
                               GL_DEPTH_STENCIL_ATTACHMENT,
                               GL_RENDERBUFFER,
                               self->_depthStencilRenderbuffer));
    GLuint framebufferStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    NSAssert(framebufferStatus == GL_FRAMEBUFFER_COMPLETE,
             @"Framebuffer incomplete: %x!", framebufferStatus);
    [EAGLContext setCurrentContext:nil];

    [self setDirty];
}
    
- (BOOL)_ensureDisplayLink {
    if (self->_displayLink != nil)
        return YES;
    UIView *view = [self _textView];
    if (view == nil) {
        NSLog(@"-[WRTextLayer _ensureDisplayLink]: no view yet");
        return NO;
    }
    UIWindow *window = [view window];
    if (window == nil) {
        NSLog(@"-[WRTextLayer _ensureDisplayLink]: no window yet");
        return NO;
    }
    UIScreen *screen = [window screen];
    if (screen == nil) {
        NSLog(@"-[WRTextLayer _ensureDisplayLink]: no screen yet");
        return NO;
    }
    self->_displayLink = [screen displayLinkWithTarget:self selector:@selector(redraw)];
    return self->_displayLink != nil;
}
    
- (void)setAsynchronous:(BOOL)isAsynchronous {
    NSLog(@"-[WRTextLayer setAsynchronous:%s]", isAsynchronous ? "YES" : "NO");

    if (![self _ensureDisplayLink])
        return;

    if (!self->_isAsynchronous && !self->_isDirty && isAsynchronous)
        [self->_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

    self->_isAsynchronous = isAsynchronous;
}
#endif

- (void)selectAll {
    if (![self isReady])
        return;

    wrtv_view_select_all(self->_webRenderView);
}

- (BOOL)isReady {
    return self->_webRenderView != NULL;
}

@end
