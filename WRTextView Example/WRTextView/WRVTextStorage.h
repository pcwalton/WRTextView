//
//  WRVTextStorage.h
//  WRTextView Example
//
//  Created by Patrick Walton on 5/7/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#ifndef WRV_TEXT_STORAGE_H
#define WRV_TEXT_STORAGE_H

#include <pilcrow.h>

@protocol WRVTextStorage

- (pilcrow_document_t *)takeDocument;

@end

#endif /* WRV_TEXT_STORAGE_H */
