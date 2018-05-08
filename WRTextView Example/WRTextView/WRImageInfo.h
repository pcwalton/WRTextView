//
//  WRImageInfo.h
//  WRTextView
//
//  Created by Patrick Walton on 5/2/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WRImageInfo : NSObject


@property(nonatomic, strong) NSImage *image;
@property(nonatomic) uint32_t imageID;

- (instancetype)initWithImage:(NSImage *)image id:(uint32_t)imageID;

@end
