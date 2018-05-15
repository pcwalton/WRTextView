//
//  NSObject+WRVCasting.h
//  WRTextView
//
//  Created by Patrick Walton on 5/9/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject(WRVCasting)

+ (instancetype)wrv_staticCast:(id)that;
+ (instancetype)wrv_dynamicCast:(id)that;

@end
