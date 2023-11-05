//
//  TSCustomNameEditorViewController.m
//
//  Created by Steve Pucci 11 Feb 2012
//  Copyright Emerald Sequoia LLC 2012. All rights reserved.
//

#import "TSCustomNameEditorViewController.h"
#import "TSCustomNameTextfieldController.h"
#import "TSTopOptionsViewController.h"
#import "TSRootViewController.h"

@implementation TSCustomNameEditorViewController

@synthesize addButtonItem, editButtonItem, bottomToolbar, tableView, hintLabel;

// UITableViewDataSource methods

#define DEFAULT_PROJECT_NAME @"Project 1"

static TSCustomNameEditorViewController *theController = nil;
static bool isEditing = false;
static NSInteger rowNumberBeingEdited = -1;

static bool multipleSelectionCapable = false;  // globally set in viewDidLoad based on OS API

static NSMutableArray *customNamesByMode[TSNumMasterModes] = { nil, nil, nil };

static NSString *defaultsKeysByMode[TSNumMasterModes] = {
    @"TSClassicCustomNames",
    nil,
    @"TSProjectCustomNames"
};

static void loadDefaultsIntoArray(TSMasterModeType masterMode,
                                  NSUserDefaults   *userDefaults) {
    NSMutableArray **arr = &customNamesByMode[masterMode];
    NSString *defaultsKey = defaultsKeysByMode[masterMode];
    if (*arr) {
        [*arr release];
    }
    NSArray *defaultsValue = [userDefaults arrayForKey:defaultsKey];
    if (defaultsValue) {
        *arr = [[NSMutableArray arrayWithArray:defaultsValue] retain];
    } else {
        *arr = nil;
    }
}

+ (void)loadDefaults {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    loadDefaultsIntoArray(TSMasterModeClassic, userDefaults);
    loadDefaultsIntoArray(TSMasterModeProject, userDefaults);
    if (!customNamesByMode[TSMasterModeProject]) {
        customNamesByMode[TSMasterModeProject] = [[NSMutableArray arrayWithObject:DEFAULT_PROJECT_NAME] retain];
    }
}

static void saveDefaultsForMode(TSMasterModeType masterMode,
                                NSUserDefaults   *userDefaults,
                                bool             makeNewButtonsToo) {
    assert(masterMode >= 0 && masterMode < TSNumMasterModes);
    [userDefaults setObject:customNamesByMode[masterMode] forKey:defaultsKeysByMode[masterMode]];
    if (makeNewButtonsToo) {
        [TSRootViewController makeNewButtonsAndSetColors];
    }
}

+ (NSArray *)customNamesForMode:(TSMasterModeType)masterMode {
    assert(masterMode >= 0 && masterMode < TSNumMasterModes);
    return customNamesByMode[masterMode];
}

// UITableViewDataSource methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    assert(section == 0);
//    TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
//    if (masterMode == TSMasterModeProject) {
//        return @"There is always at least one project";
//    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    assert(section == 0);
    return @"Custom Names";
    //return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    assert(section == 0);
    TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
    assert(masterMode >= 0 && masterMode < TSNumMasterModes);
    NSArray *arr = customNamesByMode[masterMode];
    assert(masterMode != TSMasterModeProject || arr);
    if (arr) {
        return [arr count] + 1;
    } else {
        return 1;
    }
}

- (UITableViewCell *)tableView:(UITableView *)requestingTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(indexPath.section == 0);
    TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
    assert(masterMode >= 0 && masterMode < TSNumMasterModes);
    NSArray *arr = customNamesByMode[masterMode];
    NSString *reuseIdentifier = @"TSCustomNameEditorCell";
    UITableViewCell *tableViewCell = [requestingTableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (!tableViewCell) {
        tableViewCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier] autorelease];
        tableViewCell.showsReorderControl = YES;
        tableViewCell.tintColor = [UIColor redColor];
    }

    assert(tableViewCell);
    if (indexPath.row < [arr count]) {
        tableViewCell.textLabel.text = [arr objectAtIndex:indexPath.row];
        tableViewCell.selectionStyle = multipleSelectionCapable && tableView.editing ? UITableViewCellSelectionStyleBlue : UITableViewCellSelectionStyleNone;
    } else {
        tableViewCell.textLabel.text = @"";
        tableViewCell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return tableViewCell;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(indexPath.section == 0);
    TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
    assert(masterMode >= 0 && masterMode < TSNumMasterModes);
    NSArray *arr = customNamesByMode[masterMode];
    return indexPath.row < [arr count];
}

