//
//  Document.h
//  WRTextView Example
//
//  Created by Patrick Walton on 4/11/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <pilcrow.h>

@interface Document : NSDocument {}

@property(nonatomic) pilcrow_text_buf_t *textBuffer;

@end

