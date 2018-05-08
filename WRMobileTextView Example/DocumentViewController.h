//
//  DocumentViewController.h
//  WRMobileTextView Example
//
//  Created by Patrick Walton on 4/26/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Document;

@interface DocumentViewController : UIViewController

@property(strong) Document *document;
@property(nonatomic, strong) IBOutlet UINavigationBar *navigationBar;

@end
