//
//  WRTextView.m
//  WRTextView Example
//
//  Created by Patrick Walton on 4/16/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "WRTextView.h"
#import "WRTextLayer.h"
#import "WRImageInfo.h"

// Can't use the AppKit one because it's a private API...
static NSSpeechSynthesizer *gWRGlobalSpeechSynthesizer = nil;

@implementation WRTextView

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [NSApp registerServicesMenuSendTypes:[NSArray arrayWithObject:NSStringPboardType]
                                 returnTypes:[NSArray array]];
    });
}

- (void)_setup {
    if (self->_initialized)
        return;
    self->_initialized = YES;
    
    self->_loadedImages = [[NSMutableSet alloc] init];

#if 0
    NSTimer *debugTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                          repeats:YES
                                                            block:^(NSTimer * _Nonnull timer) {
        NSResponder *responder = [[self window] firstResponder];
        while (responder != nil) {
           NSLog(@"%@", responder);
           responder = [responder nextResponder];
       }
    }];
#endif

    self->_animationCount = 0;
    
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(_reshape:)
                                                name:NSViewFrameDidChangeNotification
                                              object:self];
    
    NSScrollView *scrollView = [self _scrollView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(_panZoomStarted:)
                                                name:NSScrollViewWillStartLiveScrollNotification
                                              object:scrollView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(_panZoomFinished:)
                                                name:NSScrollViewDidEndLiveScrollNotification
                                              object:scrollView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(_panZoomStarted:)
                                                name:NSScrollViewWillStartLiveMagnifyNotification
                                              object:scrollView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(_panZoomFinished:)
                                                name:NSScrollViewDidEndLiveMagnifyNotification
                                              object:scrollView];
#endif
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    [bundle loadNibNamed:@"ContextMenu" owner:self topLevelObjects:nil];
}

- (void)beginAnimation {
    if (self->_animationCount == 0) {
        [self->_textLayer setAsynchronous:YES];
        [self->_textLayer setNeedsDisplay];
    }
    self->_animationCount++;
}

- (void)endAnimation {
    NSAssert(self->_animationCount > 0, @"WRTextView: No animation in progress?!");
    self->_animationCount--;
    if (self->_animationCount == 0) {
        [self->_textLayer setAsynchronous:NO];
        [self->_textLayer setNeedsDisplay];
    }
}

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (void)_panZoomStarted:(NSNotification *)notification {
    [self beginAnimation];
}

- (void)_panZoomFinished:(NSNotification *)notification {
    [self endAnimation];
}

- (void)_reshape:(NSNotification *)notification {
    [self->_textLayer reshape];
    [self setNeedsDisplay:YES];
}

- (CALayer *)makeBackingLayer {
    self->_textLayer = [WRTextLayer layer];
    [self->_textLayer setContentsScale:[[self window] backingScaleFactor]];
    [self->_textLayer setTextView:self];
    return self->_textLayer;
}
#else
+ (Class)layerClass {
    return [WRTextLayer class];
}

- (WRTextLayer *)_textLayer {
    return (WRTextLayer *)[self layer];
}

- (void)didMoveToWindow {
    [[self _textLayer] attachedToWindow];
}
#endif

- (void)awakeFromNib {
    [self _setup];
}

- (BOOL)isOpaque {
    return YES;
}

- (void)reloadText {
    [self->_textLayer reloadText];
}

- (NSScrollView *)_scrollView {
    NSView *superview = [self superview];
    return [superview isKindOfClass:[NSScrollView class]] ? (NSScrollView *)superview : nil;
}

- (void)scrollToBeginningOfDocument:(id)sender {
    CGFloat originY = [[self documentView] frame].size.height - [self frame].size.height;
    [self scrollPoint:NSMakePoint(0.0, originY)];
    [self setNeedsDisplay:YES];
}

- (void)setNeedsDisplayInRect:(CGRect)invalidRect {
    [super setNeedsDisplayInRect:invalidRect];

    if (![self->_textLayer isAsynchronous])
        [self->_textLayer setNeedsDisplayInRect:invalidRect];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    return YES;
}

- (void)processQueuedImages {
    if (self->_textLayer == NULL || ![self->_textLayer isReady])
        return;

    for (WRImageInfo *imageInfo in self->_loadedImages)
        [self->_textLayer setImage:[imageInfo image] forID:[imageInfo imageID]];
    [self->_loadedImages removeAllObjects];

    [self setNeedsDisplay:YES];
}

- (id)validRequestorForSendType:(NSPasteboardType)sendType
                     returnType:(NSPasteboardType)returnType {
    if ([sendType isEqual:NSStringPboardType])
        return self;
    return [super validRequestorForSendType:sendType returnType:returnType];
}

- (void)setDocumentSize:(CGSize)newSize {
    [[self documentView] setFrameSize:newSize];
}

- (void)selectAll:(id)sender {
    [self->_textLayer selectAll];
    [self setNeedsDisplay:YES];
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pasteboard types:(NSArray *)types {
    if (![types containsObject:NSStringPboardType])
        return NO;
    NSString *string = [self->_textLayer selectedText];
    [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    return [pasteboard setString:string forType:NSStringPboardType];
}

- (IBAction)copy:(id)sender {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [self writeSelectionToPasteboard:pasteboard
                               types:[NSArray arrayWithObject:NSStringPboardType]];
}

- (void)setDebuggerEnabled:(BOOL)enabled {
    [self->_textLayer setDebuggerEnabled:enabled];
    [self setNeedsDisplay:YES];
}

- (IBAction)startSpeaking:(id)sender {
    NSString *string = [self->_textLayer selectedText];
    if (string == nil)
        string = [self->_textLayer allText];
    if (gWRGlobalSpeechSynthesizer == nil)
        gWRGlobalSpeechSynthesizer = [[NSSpeechSynthesizer alloc] initWithVoice:nil];
    [gWRGlobalSpeechSynthesizer startSpeakingString:string];
}

- (IBAction)stopSpeaking:(id)sender {
    if (gWRGlobalSpeechSynthesizer != nil)
        [gWRGlobalSpeechSynthesizer stopSpeaking];
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

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (void)mouseDown:(NSEvent *)event {
    [[self window] makeFirstResponder:self];
    [self->_textLayer mouseDown:event];
    [self setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)event {
    [self->_textLayer mouseDragged:event];
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event {
    [self->_textLayer mouseUp:event];
    [self setNeedsDisplay:YES];
}

- (void)mouseMoved:(NSEvent *)event {
    [self->_textLayer mouseMoved:event];
}

- (void)mouseExited:(NSEvent *)event {
    [[NSCursor arrowCursor] set];
}

- (void)setImage:(NSImage *)image forID:(uint32_t)imageID {
    NSLog(@"-[WRTextView setImage:forID:]");
    [self->_loadedImages addObject:[[WRImageInfo alloc] initWithImage:image id:imageID]];
    [self processQueuedImages];
}

- (NSView *)documentView {
    return [[self subviews] objectAtIndex:0];
}
#else
- (void)setImage:(UIImage *)image forID:(uint32_t)imageID {
    NSLog(@"-[WRTextView setImage:forID:]");
    [self->_loadedImages addObject:[[WRImageInfo alloc] initWithImage:image id:imageID]];
    [self processQueuedImages];
}

- (UIView *)documentView {
    return [[self subviews] objectAtIndex:0];
}
#endif

@end
