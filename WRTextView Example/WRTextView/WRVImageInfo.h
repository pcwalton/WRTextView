//
//  WRImageInfo.h
//  WRTextView
//
//  Created by Patrick Walton on 5/2/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR || TARGET_OS_EMBEDDED
@class UIImage;
#endif

@interface WRVImageInfo : NSObject

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
@property(nonatomic, strong) NSImage *image;
#else
@property(nonatomic, strong) UIImage *image;
#endif
@property(nonatomic) uint32_t imageID;

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
- (instancetype)initWithImage:(NSImage *)image id:(uint32_t)imageID;
#else
- (instancetype)initWithImage:(UIImage *)image id:(uint32_t)imageID;
#endif

@end
