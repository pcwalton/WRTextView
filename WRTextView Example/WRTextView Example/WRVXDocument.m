//
//  WRVXDocument.m
//  WRTextView Example
//
//  Created by Patrick Walton on 4/11/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "WRVXDocument.h"
#import "WRVXWindowController.h"
#import "WRVTextView.h"
#import "NSObject+WRVCasting.h"

#define WRVX_DEFAULT_FORMAT_PANE_SIZE   250.0

#define WRVX_SELECTOR_KIND_DOCUMENT     0
#define WRVX_SELECTOR_KIND_PARAGRAPH    1
#define WRVX_SELECTOR_KIND_INLINE       2

struct WRVXSelector {
    uint8_t selector;
    uint8_t kind;
};

typedef struct WRVXSelector WRVXSelector;

@implementation WRVXDocument

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

- (uint8_t)_paragraphStyleCount {
    return (uint8_t)(sizeof(self->_paragraphMargins) / sizeof(self->_paragraphMargins[0]));
}

- (void)_populateDefaultStyles {
    self->_fonts = [NSMutableArray arrayWithObjects:
                    [NSFont fontWithName:@"Times" size:18.0],
                    [NSFont fontWithName:@"Menlo" size:16.0],
                    [NSFont systemFontOfSize:36.0 weight:NSFontWeightBold],
                    [NSFont systemFontOfSize:24.0 weight:NSFontWeightBold],
                    nil];
    self->_documentMargins.left = self->_documentMargins.right = 6.0;
    self->_documentMargins.bottom = self->_documentMargins.top = 0.0;

    size_t paragraphStyleCount = [self _paragraphStyleCount];
    for (size_t paragraphStyleIndex = 0;
         paragraphStyleIndex < paragraphStyleCount;
         paragraphStyleIndex++) {
        WRTextViewSideOffsets *sideOffsets = &self->_paragraphMargins[paragraphStyleIndex];
        sideOffsets->top = sideOffsets->right = sideOffsets->bottom = sideOffsets->left = 0.0;
    }
}

- (pilcrow_markdown_parser_t *)_createMarkdownParser {
    pilcrow_markdown_parser_t *markdownParser = pilcrow_markdown_parser_new();
 
    uint32_t fontCount = (uint32_t)[self->_fonts count];
    for (uint32_t index = 0; index < fontCount; index++) {
        NSFont *font = [self->_fonts objectAtIndex:index];
        pilcrow_font_t *pFont = pilcrow_font_new_from_native((__bridge CTFontRef)font);
        pilcrow_markdown_parser_set_font(markdownParser, (pilcrow_inline_selector_t)index, pFont);
    }
    
    uint32_t paragraphStyleCount = (uint32_t)[self _paragraphStyleCount];
    for (uint32_t index = 0; index < paragraphStyleCount; index++) {
        pilcrow_paragraph_style_t *style =
            pilcrow_markdown_parser_get_paragraph_style(markdownParser, index);
        WRTextViewSideOffsets *margins = &self->_paragraphMargins[index];
        pilcrow_paragraph_style_set_margin(style,
                                           margins->top,
                                           margins->right,
                                           margins->bottom,
                                           margins->left);
    }
    
    return markdownParser;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
    self->_textString = [[NSString alloc] initWithContentsOfURL:absoluteURL
                                                       encoding:NSUTF8StringEncoding
                                                          error:outError];
    [self _populateDefaultStyles];
    pilcrow_markdown_parser_t *markdownParser = [self _createMarkdownParser];
    return [self _recreateTextBufferWithMarkdownParser:markdownParser];
}

- (BOOL)_recreateTextBufferWithMarkdownParser:(pilcrow_markdown_parser_t *)markdownParser {
    const char *bytes = [self->_textString UTF8String];
    if (bytes == NULL)
        return NO;

    self->_document = pilcrow_document_new();

    pilcrow_document_style_t *documentStyle = pilcrow_document_get_style(self->_document);
    pilcrow_document_style_set_margin(documentStyle,
                                      self->_documentMargins.top,
                                      self->_documentMargins.right,
                                      self->_documentMargins.bottom,
                                      self->_documentMargins.left);
    
    pilcrow_markdown_parse_results_t *parseResults =
        pilcrow_markdown_parser_add_to_document(markdownParser,
                                                (const uint8_t *)bytes,
                                                strlen(bytes),
                                                self->_document);

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
        NSURL *imageURL = [NSURL URLWithString:imageURLString relativeToURL:[self fileURL]];
        NSLog(@"found image URL: %@", imageURL);

        uintptr_t thisImageIndex = imageIndex;
    
        NSURLSessionDataTask *imageDataTask =
            [urlSession dataTaskWithURL:imageURL
                      completionHandler:^(NSData *_Nullable data,
                                          NSURLResponse *_Nullable response,
                                          NSError *_Nullable error) {
                if (error != nil) {
                    NSLog(@"failed to load image URL: %@", error);
                    return;
                }

                NSLog(@"successfully fetched image URL: %@ index: %u",
                      [response URL],
                      (unsigned)imageIndex);

                NSDictionary *imageInfo =
                    [NSDictionary dictionaryWithObjectsAndKeys:
                     [NSNumber numberWithUnsignedInteger:thisImageIndex], @"ImageID",
                     [[NSImage alloc] initWithData:data], @"Image",
                     nil];

                [self performSelectorOnMainThread:@selector(_imageLoaded:)
                                       withObject:imageInfo
                                    waitUntilDone:NO];
            }];
        [imageDataTask resume];
    }
    
    return YES;
}

