//
//  TSNumStopwatchesViewController.m
//
//  Created by Steve Pucci 14 Feb 2012
//  Copyright Emerald Sequoia LLC 2012. All rights reserved.
//

#import "TSNumStopwatchesViewController.h"
#import "TSModeOptionsViewController.h"
#import "TSRootViewController.h"

@implementation TSNumStopwatchesViewController

-(void)viewDidLoad {
    UINavigationItem *navItem = self.navigationItem;
    navItem.title = @"Stopwatches";
    [navItem setRightBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(popToTop)] autorelease]];
}

-(void)popToTop {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

// UITableViewDataSource methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)requestingTableView {
    assert(requestingTableView == self.tableView);
    return 1;
}

- (NSString *)tableView:(UITableView *)requestingTableView titleForFooterInSection:(NSInteger)section {
    assert(requestingTableView == self.tableView);
    assert(section == 0);
    return nil;
}

- (NSString *)tableView:(UITableView *)requestingTableView titleForHeaderInSection:(NSInteger)section {
    assert(requestingTableView == self.tableView);
    assert(section == 0);
    return @"Number of stopwatches";
}

- (NSInteger)tableView:(UITableView *)requestingTableView numberOfRowsInSection:(NSInteger)section {
    assert(requestingTableView == self.tableView);
    assert(section == 0);
    return [TSModeOptionsViewController maxNumStopwatchesForDevice];
}

- (UITableViewCell *)tableView:(UITableView *)requestingTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(requestingTableView == self.tableView);
    assert(indexPath.section == 0);
    NSString *reuseIdentifier = @"TSNumStopwatchesCell";
    UITableViewCell *tableViewCell = [requestingTableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (!tableViewCell) {
        tableViewCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier] autorelease];
    }
    assert(tableViewCell);
    tableViewCell.textLabel.text = [NSString stringWithFormat:@"%d", indexPath.row + 1];
    tableViewCell.selectionStyle = UITableViewCellSelectionStyleNone;
    tableViewCell.accessoryType = (numberOfStopwatches == indexPath.row + 1) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return tableViewCell;
}

- (void)tableView:(UITableView *)notifyingTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(notifyingTableView == self.tableView);
    assert(indexPath.section == 0);
    [TSModeOptionsViewController setNumberOfStopwatches:indexPath.row + 1];
    [notifyingTableView reloadData];
}

@end