- (void)tableView:(UITableView *)aTableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    assert(aTableView == tableView);
    assert(fromIndexPath.section == 0);
    assert(toIndexPath.section == 0);
    NSInteger fromRow = fromIndexPath.row;
    NSInteger toRow = toIndexPath.row;
    TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
    assert(masterMode >= 0 && masterMode < TSNumMasterModes);
    NSMutableArray *arr = customNamesByMode[masterMode];
    assert(arr);  // Otherwise row count should have been zero
    assert(fromRow < [arr count]);  // Otherwise we should't have been allowed to move the row
    if (toRow >= [arr count]) {
        toRow = [arr count] - 1;
        [aTableView reloadData];
    }
    assert(toRow < [arr count]);
    NSString *movingName = [[[arr objectAtIndex:fromRow] retain] autorelease];
    [arr removeObjectAtIndex:fromRow];
    [arr insertObject:movingName atIndex:toRow];
    saveDefaultsForMode(masterMode, [NSUserDefaults standardUserDefaults], true/*makeNewButtonsToo*/);
}

 - (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillTransitionToSize:(CGSize)size 
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    printf("viewWillTransitionToSize %g %g\n", size.width, size.height);
    // Figure out effective orientation here.
}

// - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
//  // Return YES for supported orientations.
//      return YES;
//  }

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(indexPath.section == 0);
    TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
    assert(masterMode >= 0 && masterMode < TSNumMasterModes);
    NSArray *arr = customNamesByMode[masterMode];
    return indexPath.row < [arr count];
}

- (void)tableView:(UITableView *)requestingTableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(tableView == requestingTableView);
    assert(editingStyle == UITableViewCellEditingStyleDelete);
    TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
    assert(masterMode >= 0 && masterMode < TSNumMasterModes);
    NSMutableArray *arr = customNamesByMode[masterMode];
    assert(arr);  // Otherwise row count should have been zero
    assert(indexPath.row < [arr count]);  // Otherwise we shouldn't have been allowed to edit it
    [arr removeObjectAtIndex:indexPath.row];
    if ([arr count] == 0) {
        if (masterMode == TSMasterModeProject) {
            [arr addObject:DEFAULT_PROJECT_NAME];
        } else {
            [arr release];
            customNamesByMode[masterMode] = nil;
        }
    }
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationTop];
    saveDefaultsForMode(masterMode, [NSUserDefaults standardUserDefaults], true/*makeNewButtonsToo*/);
}

-(void)popToTop {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)viewDidLoad {
    theController = self;
    tableView.delegate = self;
    tableView.dataSource = self;
    NSString *titleTxt;
    NSString *hintTxt = nil;
    switch ([TSTopOptionsViewController masterMode]) {
      case TSMasterModeClassic:
        titleTxt = @"Custom Names";
        hintTxt = @"Use the + button below left to add custom names; tap on a name to edit it.  The number of usable custom names depends on the display width.";
        break;
      case TSMasterModeStopwatch:
        titleTxt = @"Stopwatch Names";
        assert(false);  // We don't have stopwatch names
        break;
      case TSMasterModeProject:
        titleTxt = @"Project Names";
        hintTxt = @"The number of usable custom projects depends on the display width; there is always at least one project";
        break;
      default:
        assert(false);
        titleTxt = nil;
        hintTxt = nil;
        break;
    }
    UINavigationItem *navItem = self.navigationItem;
    navItem.title = titleTxt;
    navItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Names" style:UIBarButtonItemStylePlain target:nil action:nil] autorelease];
    [navItem setRightBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(popToTop)] autorelease]];
    if ([UITableView instancesRespondToSelector:@selector(allowsMultipleSelectionDuringEditing)]) {
        multipleSelectionCapable = true;
    }
    hintLabel.text = hintTxt;
}

