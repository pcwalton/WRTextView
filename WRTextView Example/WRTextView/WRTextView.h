//
//  WRTextView.h
//  WRTextView
//
//  Created by Patrick Walton on 4/24/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <TargetConditionals.h>

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
#import <Cocoa/Cocoa.h>
#else
#import <UIKit/UIKit.h>
#endif

//! Project version number for WRTextView.
FOUNDATION_EXPORT double WRTextViewVersionNumber;

//! Project version string for WRTextView.
FOUNDATION_EXPORT const unsigned char WRTextViewVersionString[];

@protocol WRTextStorage;
@class WRImageInfo;
@class WRTextLayer;

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
@interface WRTextView : NSClipView<CALayerDelegate> {
#else
@interface WRTextView : UIScrollView<UIScrollViewDelegate> {
#endif
    NSMutableSet<WRImageInfo *> *_loadedImages;
    unsigned _animationCount;
    BOOL _initialized;
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
    WRTextLayer *_textLayer;
    NSTrackingArea *_trackingArea;
#else
    BOOL _debuggerEnabled;
#endif
}

@property(nonatomic, strong) IBOutlet id<WRTextStorage> textStorage;

- (WRTextLayer *)_textLayer;
- (void)beginAnimation;
- (void)endAnimation;
- (void)reloadText;
- (void)setDebuggerEnabled:(BOOL)enabled;
- (void)setContentSize:(CGSize)newSize;
- (void)processQueuedImages;
- (void)setNeedsDisplayInRect:(CGRect)invalidRect;
- (IBAction)scrollToBeginningOfDocument:(id)sender;
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (void)setImage:(NSImage *)image forID:(uint32_t)imageID;
- (NSView *)documentView;
#else
- (void)setImage:(UIImage *)image forID:(uint32_t)imageID;
- (UIView *)documentView;
- (void)setNeedsDisplay:(BOOL)needsDisplay;
#endif
    
@end

