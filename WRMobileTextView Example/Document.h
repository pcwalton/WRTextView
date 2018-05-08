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

@interface Document : UIDocument {
    NSString *_textString;
    NSMutableArray<UIFont *> *_fonts;
    pilcrow_document_t *_document;
}

- (pilcrow_document_t *)takeDocument;

@end
