//
//  WRVXWindowController.m
//  WRTextView Example
//
//  Created by Patrick Walton on 4/24/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "WRVXDocument.h"
#import "WRVXWindowController.h"

#define MIN_FORMAT_PANE_SIZE    180.0

@interface WRVXWindowController ()

@end

@implementation WRVXWindowController

- (void)windowDidLoad {
    [super windowDidLoad];

    WRVXDocument *document = [self owner];

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
    
    NSSplitView *splitView = [document splitView];
    [splitView setDelegate:self];
    [splitView setPosition:[splitView frame].size.width ofDividerAtIndex:0];

    [document selectNewStyle:self];
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

- (CGFloat)splitView:(NSSplitView *)splitView
    constrainMinCoordinate:(CGFloat)proposedMinimumPosition
         ofSubviewAt:(NSInteger)dividerIndex {
    return 0.0;
}

- (CGFloat)splitView:(NSSplitView *)splitView
constrainMaxCoordinate:(CGFloat)proposedMaximumPosition
         ofSubviewAt:(NSInteger)dividerIndex {
    return [splitView frame].size.width - MIN_FORMAT_PANE_SIZE;
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
    return [[splitView subviews] lastObject] == subview;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldHideDividerAtIndex:(NSInteger)dividerIndex {
    return YES;
}

@end
