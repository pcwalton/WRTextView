//
//  WRImageInfo.m
//  WRTextView
//
//  Created by Patrick Walton on 5/2/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "WRImageInfo.h"

@implementation WRImageInfo

- (instancetype)initWithImage:(NSImage *)image id:(uint32_t)imageID {
    self = [super init];
    self->_image = image;
    self->_imageID = imageID;
    return self;
}

@end
