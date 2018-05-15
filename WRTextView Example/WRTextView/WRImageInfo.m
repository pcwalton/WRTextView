//
//  WRImageInfo.m
//  WRTextView
//
//  Created by Patrick Walton on 5/2/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "WRImageInfo.h"

@implementation WRImageInfo

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (instancetype)initWithImage:(NSImage *)image id:(uint32_t)imageID {
#else
- (instancetype)initWithImage:(UIImage *)image id:(uint32_t)imageID {
#endif
    self = [super init];
    self->_image = image;
    self->_imageID = imageID;
    return self;
}

@end
