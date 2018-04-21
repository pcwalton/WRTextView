//
//  Document.m
//  WRTextView Example
//
//  Created by Patrick Walton on 4/11/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "Document.h"
#import "WRTextView.h"

@interface Document ()

@end

@implementation Document

- (instancetype)init {
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
    }
    return self;
}

+ (BOOL)autosavesInPlace {
    return YES;
}


- (NSString *)windowNibName {
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"Document";
}


- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    [NSException raise:@"UnimplementedMethod" format:@"%@ is unimplemented", NSStringFromSelector(_cmd)];
    return nil;
}


- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
    NSString *string = [[NSString alloc] initWithContentsOfURL:absoluteURL
                                                      encoding:NSUTF8StringEncoding
                                                         error:outError];
    const char *bytes = [string UTF8String];
    if (bytes == NULL)
        return NO;
    
    pilcrow_markdown_parser_t *markdownParser = pilcrow_markdown_parser_new();
    NSFont *plainFont = [NSFont fontWithName:@"Times" size:48.0];
    NSFont *codeFont = [NSFont fontWithName:@"Menlo" size:42.0];
    NSFont *heading1Font = [NSFont systemFontOfSize:72.0 weight:NSFontWeightBold];
    NSFont *heading2Font = [NSFont systemFontOfSize:64.0 weight:NSFontWeightBold];
    pilcrow_font_t *plainPFont = pilcrow_font_new_from_native((__bridge CTFontRef)plainFont);
    pilcrow_font_t *codePFont = pilcrow_font_new_from_native((__bridge CTFontRef)codeFont);
    pilcrow_font_t *heading1PFont = pilcrow_font_new_from_native((__bridge CTFontRef)heading1Font);
    pilcrow_font_t *heading2PFont = pilcrow_font_new_from_native((__bridge CTFontRef)heading2Font);
    pilcrow_markdown_parser_set_font(markdownParser, PILCROW_FONT_SELECTOR_T_PLAIN, plainPFont);
    pilcrow_markdown_parser_set_font(markdownParser, PILCROW_FONT_SELECTOR_T_CODE, codePFont);
    pilcrow_markdown_parser_set_font(markdownParser,
                                     PILCROW_FONT_SELECTOR_T_HEADING1,
                                     heading1PFont);
    pilcrow_markdown_parser_set_font(markdownParser,
                                     PILCROW_FONT_SELECTOR_T_HEADING2,
                                     heading2PFont);
    
    self->_textBuffer = pilcrow_text_buf_new();
    pilcrow_markdown_parser_add_to_text_buf(markdownParser,
                                            (const uint8_t *)bytes,
                                            strlen(bytes),
                                            self->_textBuffer);
    return YES;
}

- (pilcrow_text_buf_t *)textBuffer {
    return self->_textBuffer;
}

- (IBAction)toggleFormatPaneVisibility:(id)sender {
    BOOL hide = ![self->formatPane isHidden];
    [self->formatPane setHidden:hide];
    if ([sender isKindOfClass:[NSButton class]])
        [(NSButton *)sender setState:hide ? NSOffState : NSOnState];
    NSView *splitView = [self->formatPane superview];
    if ([splitView isKindOfClass:[NSSplitView class]])
        [(NSSplitView *)splitView adjustSubviews];
}

- (IBAction)zoom:(id)sender {
    CGFloat factor = 1.0;
    if ([sender isKindOfClass:[NSSegmentedControl class]])
        factor = [(NSSegmentedControl *)sender selectedSegment] == 0 ? 1./1.1 : 1.1;
    if (factor == 1.0)
        return;
    NSSize textViewSize = [self->textView frame].size;
    NSPoint center = NSMakePoint(textViewSize.width * 0.5, textViewSize.height * 0.5);
    [self->textView zoomBy:factor atPoint:center];
}

@end
