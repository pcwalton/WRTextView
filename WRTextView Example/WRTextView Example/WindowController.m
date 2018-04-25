//
//  WindowController.m
//  WRTextView Example
//
//  Created by Patrick Walton on 4/24/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "Document.h"
#import "WindowController.h"

@interface WindowController ()

@end

@implementation WindowController

- (void)windowDidLoad {
    [super windowDidLoad];

    Document *document = [self owner];
    
    NSCellStyleMask highlightMask = NSPushInCellMask | NSContentsCellMask;
    NSCellStyleMask showsStateMask = highlightMask | NSChangeBackgroundCellMask;

    NSButtonCell *debuggerToolbarButtonCell = [[document debuggerToolbarButton] cell];
    NSButtonCell *formatToolbarButtonCell = [[document formatToolbarButton] cell];
    [debuggerToolbarButtonCell setHighlightsBy:highlightMask];
    [formatToolbarButtonCell setHighlightsBy:highlightMask];
    [debuggerToolbarButtonCell setShowsStateBy:showsStateMask];
    [formatToolbarButtonCell setShowsStateBy:showsStateMask];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(_fontButtonWillPopUp:)
                                                name:NSPopUpButtonWillPopUpNotification
                                              object:[document fontPopUpButton]];
}

- (void)_fontButtonWillPopUp:(NSNotification *)notification {
    NSPopUpButton *fontPopUpButton = [notification object];
    NSString *selectedFontFamily = [fontPopUpButton titleOfSelectedItem];
    [fontPopUpButton removeAllItems];

    NSArray<NSString *> *fontFamilies = [[NSFontManager sharedFontManager] availableFontFamilies];
    NSUInteger fontFamilyCount = [fontFamilies count];
    for (NSUInteger fontFamilyIndex = 0; fontFamilyIndex < fontFamilyCount; fontFamilyIndex++) {
        NSString *fontFamily = [fontFamilies objectAtIndex:fontFamilyIndex];
        [fontPopUpButton addItemWithTitle:fontFamily];
        if ([fontFamily isEqualToString:selectedFontFamily])
            [fontPopUpButton selectItemAtIndex:(NSInteger)fontFamilyIndex];
    }
}

@end
