//
//  DocumentViewController.m
//  WRMobileTextView Example
//
//  Created by Patrick Walton on 4/26/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "DocumentViewController.h"
#import "Document.h"
#import "WRTextView.h"

@implementation DocumentViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Access the document
    Document *document = [self document];
    [document openWithCompletionHandler:^(BOOL success) {
        if (success) {
            // Display the content of the document:
            [[[self navigationBar] topItem] setTitle:[[[self document] fileURL] lastPathComponent]];
            NSLog(@"setting text storage: %p", self->_textView);
            [self->_textView setTextStorage:document];
            [self->_textView setNeedsDisplay:YES];
        } else {
            // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
        }
    }];
}

- (IBAction)dismissDocumentViewController {
    [self dismissViewControllerAnimated:YES completion:^{
        [self.document closeWithCompletionHandler:nil];
    }];
}

- (IBAction)toggleDebugger:(id)sender {
    self->_debuggerEnabled = !self->_debuggerEnabled;
    [self->_textView setDebuggerEnabled:self->_debuggerEnabled];

}

@end
