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

static const wrtv_mouse_event_kind_t WRMouseEventKindFromNSEvent(NSEvent *event) {
    switch ([event clickCount]) {
        case 2:
            return WRTV_MOUSE_EVENT_KIND_T_LEFT_DOUBLE;
    }
    return WRTV_MOUSE_EVENT_KIND_T_LEFT;
}

static NSString *WRNSStringFromPilcrowString(pilcrow_string_t *pString) {
    if (pString == NULL)
        return nil;
    NSString *string = [[NSString alloc] initWithBytes:pilcrow_string_get_chars(pString)
                                                length:pilcrow_string_get_byte_len(pString)
                                              encoding:NSUTF8StringEncoding];
    pilcrow_string_destroy(pString);
    return string;
}

// Can't use the AppKit one because it's a private API...
static NSSpeechSynthesizer *gWRGlobalSpeechSynthesizer = nil;

@implementation WRTextRendererView

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [NSApp registerServicesMenuSendTypes:[NSArray arrayWithObject:NSStringPboardType]
                                 returnTypes:[NSArray array]];
    });
}

- (id)initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat *)pixelFormat {
    self = [super initWithFrame:frameRect pixelFormat:pixelFormat];
    
    [self setPixelFormat:pixelFormat];
    NSOpenGLContext *glContext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat
                                                            shareContext:nil];
    [self setOpenGLContext:glContext];
    [self setWantsBestResolutionOpenGLSurface:YES];

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    [bundle loadNibNamed:@"ContextMenu" owner:self topLevelObjects:nil];
    
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

    NSOpenGLContext *glContext = [self openGLContext];
    [glContext makeCurrentContext];
    GLint one = 1;
    CGLSetParameter([glContext CGLContextObj], kCGLCPSwapInterval, &one);

    NSRect frame = [self frame];
    NSRect backingFrame = [self convertRectToBacking:frame];
    
    float devicePixelRatio = (float)[[self window] backingScaleFactor];
    if (devicePixelRatio == 0.0) {
        // This is what AppKit does if there's no current window (which happens during awakening
        // from the nib).
        devicePixelRatio = [[NSScreen mainScreen] backingScaleFactor];
    }
    
    pilcrow_document_t *document = [[textView document] takeDocument];
    if (document == NULL)
        return;

    self->_wrView = wrtv_view_new(document,
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
    NSSize newFrameSize = NSMakeSize(newWidth, newHeight);
    [self->_textView setFrameSize:newFrameSize];
    [self->_textView scrollToBeginningOfDocument:self];
    NSLog(@"layout size: %f,%f", newWidth, newHeight);

    [self setNeedsDisplay:YES];
}

- (void)reloadText {
    NSLog(@"reloading text!");
    if (self->_wrView == NULL)
        return;
    pilcrow_document_t *newDocument = [[self->_textView document] takeDocument];
    if (newDocument == NULL)
        return;
    pilcrow_document_t *currentDocument = wrtv_view_get_document(self->_wrView);
    pilcrow_document_clear(currentDocument);
    pilcrow_document_style_copy(pilcrow_document_get_style(currentDocument),
                                pilcrow_document_get_style(newDocument));
    pilcrow_document_append_document(currentDocument, newDocument);
    wrtv_view_document_changed(self->_wrView);
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

    wrtv_mouse_event_kind_t mouseEventKind = WRMouseEventKindFromNSEvent(event);
    wrtv_view_mouse_down(self->_wrView, (float)point.x, (float)point.y, mouseEventKind);

    [self setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)event {
    if (self->_wrView == NULL)
        return;
    NSPoint point = [self _convertEventLocationToTextViewCoordinateSystem:event];
    wrtv_view_mouse_dragged(self->_wrView, (float)point.x, (float)point.y);
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event {
    if (self->_wrView == NULL)
        return;

    NSPoint point = [self _convertEventLocationToTextViewCoordinateSystem:event];
    wrtv_mouse_event_kind_t mouseEventKind = WRMouseEventKindFromNSEvent(event);
    wrtv_event_result_t *eventResult = wrtv_view_mouse_up(self->_wrView,
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
    if (self->_wrView != NULL)
        wrtv_view_select_all(self->_wrView);
    [self setNeedsDisplay:YES];
}

- (NSString *)_allText {
    pilcrow_string_t *string = pilcrow_document_copy_string(wrtv_view_get_document(self->_wrView));
    return WRNSStringFromPilcrowString(string);
}

- (NSString *)_selectedText {
    if (self->_wrView == NULL)
        return nil;
    return WRNSStringFromPilcrowString(wrtv_view_copy_selected_text(self->_wrView));
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pasteboard types:(NSArray *)types {
    if (![types containsObject:NSStringPboardType])
        return NO;
    NSString *string = [self _selectedText];
    [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    return [pasteboard setString:string forType:NSStringPboardType];
}

- (IBAction)copy:(id)sender {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [self writeSelectionToPasteboard:pasteboard
                               types:[NSArray arrayWithObject:NSStringPboardType]];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)setDebuggerEnabled:(BOOL)enabled {
    if (self->_wrView != NULL)
        wrtv_view_set_debugger_enabled(self->_wrView, enabled);
    [self setNeedsDisplay:YES];
}

- (id)validRequestorForSendType:(NSPasteboardType)sendType
                     returnType:(NSPasteboardType)returnType {
    if ([sendType isEqual:NSStringPboardType])
        return self;
    return [super validRequestorForSendType:sendType returnType:returnType];
}

- (IBAction)startSpeaking:(id)sender {
    NSString *string = [self _selectedText];
    if (string == nil)
        string = [self _allText];
    if (gWRGlobalSpeechSynthesizer == nil)
        gWRGlobalSpeechSynthesizer = [[NSSpeechSynthesizer alloc] initWithVoice:nil];
    [gWRGlobalSpeechSynthesizer startSpeakingString:string];
}

- (IBAction)stopSpeaking:(id)sender {
    if (gWRGlobalSpeechSynthesizer != nil)
        [gWRGlobalSpeechSynthesizer stopSpeaking];
}

/*
- (void)rightMouseDown:(NSEvent *)event {
    if (self->_contextMenu == nil) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        [bundle loadNibNamed:@"ContextMenu" owner:self topLevelObjects:nil];
    }
    [NSMenu popUpContextMenu:self->_contextMenu withEvent:event forView:self];
}*/

@end