- (pilcrow_document_t *)takeDocument {
    pilcrow_document_t *document = self->_document;
    self->_document = nil;
    return document;
}

- (IBAction)toggleDebugger:(id)sender {
    self->_debuggerEnabled = !self->_debuggerEnabled;
    [self->_debuggerToolbarButton setState:self->_debuggerEnabled ? NSOnState : NSOffState];
    [self->_textView setDebuggerEnabled:self->_debuggerEnabled];
}

- (IBAction)toggleFormatPaneVisibility:(id)sender {
    NSSplitView *splitView = [NSSplitView wrv_dynamicCast:[self->formatPane superview]];

    BOOL collapse = ![splitView isSubviewCollapsed:self->formatPane];
    [self->_formatToolbarButton setState:collapse ? NSOffState : NSOnState];

    CGFloat position = [splitView frame].size.width;
    if (collapse)
        position -= WRVX_DEFAULT_FORMAT_PANE_SIZE;
    [splitView setPosition:position ofDividerAtIndex:0];
}

- (void)makeWindowControllers {
    [self addWindowController:[[WRVXWindowController alloc]
                               initWithWindowNibName:[self windowNibName] owner:self]];
}

- (WRVXSelector)_currentSelector {
    NSInteger tag = [self->_selectorPopUpButton selectedTag];
    WRVXSelector selector;
    selector.kind = (tag >> 8);
    selector.selector = (tag & 0xff);
    return selector;
}

- (void)_recreateTextBufferAndReloadText {
    pilcrow_markdown_parser_t *markdownParser = [self _createMarkdownParser];
    [self _recreateTextBufferWithMarkdownParser:markdownParser];
    [self->_textView reloadText];
}

- (void)_updateFont {
    uint32_t fontSelector = (uint32_t)[self _currentSelector].selector;
    NSString *familyName = [self->_fontPopUpButton titleOfSelectedItem];
    CGFloat size = [self->_fontSizeField doubleValue];
    NSFont *font = [NSFont fontWithName:familyName size:size];
    [self->_fonts replaceObjectAtIndex:fontSelector withObject:font];

    [self _recreateTextBufferAndReloadText];
}

- (void)_updateMargins:(WRTextViewSideOffsets *)destMargins {
    destMargins->top = [self->_marginTopField floatValue];
    destMargins->right = [self->_marginRightField floatValue];
    destMargins->bottom = [self->_marginBottomField floatValue];
    destMargins->left = [self->_marginLeftField floatValue];
    
    [self _recreateTextBufferAndReloadText];
}

- (void)_updateDocumentStyle {
    [self _updateMargins:&self->_documentMargins];
}

- (void)_updateParagraphStyle {
    uint32_t paragraphStyleCount = [self _paragraphStyleCount];
    uint8_t paragraphSelector = (uint8_t)[self _currentSelector].selector;
    if (paragraphSelector >= paragraphStyleCount)
        paragraphSelector = paragraphStyleCount - 1;
    [self _updateMargins:&self->_paragraphMargins[paragraphSelector]];
}

- (IBAction)changeFontFamily:(id)sender {
    [self _updateFont];
}

- (IBAction)changeFontSize:(id)sender {
    CGFloat newSize = [sender doubleValue];
    [self->_fontSizeStepper setDoubleValue:newSize];
    [self->_fontSizeField setDoubleValue:newSize];

    [self _updateFont];
}

- (IBAction)changeMargins:(id)sender {
    switch ([self _currentSelector].kind) {
    case WRVX_SELECTOR_KIND_DOCUMENT:
        [self _updateDocumentStyle];
        break;
    case WRVX_SELECTOR_KIND_PARAGRAPH:
        [self _updateParagraphStyle];
        break;
    }
}

- (IBAction)selectNewStyle:(id)sender {
    WRVXSelector selector = [self _currentSelector];
    
    NSInteger tabIndex = selector.kind == WRVX_SELECTOR_KIND_INLINE ? 1 : 0;
    [self->_formatTabView selectTabViewItemAtIndex:tabIndex];

    switch (selector.kind) {
    case WRVX_SELECTOR_KIND_INLINE: {
        NSFont *font = [self->_fonts objectAtIndex:selector.selector];
        CGFloat size = [font pointSize];
        [self->_fontSizeField setDoubleValue:size];
        [self->_fontSizeStepper setDoubleValue:size];
        
        NSString *familyName = [font familyName];
        if ([self->_fontPopUpButton indexOfItemWithTitle:familyName] < 0)
            [self->_fontPopUpButton addItemWithTitle:familyName];
        [self->_fontPopUpButton selectItemWithTitle:familyName];

        break;
    }

    case WRVX_SELECTOR_KIND_DOCUMENT:
    case WRVX_SELECTOR_KIND_PARAGRAPH: {
        const WRTextViewSideOffsets *margins;
        if (selector.kind == WRVX_SELECTOR_KIND_DOCUMENT) {
            margins = &self->_documentMargins;
        } else {
            NSAssert(selector.selector < [self _paragraphStyleCount], @"Bad selector!");
            margins = &self->_paragraphMargins[selector.selector];
        }

        [self->_marginTopField setFloatValue:margins->top];
        [self->_marginRightField setFloatValue:margins->right];
        [self->_marginBottomField setFloatValue:margins->bottom];
        [self->_marginLeftField setFloatValue:margins->left];

        break;
    }
    }
}

- (void)_imageLoaded:(NSDictionary *)imageInfo {
    NSLog(@"imageLoaded: %@", imageInfo);
    [self->_textView setImage:[imageInfo objectForKey:@"Image"]
                        forID:[[imageInfo objectForKey:@"ImageID"] unsignedIntValue]];
}

@end
