//
//  WRTextView.h
//  WRTextView
//
//  Created by Patrick Walton on 4/24/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//! Project version number for WRTextView.
FOUNDATION_EXPORT double WRTextViewVersionNumber;

//! Project version string for WRTextView.
FOUNDATION_EXPORT const unsigned char WRTextViewVersionString[];

@class Document;
@class WRTextRendererView;

@interface WRTextView : NSView {}

@property(nonatomic, strong) WRTextRendererView *rendererView;
@property(nonatomic, strong) IBOutlet Document *document;
@property(nonatomic) CGFloat scale;

- (CGAffineTransform)transform;
- (void)zoomBy:(CGFloat)scale atPoint:(NSPoint)point;

@end

