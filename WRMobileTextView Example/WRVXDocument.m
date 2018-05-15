//
//  WRVXDocument.m
//  WRMobileTextView Example
//
//  Created by Patrick Walton on 4/26/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "WRVXDocument.h"

@implementation WRVXDocument

- (void)_populateDefaultStyles {
    self->_fonts = [NSMutableArray arrayWithObjects:
                    [UIFont fontWithName:@"Times" size:18.0],
                    [UIFont fontWithName:@"Menlo" size:16.0],
                    [UIFont systemFontOfSize:36.0 weight:UIFontWeightBold],
                    [UIFont systemFontOfSize:24.0 weight:UIFontWeightBold],
                    nil];
}

- (pilcrow_markdown_parser_t *)_createMarkdownParser {
    pilcrow_markdown_parser_t *markdownParser = pilcrow_markdown_parser_new();
    
    uint32_t fontCount = (uint32_t)[self->_fonts count];
    for (uint32_t index = 0; index < fontCount; index++) {
        UIFont *font = [self->_fonts objectAtIndex:index];
        pilcrow_font_t *pFont = pilcrow_font_new_from_native((__bridge CTFontRef)font);
        pilcrow_markdown_parser_set_font(markdownParser, (pilcrow_inline_selector_t)index, pFont);
    }

    return markdownParser;
}

- (BOOL)_recreateTextBufferWithMarkdownParser:(pilcrow_markdown_parser_t *)markdownParser {
    const char *bytes = [self->_textString UTF8String];
    if (bytes == NULL)
        return NO;
    
    self->_document = pilcrow_document_new();
    
    pilcrow_document_style_t *documentStyle = pilcrow_document_get_style(self->_document);
    
    pilcrow_markdown_parse_results_t *parseResults =
    pilcrow_markdown_parser_add_to_document(markdownParser,
                                            (const uint8_t *)bytes,
                                            strlen(bytes),
                                            self->_document);
    
    uintptr_t imageCount = pilcrow_markdown_parse_results_get_image_count(parseResults);
    NSURLSession *urlSession = [NSURLSession sharedSession];
    return YES;
}

- (void)_recreateTextBufferAndReloadText {
    pilcrow_markdown_parser_t *markdownParser = [self _createMarkdownParser];
    [self _recreateTextBufferWithMarkdownParser:markdownParser];
    [[self delegate] reloadDocumentText:self];
}

- (id)contentsForType:(NSString*)typeName error:(NSError **)errorPtr {
    // Encode your document with an instance of NSData or NSFileWrapper
    return [[NSData alloc] init];
}
    
- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError **)errorPtr {
    self->_textString = [[NSString alloc] initWithData:(NSData *)contents
                                              encoding:NSUTF8StringEncoding];
    [self _populateDefaultStyles];
    pilcrow_markdown_parser_t *markdownParser = [self _createMarkdownParser];
    return [self _recreateTextBufferWithMarkdownParser:markdownParser];
}

- (pilcrow_document_t *)takeDocument {
    pilcrow_document_t *document = self->_document;
    self->_document = nil;
    return document;
}

- (void)setFontFamily:(NSString *)fontFamily
    forInlineSelector:(pilcrow_inline_selector_t)selector {
    NSAssert(selector < [self->_fonts count], @"Inline selector out of range!");
    UIFont *font = [self->_fonts objectAtIndex:(NSUInteger)selector];
    font = [UIFont fontWithName:fontFamily size:[font pointSize]];
    NSAssert(font != nil, @"No font with name \"%@\"!", fontFamily);
    [self->_fonts setObject:font atIndexedSubscript:(NSUInteger)selector];
}

- (void)setFontSize:(CGFloat)size forInlineSelector:(pilcrow_inline_selector_t)selector {
    NSAssert(selector < [self->_fonts count], @"Inline selector out of range!");
    UIFont *font = [[self->_fonts objectAtIndex:(NSUInteger)selector] fontWithSize:size];
    [self->_fonts setObject:font atIndexedSubscript:(NSUInteger)selector];
}

@end
