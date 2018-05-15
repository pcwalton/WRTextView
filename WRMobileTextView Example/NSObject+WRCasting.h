//
//  NSObject+WRCasting.h
//  WRMobileTextView Example
//
//  Created by Patrick Walton on 5/9/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (WRCasting)

+ (instancetype)staticCast:(id)that;
+ (instancetype)dynamicCast:(id)that;

@end
