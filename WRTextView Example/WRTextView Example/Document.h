//
//  Document.h
//  WRTextView Example
//
//  Created by Patrick Walton on 4/11/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <pilcrow.h>

@class WRTextView;

@interface Document : NSDocument {
    IBOutlet WRTextView *textView;
    IBOutlet NSView *formatPane;
}

@property(nonatomic) pilcrow_text_buf_t *textBuffer;

- (IBAction)toggleFormatPaneVisibility:(id)sender;
- (IBAction)zoom:(id)sender;

@end