- (void)dealloc {
    theController = nil;
    [super dealloc];
}

// UITableViewDelegate methods

static UIButton *theDeleteButton;

static void
setDeleteButtonText(UITableView *tableView) {
    assert(theDeleteButton);
    NSArray *indexPathsFlaggedForDelete = [tableView indexPathsForSelectedRows];
    NSInteger deleteCount = indexPathsFlaggedForDelete ? [indexPathsFlaggedForDelete count] : 0;
    NSString *deleteButtonText = deleteCount == 0
        ? NSLocalizedString(@"Delete all", @"Title for delete button when all items will be deleted")
        : [NSString stringWithFormat:NSLocalizedString(@"Delete (%ld)", @"Title for delete button when only selected items will be deleted"), (long)deleteCount];
    [theDeleteButton setTitle:deleteButtonText forState:UIControlStateNormal];
    [theDeleteButton sizeToFit];
    theDeleteButton.bounds = CGRectMake(theDeleteButton.bounds.origin.x, theDeleteButton.bounds.origin.x,
                                        theDeleteButton.bounds.size.width, 34);
}

- (NSIndexPath *)tableView:(UITableView *)notifyingTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(notifyingTableView == tableView);
    assert(indexPath.section == 0);
    if (isEditing) {  // Must be multiple-selection capable
        TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
        assert(masterMode >= 0 && masterMode < TSNumMasterModes); 
        NSArray *arr = customNamesByMode[masterMode];
        if (indexPath.row >= [arr count]) {
            return nil;
        }
    }
    return indexPath;
}

- (void)tableView:(UITableView *)notifyingTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(notifyingTableView == tableView);
    if (isEditing) {  // Must be multiple-selection capable
        assert(multipleSelectionCapable);
        setDeleteButtonText(notifyingTableView);
        return;
    }
    assert(indexPath.section == 0);
    //NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
    assert(masterMode >= 0 && masterMode < TSNumMasterModes); 
    NSArray *arr = customNamesByMode[masterMode];
    if (indexPath.row < [arr count]) {
        assert(arr);
        rowNumberBeingEdited = indexPath.row;
    } else {
        if (arr) {
            rowNumberBeingEdited = [arr count];
        } else {
            rowNumberBeingEdited = 0;
        }
    }
    TSCustomNameTextfieldController *vc = [[TSCustomNameTextfieldController alloc] initWithCustomNameEditorController:self];
    [self.navigationController pushViewController:vc animated:true];
}

- (void)tableView:(UITableView *)notifyingTableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(notifyingTableView == tableView);
    if (isEditing) {  // Must be multiple-selection capable
        assert(multipleSelectionCapable);
        setDeleteButtonText(notifyingTableView);
        return;
    }
}

// View actions

- (IBAction)addNameAction:(id)sender {
    TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
    assert(masterMode >= 0 && masterMode < TSNumMasterModes);
    NSArray *arr = customNamesByMode[masterMode];
    if (arr) {
        rowNumberBeingEdited = [arr count];
    } else {
        rowNumberBeingEdited = 0;
    }
    TSCustomNameTextfieldController *vc = [[TSCustomNameTextfieldController alloc] initWithCustomNameEditorController:self];
    [self.navigationController pushViewController:vc animated:true];
}

