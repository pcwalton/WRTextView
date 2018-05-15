//
//  WRVXNavigationController.m
//  WRMobileTextView Example
//
//  Created by Patrick Walton on 5/9/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "WRVXNavigationController.h"
#import "WRVXDocumentViewController.h"
#import "NSObject+WRVCasting.h"

@implementation WRVXNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (WRVXDocumentViewController *)documentViewController {
    NSArray<UIViewController *> *viewControllers = [self viewControllers];
    NSInteger index = [viewControllers indexOfObjectPassingTest:
                       ^BOOL(UIViewController *obj, NSUInteger idx, BOOL *stop) {
                           return [obj isKindOfClass:[WRVXDocumentViewController class]];
                       }];
    if (index == NSNotFound)
        return nil;
    return [WRVXDocumentViewController wrv_staticCast:
            [viewControllers objectAtIndex:(NSUInteger)index]];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
