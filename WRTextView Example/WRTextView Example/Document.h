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
    pilcrow_text_buf_t *_textBuffer;
    NSString *_textString;
    BOOL _debuggerEnabled;
    IBOutlet WRTextView *textView;
    IBOutlet NSView *formatPane;
}

@property(nonatomic, strong) IBOutlet NSButton *debuggerToolbarButton;
@property(nonatomic, strong) IBOutlet NSButton *formatToolbarButton;
@property(nonatomic, strong) IBOutlet NSPopUpButton *fontPopUpButton;

- (IBAction)toggleDebugger:(id)sender;
- (IBAction)toggleFormatPaneVisibility:(id)sender;
- (IBAction)zoom:(id)sender;
- (IBAction)changeFontFamily:(id)sender;
- (pilcrow_text_buf_t *)takeTextBuffer;

@end

