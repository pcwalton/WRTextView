//
//  WRTextScrollView.m
//  WRTextView
//
//  Created by Patrick Walton on 5/2/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import <TargetConditionals.h>

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
#import "WRTextScrollView.h"
#import "WRTextView.h"

@implementation WRTextScrollView

- (WRTextView *)_textView {
    NSArray<NSView *> *subviews = [self subviews];
    for (NSView *subview in subviews) {
        if ([subview isKindOfClass:[WRTextView class]])
            return (WRTextView *)subview;
    }
    return nil;
}

- (void)_zoomAtCenterBy:(CGFloat)factor {
    NSRect frame = [self frame];
    NSPoint center = NSMakePoint(NSMidX(frame), NSMidY(frame));
    CGFloat newMagnification = [self magnification] * factor;

    WRTextView *textView = [self _textView];
    [NSAnimationContext beginGrouping];
    [textView beginAnimation];
    [[self animator] setMagnification:newMagnification centeredAtPoint:center];

    if (textView != nil) {
        // FIXME(pcwalton): This is a nasty hack to work around the completion handler being called
        // too early…
        [[NSAnimationContext currentContext] setCompletionHandler:^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(),
                           ^{
                [textView endAnimation];
            });
        }];
    }

    [NSAnimationContext endGrouping];
}

- (IBAction)zoom:(id)sender {
    if (![sender isKindOfClass:[NSSegmentedControl class]])
        return;
    if ([(NSSegmentedControl *)sender selectedSegment] == 0)
        [self zoomOut:sender];
    else
        [self zoomIn:sender];
}

- (IBAction)zoomIn:(id)sender {
    [self _zoomAtCenterBy:1.3];
}

- (IBAction)zoomOut:(id)sender {
    [self _zoomAtCenterBy:1./1.3];
}

- (IBAction)zoomToActualSize:(id)sender {
    [self _zoomAtCenterBy:1. / [self magnification]];
}

@end
#endif
