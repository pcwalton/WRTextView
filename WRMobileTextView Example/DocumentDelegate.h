//
//  DocumentDelegate.h
//  WRMobileTextView Example
//
//  Created by Patrick Walton on 5/9/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Document;

@protocol DocumentDelegate<NSObject>

- (void)reloadDocumentText:(Document *)document;

@end