- (IBAction)editAction:(id)sender {
    if (theController) {
        isEditing = !isEditing;
        if (multipleSelectionCapable) {
            tableView.allowsMultipleSelectionDuringEditing = isEditing;  // hack to allow swipe-to-delete even in iOS 5+
        }
        [tableView setEditing:isEditing animated:YES];
        NSArray *oldItems = [bottomToolbar items];
        assert(oldItems);
        assert([oldItems count] == 3);
        UIBarButtonItem *leftItem =  [oldItems objectAtIndex:0];
        UIBarButtonItem *spacer   =  [oldItems objectAtIndex:1];
        UIBarButtonItem *rightItem = [oldItems objectAtIndex:2];
        if (isEditing) {
            if (multipleSelectionCapable) {
                UIButton *deleteButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
                theDeleteButton = [deleteButton retain];
                theDeleteButton.titleLabel.font = [UIFont systemFontOfSize:18];
                setDeleteButtonText(tableView);  // also sets up gradient
                [theDeleteButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
                [deleteButton addTarget:self action:@selector(deleteDownAction:)      forControlEvents:UIControlEventTouchDown];
                [deleteButton addTarget:self action:@selector(deleteAction:)          forControlEvents:UIControlEventTouchUpInside];
                [deleteButton addTarget:self action:@selector(deleteCancelAction:)    forControlEvents:UIControlEventTouchUpOutside];
                [deleteButton addTarget:self action:@selector(deleteCancelAction:)    forControlEvents:UIControlEventTouchCancel];
                [deleteButton addTarget:self action:@selector(deleteDragExitAction:)  forControlEvents:UIControlEventTouchDragExit];
                [deleteButton addTarget:self action:@selector(deleteDragEnterAction:) forControlEvents:UIControlEventTouchDragEnter];
                leftItem = [[[UIBarButtonItem alloc] initWithCustomView:deleteButton] autorelease];
                rightItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(editAction:)]    autorelease];
            } else {
                leftItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil] autorelease];
                rightItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(editAction:)]    autorelease];
            }
        } else {
            leftItem  = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd  target:self action:@selector(addNameAction:)] autorelease];
            leftItem.style = UIBarButtonItemStylePlain;
            rightItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editAction:)]    autorelease];
        }
        [bottomToolbar setItems:[NSArray arrayWithObjects:leftItem, spacer, rightItem, nil]
                       animated:YES];
        if (multipleSelectionCapable) {
            [NSTimer scheduledTimerWithTimeInterval:0.35 target:tableView selector:@selector(reloadData) userInfo:nil repeats:NO];
        }
    }
}

- (void)deleteDownAction:(id)sender {
    assert(multipleSelectionCapable);
    //printf("Down! Down! Down! sender is 0x%08x\n", (unsigned int)sender);
}

- (void)deleteCancelAction:(id)sender {
    assert(multipleSelectionCapable);
    //printf("Cancel! Cancel! Cancel! sender is 0x%08x\n", (unsigned int)sender);
}

- (void)reallyClear {
    TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
    assert(masterMode >= 0 && masterMode < TSNumMasterModes);
    NSMutableArray **arr = &customNamesByMode[masterMode];
    assert(masterMode != TSMasterModeProject || *arr);
    if (*arr) {
        NSInteger count = [*arr count];
        if (count > 0) {
            if (masterMode == TSMasterModeProject) {
                [*arr removeAllObjects];
                [*arr addObject:DEFAULT_PROJECT_NAME];
            } else {
                [*arr release];
                *arr = nil;
            }
            saveDefaultsForMode(masterMode, [NSUserDefaults standardUserDefaults], true/*makeNewButtonsToo*/);
            [tableView beginUpdates];
            NSMutableArray *indexPathArray = [NSMutableArray arrayWithCapacity:count];
            for (int i = 0; i < count; i++) {
                [indexPathArray addObject:[NSIndexPath indexPathForRow:i inSection:0]];
            }
            [tableView deleteRowsAtIndexPaths:indexPathArray withRowAnimation:UITableViewRowAnimationTop];
            [tableView endUpdates];
        }
    }
    [self editAction:nil];
    [NSTimer scheduledTimerWithTimeInterval:0.3 target:tableView selector:@selector(reloadData) userInfo:nil repeats:NO];
}

static NSInteger
downSort(NSIndexPath *path1,
         NSIndexPath *path2,
         void        *context) {
    NSInteger row1 = path1.row;
    NSInteger row2 = path2.row;
    if (row1 < row2) {
        return NSOrderedDescending;
    } else if (row1 == row2) {
        return NSOrderedSame;
    } else {
        return NSOrderedAscending;
    }
}

- (void)clearAction:(id)sender {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Clear", "Clear button title")
                                                                   message:NSLocalizedString(@"Remove all custom names?", "")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {}]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
                [self reallyClear];                
            }]];
    [self presentViewController:alert animated:YES completion:nil];
 }

