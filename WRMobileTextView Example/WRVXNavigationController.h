//
//  WRVXNavigationController.h
//  WRMobileTextView Example
//
//  Created by Patrick Walton on 5/9/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <UIKit/UIKit.h>

@class WRVXDocumentViewController;

@interface WRVXNavigationController : UINavigationController

- (WRVXDocumentViewController *)documentViewController;

@end
