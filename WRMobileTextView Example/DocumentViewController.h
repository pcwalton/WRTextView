//
//  DocumentViewController.h
//  WRMobileTextView Example
//
//  Created by Patrick Walton on 4/26/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Document;
@class WRTextView;

@interface DocumentViewController : UIViewController {
    BOOL _debuggerEnabled;
}

@property(strong) Document *document;
@property(nonatomic, strong) IBOutlet UINavigationBar *navigationBar;
@property(nonatomic, strong) IBOutlet WRTextView *textView;

- (IBAction)toggleDebugger:(id)sender;

@end
