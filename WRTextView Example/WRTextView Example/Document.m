//
//  Document.m
//  WRTextView Example
//
//  Created by Patrick Walton on 4/11/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "Document.h"
#import "WRTextView.h"
#import "WindowController.h"

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
    self->_textString = [[NSString alloc] initWithContentsOfURL:absoluteURL
                                                       encoding:NSUTF8StringEncoding
                                                          error:outError];
    pilcrow_markdown_parser_t *markdownParser = pilcrow_markdown_parser_new();
    NSFont *plainFont = [NSFont fontWithName:@"Times" size:18.0];
    NSFont *codeFont = [NSFont fontWithName:@"Menlo" size:16.0];
    NSFont *heading1Font = [NSFont systemFontOfSize:36.0 weight:NSFontWeightBold];
    NSFont *heading2Font = [NSFont systemFontOfSize:24.0 weight:NSFontWeightBold];
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

    return [self _recreateTextBufferWithMarkdownParser:markdownParser];
}

- (BOOL)_recreateTextBufferWithMarkdownParser:(pilcrow_markdown_parser_t *)markdownParser {
    const char *bytes = [self->_textString UTF8String];
    if (bytes == NULL)
        return NO;

    self->_textBuffer = pilcrow_text_buf_new();
    pilcrow_markdown_parse_results_t *parseResults =
        pilcrow_markdown_parser_add_to_text_buf(markdownParser,
                                                (const uint8_t *)bytes,
                                                strlen(bytes),
                                                self->_textBuffer);
    
    uintptr_t imageCount = pilcrow_markdown_parse_results_get_image_count(parseResults);
    NSURLSession *urlSession = [NSURLSession sharedSession];

    for (uintptr_t imageIndex = 0; imageIndex < imageCount; imageIndex++) {
        uintptr_t imageURLLength = pilcrow_markdown_parse_results_get_image_url_len(parseResults,
                                                                                    imageIndex);
        uint8_t *imageURLBytes = (uint8_t *)malloc(imageURLLength + 1);
        pilcrow_markdown_parse_results_get_image_url(parseResults,
                                                     imageIndex,
                                                     imageURLBytes,
                                                     imageURLLength);
        imageURLBytes[imageURLLength] = '\0';
        NSString *imageURLString = [NSString stringWithUTF8String:(const char *)imageURLBytes];
        NSURL *imageURL = [NSURL URLWithString:imageURLString];
        NSLog(@"found image URL: %@", imageURL);

        NSURLSessionDataTask *imageDataTask =
            [urlSession dataTaskWithURL:imageURL
                      completionHandler:^(NSData *_Nullable data,
                                          NSURLResponse *_Nullable response,
                                          NSError *_Nullable error) {
            if (error != nil) {
                NSLog(@"failed to load image URL: %@", error);
                return;
            }

            NSLog(@"successfully fetched image URL: %@", [response URL]);
        }];
        [imageDataTask resume];
    }
    
    return YES;
}

- (pilcrow_text_buf_t *)takeTextBuffer {
    pilcrow_text_buf_t *textBuffer = self->_textBuffer;
    self->_textBuffer = nil;
    return textBuffer;
}

- (IBAction)toggleDebugger:(id)sender {
    self->_debuggerEnabled = !self->_debuggerEnabled;
    [self->textView setDebuggerEnabled:self->_debuggerEnabled];
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

- (void)makeWindowControllers {
    [self addWindowController:[[WindowController alloc] initWithWindowNibName:[self windowNibName]
                                                                        owner:self]];
}

- (IBAction)changeFontFamily:(id)sender {
    NSPopUpButton *fontPopUpButton = sender;
    
    pilcrow_markdown_parser_t *markdownParser = pilcrow_markdown_parser_new();
    NSFont *plainFont = [NSFont fontWithName:[fontPopUpButton titleOfSelectedItem] size:18.0];
    NSFont *codeFont = [NSFont fontWithName:@"Menlo" size:16.0];
    NSFont *heading1Font = [NSFont systemFontOfSize:36.0 weight:NSFontWeightBold];
    NSFont *heading2Font = [NSFont systemFontOfSize:24.0 weight:NSFontWeightBold];
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
    
    [self _recreateTextBufferWithMarkdownParser:markdownParser];
    
    [self->textView reloadText];
}

@end
