//
//  FontFamilyTableViewController.h
//  WRMobileTextView Example
//
//  Created by Patrick Walton on 5/9/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FontFamilyTableViewController : UITableViewController<UITableViewDataSource,
                                                                 UITableViewDelegate> {
    NSArray<NSString *> *_familyNames;
    pilcrow_inline_selector_t _inlineSelector;
}

- (IBAction)selectFont:(id)sender;

@end
