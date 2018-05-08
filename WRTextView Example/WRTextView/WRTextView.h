//
//  WRTextView.h
//  WRTextView
//
//  Created by Patrick Walton on 4/24/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

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
@interface WRTextView : NSClipView {
#else
@interface WRTextView : UIView {
#endif
    WRTextLayer *_textLayer;
    NSTrackingArea *_trackingArea;
    NSMutableSet<WRImageInfo *> *_loadedImages;
    unsigned _animationCount;
    BOOL _initialized;
}

@property(nonatomic, strong) IBOutlet id<WRTextStorage> textStorage;

- (void)beginAnimation;
- (void)endAnimation;
- (void)reloadText;
- (void)setDebuggerEnabled:(BOOL)enabled;
- (void)setDocumentSize:(CGSize)newSize;
- (void)processQueuedImages;
- (void)setNeedsDisplayInRect:(CGRect)invalidRect;
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (void)setImage:(NSImage *)image forID:(uint32_t)imageID;
- (NSView *)documentView;
#else
- (void)setImage:(UIImage *)image forID:(uint32_t)imageID;
- (UIView *)documentView;
#endif
    
@end

