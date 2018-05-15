//
//  WRVTextView.m
//  WRTextView Example
//
//  Created by Patrick Walton on 4/16/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <TargetConditionals.h>
#import <CoreText/CoreText.h>
#import "WRVTextView.h"
#import "WRVTextLayer.h"
#import "WRVImageInfo.h"

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
// Can't use the AppKit one because it's a private API...
static NSSpeechSynthesizer *gWRGlobalSpeechSynthesizer = nil;
#endif

@implementation WRVTextView

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [NSApp registerServicesMenuSendTypes:[NSArray arrayWithObject:NSStringPboardType]
                                 returnTypes:[NSArray array]];
    });
}
#endif

- (void)_setup {
    if (self->_initialized)
        return;

    self->_initialized = YES;
    self->_loadedImages = [[NSMutableSet alloc] init];
    self->_animationCount = 0;
    
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(_reshape:)
                                                name:NSViewFrameDidChangeNotification
                                              object:self];
    
    NSScrollView *scrollView = [self _scrollView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(scrollViewWillBeginDragging:)
                                                name:NSScrollViewWillStartLiveScrollNotification
                                              object:scrollView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(scrollViewDidEndDecelerating:)
                                                name:NSScrollViewDidEndLiveScrollNotification
                                              object:scrollView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(scrollViewWillBeginZooming:)
                                                name:NSScrollViewWillStartLiveMagnifyNotification
                                              object:scrollView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(scrollViewDidEndZooming:)
                                                name:NSScrollViewDidEndLiveMagnifyNotification
                                              object:scrollView];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    [bundle loadNibNamed:@"ContextMenu" owner:self topLevelObjects:nil];
#else
    [self setDelegate:self];
#endif
}

- (void)beginAnimation {
    NSLog(@"-[WRVTextLayer beginAnimation](animation count=%u)", self->_animationCount);
    if (self->_animationCount == 0)
        [[self _textLayer] setAsynchronous:YES];
    self->_animationCount++;
}

- (void)endAnimation {
    NSAssert(self->_animationCount > 0, @"WRVTextView: No animation in progress?!");
    self->_animationCount--;
    NSLog(@"-[WRVTextLayer endAnimation](animation count=%u)", self->_animationCount);
    if (self->_animationCount == 0)
        [[self _textLayer] setAsynchronous:NO];
}

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (NSScrollView *)_scrollView {
    NSView *superview = [self superview];
    return [superview isKindOfClass:[NSScrollView class]] ? (NSScrollView *)superview : nil;
}
#endif

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (void)scrollViewWillBeginDragging:(NSNotification *)notification {
#else
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
#endif
    [self beginAnimation];
}

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (void)scrollViewDidEndDecelerating:(NSNotification *)notification {
#else
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
#endif
    [self endAnimation];
}
    
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR || TARGET_OS_EMBEDDED
- (void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)willDecelerate {
    if (!willDecelerate)
        [self endAnimation];
}
#endif
    
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (void)scrollViewWillBeginZooming:(NSNotification *)notification {
#else
- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
#endif
    NSLog(@"-[WRVTextLayer scrollViewWillBeginZooming:]");
    [self beginAnimation];
}
    
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (void)scrollViewDidEndZooming:(NSNotification *)notification {
#else
- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView
                       withView:(UIView *)view
                        atScale:(CGFloat)scale {
#endif
    [self endAnimation];
}
    
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR || TARGET_OS_EMBEDDED
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return [self documentView];
}
#endif

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (void)_reshape:(NSNotification *)notification {
    [self->_textLayer reshape];
    [self setNeedsDisplay:YES];
}

- (CALayer *)makeBackingLayer {
    self->_textLayer = [WRVTextLayer layer];
    [self->_textLayer setContentsScale:[[self window] backingScaleFactor]];
    [self->_textLayer setDelegate:self];
    return self->_textLayer;
}
#else
+ (Class)layerClass {
    return [WRVTextLayer class];
}

- (void)didMoveToWindow {
    [[self _textLayer] attachedToWindow];
}
#endif
    
- (WRVTextLayer *)_textLayer {
    return (WRVTextLayer *)[self layer];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self _setup];
}

- (BOOL)isOpaque {
    return YES;
}

- (void)reloadText {
    [[self _textLayer] reloadText];
}

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (IBAction)scrollToBeginningOfDocument:(id)sender {
    CGFloat originY = [[self documentView] frame].size.height - [self frame].size.height;
    [self scrollPoint:CGPointMake(0.0, originY)];
    [self setNeedsDisplay:YES];
}

- (void)setNeedsDisplayInRect:(CGRect)invalidRect {
    [super setNeedsDisplayInRect:invalidRect];
    
    if (![self->_textLayer isAsynchronous])
        [self->_textLayer setNeedsDisplayInRect:invalidRect];
}
#else
- (IBAction)scrollToBeginningOfDocument:(id)sender {
    // TODO(pcwalton)
}

- (void)setNeedsDisplayInRect:(CGRect)invalidRect {
    [super setNeedsDisplayInRect:invalidRect];

    [[self _textLayer] setDirty];
}
#endif

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    return YES;
}

- (void)processQueuedImages {
    WRTextLayer *textLayer = [self _textLayer];
    if (textLayer == nil || ![textLayer isReady])
        return;

    for (WRVImageInfo *imageInfo in self->_loadedImages)
        [textLayer setImage:[imageInfo image] forID:[imageInfo imageID]];
    [self->_loadedImages removeAllObjects];

    [self setNeedsDisplay:YES];
}

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (id)validRequestorForSendType:(NSPasteboardType)sendType
                     returnType:(NSPasteboardType)returnType {
    if ([sendType isEqual:NSStringPboardType])
        return self;
    return [super validRequestorForSendType:sendType returnType:returnType];
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
#endif

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (void)setContentSize:(CGSize)newSize {
    [[self documentView] setFrameSize:newSize];
}
#endif

- (void)selectAll:(id)sender {
    [[self _textLayer] selectAll];
    [self setNeedsDisplay:YES];
}

- (void)setDebuggerEnabled:(BOOL)enabled {
    [[self _textLayer] setDebuggerEnabled:enabled];
    [self setNeedsDisplay:YES];
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
    NSLog(@"-[WRVTextView setImage:forID:]");
    [self->_loadedImages addObject:[[WRVImageInfo alloc] initWithImage:image id:imageID]];
    [self processQueuedImages];
}

- (NSView *)documentView {
    return [[self subviews] objectAtIndex:0];
}
#else
- (void)setImage:(UIImage *)image forID:(uint32_t)imageID {
    NSLog(@"-[WRVTextView setImage:forID:]");
    [self->_loadedImages addObject:[[WRVImageInfo alloc] initWithImage:image id:imageID]];
    [self processQueuedImages];
}

- (UIView *)documentView {
    return [[self subviews] objectAtIndex:0];
}

- (void)setNeedsDisplay:(BOOL)needsDisplay {
    if (needsDisplay)
        [self setNeedsDisplayInRect:[self bounds]];
}    
#endif

@end
