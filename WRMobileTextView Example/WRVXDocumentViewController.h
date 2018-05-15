//
//  WRVXDocumentViewController.h
//  WRMobileTextView Example
//
//  Created by Patrick Walton on 4/26/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <UIKit/UIKit.h>

@class WRVXDocument;
@class WRVTextView;

@interface WRVXDocumentViewController : UIViewController {
    BOOL _debuggerEnabled;
}

@property(strong) WRVXDocument *document;
@property(nonatomic, strong) IBOutlet UINavigationBar *navigationBar;
@property(nonatomic, strong) IBOutlet WRVTextView *textView;

- (IBAction)toggleDebugger:(id)sender;

@end
