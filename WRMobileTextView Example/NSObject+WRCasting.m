//
//  NSObject+WRCasting.m
//  WRMobileTextView Example
//
//  Created by Patrick Walton on 5/9/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "NSObject+WRCasting.h"

@implementation NSObject (WRCasting)

+ (instancetype)staticCast:(id)that {
    NSAssert([that isKindOfClass:self], @"Cast failed: %@ required, %@ found", self, [that class]);
    return that;
}

+ (instancetype)dynamicCast:(id)that {
    return [that isKindOfClass:self] ? that : nil;
}

@end
