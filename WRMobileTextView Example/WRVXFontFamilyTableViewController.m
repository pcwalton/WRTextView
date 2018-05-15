//
//  WRVXFontFamilyTableViewController.m
//  WRMobileTextView Example
//
//  Created by Patrick Walton on 5/9/18.
//  Copyright © 2018 Mozilla Foundation. All rights reserved.
//

#import "WRVXFontFamilyTableViewController.h"
#import "WRVXNavigationController.h"
#import "WRVXDocumentViewController.h"
#import "WRVXDocument.h"
#import "NSObject+WRVCasting.h"
#import <pilcrow.h>

@implementation WRVXFontFamilyTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    // Dispose of any resources that can be recreated.
    self->_familyNames = nil;
}

#pragma mark - Table view data source

- (NSArray<NSString *> *)_familyNames {
    if (self->_familyNames != nil)
        return self->_familyNames;
    self->_familyNames = [UIFont familyNames];
    self->_familyNames = [self->_familyNames sortedArrayUsingComparator:
                          ^NSComparisonResult(NSString *obj1, NSString *obj2) {
                              return [obj1 compare:obj2];
                          }];
    return self->_familyNames;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self _familyNames] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *familyName = [[self _familyNames] objectAtIndex:[indexPath row]];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FontFamily"];
    [[cell textLabel] setText:familyName];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    WRVXNavigationController *controller = [WRVXNavigationController
                                            wrv_staticCast:[self parentViewController]];
    WRVXDocumentViewController *documentViewController = [controller documentViewController];
    NSString *familyName = [[self _familyNames] objectAtIndex:[indexPath row]];
    WRVXDocument *document = [documentViewController document];
    [document setFontFamily:familyName forInlineSelector:self->_inlineSelector];
    
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    UIView *senderView = [UIView wrv_staticCast:sender];
    self->_inlineSelector = (pilcrow_inline_selector_t)[senderView tag];

}

@end
