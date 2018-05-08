//
//  WRTextStorage.h
//  WRTextView Example
//
//  Created by Patrick Walton on 5/7/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#ifndef WRTextStorage_h
#define WRTextStorage_h

#include <pilcrow.h>

@protocol WRTextStorage

- (pilcrow_document_t *)takeDocument;

@end

#endif /* WRTextStorage_h */
