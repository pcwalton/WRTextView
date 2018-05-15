//
//  NSObject+WRVCasting.m
//  WRTextView
//
//  Created by Patrick Walton on 5/9/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "NSObject+WRVCasting.h"

@implementation NSObject(WRVCasting)

+ (instancetype)wrv_staticCast:(id)that {
    NSAssert([that isKindOfClass:self], @"Cast failed: %@ required, %@ found", self, [that class]);
    return that;
}

+ (instancetype)wrv_dynamicCast:(id)that {
    return [that isKindOfClass:self] ? that : nil;
}

@end
