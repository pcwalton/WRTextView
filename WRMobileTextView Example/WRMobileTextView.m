//
//  WRMobileTextView.m
//  WRTextView
//
//  Created by Patrick Walton on 5/3/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "WRMobileTextView.h"
#import "WRMobileTextLayer.h"
#import "DocumentViewController.h"
#import "Document.h"

@implementation WRMobileTextView

+ (Class)layerClass {
    return [WRMobileTextLayer class];
}

- (WRMobileTextLayer *)_textLayer {
    return (WRMobileTextLayer *)[self layer];
}

- (void)didMoveToWindow {
    [[self _textLayer] attachedToWindow];
}

- (Document *)document {
    return [self->_documentViewController document];
}

@end
