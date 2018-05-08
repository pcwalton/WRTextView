//
//  WRTextView.h
//  WRTextView
//
//  Created by Patrick Walton on 5/3/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Document;
@class DocumentViewController;

@interface WRMobileTextView : UIView

// FIXME(pcwalton): Don't depend on `DocumentViewController`!
@property(nonatomic, strong) IBOutlet DocumentViewController *documentViewController;

- (Document *)document;

@end
