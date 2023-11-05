//
//  TSEmailOptionsViewController.m
//
//  Created by Steve Pucci 06 Feb 2012
//  Copyright Emerald Sequoia LLC 2012. All rights reserved.
//

#import "TSEmailOptionsViewController.h"
#import "TSTopOptionsViewController.h"

#define ROW_PLAIN_TEXT 0
#define ROW_TSV        1
#define ROW_CSV        2

@implementation TSEmailOptionsViewController;

-(id)initWithTopOptionsController:(TSTopOptionsViewController *)controller {
    [super initWithStyle:UITableViewStyleGrouped];
    topOptionsController = [controller retain];
    return self;
}

-(void)dealloc {
    [topOptionsController release];
    [super dealloc];
}

-(void)popToTop {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

-(void)viewDidLoad {
    UINavigationItem *navItem = self.navigationItem;
    navItem.title = @"Email Format";
    [navItem setRightBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(popToTop)] autorelease]];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

// UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    assert(section == 0);
    return @"To display fractional seconds in Excel, use a custom date format like \"yyyy/mm/dd hh:mm:ss.0\", or \"[h]:mm:ss.0\" for intervals";
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    assert(section == 0);
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    assert(section == 0);
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(indexPath.section == 0);
    NSString *reuseIdentifier = @"TSEmailOptionCell";
    UITableViewCell *tableViewCell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (!tableViewCell) {
        tableViewCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier] autorelease];
        tableViewCell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    assert(tableViewCell);
    NSString *emailFormat = [[NSUserDefaults standardUserDefaults] stringForKey:@"TSEmailFormat"];
    bool useTSV = emailFormat && ([emailFormat compare:@"tsv"] == NSOrderedSame);
    bool useCSV = emailFormat && ([emailFormat compare:@"csv"] == NSOrderedSame);
    int rowWithCheck = useTSV ? ROW_TSV : useCSV ? ROW_CSV : ROW_PLAIN_TEXT;
    tableViewCell.accessoryType = indexPath.row == rowWithCheck ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    tableViewCell.textLabel.text = indexPath.row == ROW_TSV ? @"Tab separated value" : indexPath.row == ROW_CSV ? @"Comma separated value" : @"Plain text";
    return tableViewCell;
}

// UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(indexPath.section == 0);
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *newValue;
    if (indexPath.row == ROW_TSV) {
        newValue = @"tsv";
    } else if (indexPath.row == ROW_CSV) {
        newValue = @"csv";
    } else {
        assert(indexPath.row == ROW_PLAIN_TEXT);
        newValue = @"plain";
    }        
    [userDefaults setObject:newValue forKey:@"TSEmailFormat"];
    [tableView reloadData];
    [topOptionsController reloadTableData];
}

@end
