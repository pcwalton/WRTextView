//
//  WRVXDocumentBrowserViewController.h
//  WRMobileTextView Example
//
//  Created by Patrick Walton on 4/26/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WRVXDocumentBrowserViewController :
    UIDocumentBrowserViewController<UIDocumentBrowserViewControllerDelegate>

- (void)presentDocumentAtURL:(NSURL *)documentURL;

@end