- (void)deleteAction:(id)sender {
    assert(multipleSelectionCapable);
    //printf("Delete! Delete! Delete! sender is 0x%08x\n", (unsigned int)sender);
    
    NSArray *indexPathsFlaggedForDelete = [[tableView indexPathsForSelectedRows] sortedArrayUsingFunction:downSort context:NULL];
    NSInteger deleteCount = indexPathsFlaggedForDelete ? [indexPathsFlaggedForDelete count] : 0;
    if (deleteCount == 0) {  // Means delete everybody
        [self clearAction:sender];
        return;
    } else {
        TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
        assert(masterMode >= 0 && masterMode < TSNumMasterModes);
        NSMutableArray **arr = &customNamesByMode[masterMode];
        for (NSIndexPath *indexPath in indexPathsFlaggedForDelete) {
            assert(indexPath.section == 0);
            NSInteger rowNumber = indexPath.row;
            if (*arr && rowNumber < [*arr count]) {
                [*arr removeObjectAtIndex:rowNumber];
            } else {
                assert(false);
            }
        }
        [tableView beginUpdates];
        [tableView deleteRowsAtIndexPaths:indexPathsFlaggedForDelete
                         withRowAnimation:UITableViewRowAnimationTop];
        [tableView endUpdates];
        if (*arr && [*arr count] == 0) {
            if (masterMode == TSMasterModeProject) {
                [*arr addObject:DEFAULT_PROJECT_NAME];
            } else {
                [*arr release];
                *arr = nil;
            }
        }
        saveDefaultsForMode(masterMode, [NSUserDefaults standardUserDefaults], true/*makeNewButtonsToo*/);
    }
    assert(isEditing);
    assert(theController);
    [self editAction:nil];
    [NSTimer scheduledTimerWithTimeInterval:0.3 target:tableView selector:@selector(reloadData) userInfo:nil repeats:NO];
}

- (void)deleteDragExitAction:(id)sender {
    assert(multipleSelectionCapable);
    //printf("Drag exit! Drag exit! Drag exit! sender is 0x%08x\n", (unsigned int)sender);
}

- (void)deleteDragEnterAction:(id)sender {
    assert(multipleSelectionCapable);
    //printf("Drag enter! Drag enter! Drag enter! sender is 0x%08x\n", (unsigned int)sender);
}

// Messages from text field

- (NSInteger)rowNumberBeingEdited {
    return rowNumberBeingEdited;
}

// This only works before the first character is typed
- (bool)addingNotEditing {
    TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
    assert(masterMode >= 0 && masterMode < TSNumMasterModes);
    NSMutableArray **arr = &customNamesByMode[masterMode];
    assert(rowNumberBeingEdited >= 0);
    return rowNumberBeingEdited >= [*arr count];
}

- (NSString *)currentTextForRow:(NSInteger)rowNumber {
    TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
    assert(masterMode >= 0 && masterMode < TSNumMasterModes);
    NSMutableArray **arr = &customNamesByMode[masterMode];
    assert(rowNumberBeingEdited >= 0);
    assert(rowNumber == rowNumberBeingEdited);
    if (*arr && rowNumber < [*arr count]) {
        return [*arr objectAtIndex:rowNumber];
    } else {
        return @"";
    }
}

static NSString *stripWhitespaceFrom(NSString *newValue) {
    while ([newValue length] >= 1 && [newValue characterAtIndex:0] == ' ') {
        newValue = [newValue substringFromIndex:1];
    }
    return newValue;
}

- (void)textFieldChangedTo:(NSString *)newValue {
    newValue = stripWhitespaceFrom(newValue);
    if ([newValue length] == 0) {
        return;
    }
    TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
    assert(masterMode >= 0 && masterMode < TSNumMasterModes);
    NSMutableArray **arr = &customNamesByMode[masterMode];
    assert(rowNumberBeingEdited >= 0);
    if (*arr) {
        if (rowNumberBeingEdited >= [*arr count]) {
            [*arr addObject:newValue];
        } else {
            [*arr replaceObjectAtIndex:rowNumberBeingEdited withObject:newValue];
        }
    } else {
        *arr = [[NSMutableArray arrayWithObject:newValue] retain];
    }
    saveDefaultsForMode(masterMode, [NSUserDefaults standardUserDefaults], false/* !makeNewButtonsToo*/);
    [tableView reloadData];
}

@end
