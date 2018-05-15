//
//  WRVXDocument.h
//  WRTextView Example
//
//  Created by Patrick Walton on 4/11/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <pilcrow.h>
#import "WRVTextStorage.h"

struct WRTextViewSideOffsets {
    float top, right, bottom, left;
};

typedef struct WRTextViewSideOffsets WRTextViewSideOffsets;

@class WRVTextView;

@interface WRVXDocument : NSDocument<WRVTextStorage> {
    pilcrow_document_t *_document;
    NSString *_textString;
    BOOL _debuggerEnabled;
    NSMutableArray<NSFont *> *_fonts;
    WRTextViewSideOffsets _documentMargins;
    WRTextViewSideOffsets _paragraphMargins[5];
    IBOutlet NSView *formatPane;
}

@property(nonatomic, strong) IBOutlet WRVTextView *textView;
@property(nonatomic, strong) IBOutlet NSButton *debuggerToolbarButton;
@property(nonatomic, strong) IBOutlet NSButton *formatToolbarButton;
@property(nonatomic, strong) IBOutlet NSSplitView *splitView;
@property(nonatomic, strong) IBOutlet NSPopUpButton *selectorPopUpButton;
@property(nonatomic, strong) IBOutlet NSPopUpButton *fontPopUpButton;
@property(nonatomic, strong) IBOutlet NSTextField *fontSizeField;
@property(nonatomic, strong) IBOutlet NSStepper *fontSizeStepper;
@property(nonatomic, strong) IBOutlet NSTabView *formatTabView;
@property(nonatomic, strong) IBOutlet NSTextField *marginTopField;
@property(nonatomic, strong) IBOutlet NSTextField *marginRightField;
@property(nonatomic, strong) IBOutlet NSTextField *marginBottomField;
@property(nonatomic, strong) IBOutlet NSTextField *marginLeftField;

- (IBAction)toggleDebugger:(id)sender;
- (IBAction)toggleFormatPaneVisibility:(id)sender;
- (IBAction)changeFontFamily:(id)sender;
- (IBAction)changeFontSize:(id)sender;
- (IBAction)changeMargins:(id)sender;
- (IBAction)selectNewStyle:(id)sender;
- (pilcrow_document_t *)takeDocument;

@end
