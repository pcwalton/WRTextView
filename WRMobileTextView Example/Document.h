//
//  Document.h
//  WRMobileTextView Example
//
//  Created by Patrick Walton on 4/26/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#include <pilcrow.h>
#import "WRTextStorage.h"

@interface Document : UIDocument<WRTextStorage> {
    NSString *_textString;
    NSMutableArray<UIFont *> *_fonts;
    pilcrow_document_t *_document;
}

@property(nonatomic, strong) id<DocumentDelegate> delegate;

- (void)setFontFamily:(NSString *)fontFamily forInlineSelector:(pilcrow_inline_selector_t)selector;
- (void)setFontSize:(CGFloat)size forInlineSelector:(pilcrow_inline_selector_t)selector;
- (pilcrow_document_t *)takeDocument;

@end
