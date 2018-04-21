//
//  WRTextView.h
//  WRTextView Example
//
//  Created by Patrick Walton on 4/16/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Document;
@class WRTextRendererView;

@interface WRTextView : NSView {}

@property(nonatomic, strong) WRTextRendererView *rendererView;
@property(nonatomic, strong) IBOutlet Document *document;
@property(nonatomic) CGFloat scale;

- (CGAffineTransform)transform;
- (void)zoomBy:(CGFloat)scale atPoint:(NSPoint)point;

@end
