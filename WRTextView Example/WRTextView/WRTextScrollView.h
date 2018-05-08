//
//  WRTextScrollView.h
//  WRTextView
//
//  Created by Patrick Walton on 5/2/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface WRTextScrollView : NSScrollView

- (IBAction)zoom:(id)sender;
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;
- (IBAction)zoomToActualSize:(id)sender;

@end
