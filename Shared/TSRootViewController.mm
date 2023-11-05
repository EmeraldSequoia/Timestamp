//
//  TSRootViewController.mm
//
//  Created by Steve Pucci on 4/30/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "TSRootViewController.h"
#import "TSEventViewController.h"
#import "TSHelpViewController.h"
#import "TSSharedAppDelegate.h"
#import "TSTimeHistory.h"
#import "TSAudio.h"
#import "ESRowView.h"
#import "TSTopOptionsViewController.h"
#import "TSCustomNameEditorViewController.h"

#include "ESUtil.hpp"
#include "ESTime.hpp"

#define ACCURACY_IMAGE_TAG 0
#define ZERO_BUTTON_TAG 1
#define TEXT_LABEL_TAG 2
#define DETAIL_TEXT_LABEL_TAG 3
#define EDIT_BUTTON_TAG 4
#define TEXT_LABEL2_TAG 5
#define DETAIL_TEXT_LABEL2_TAG 6

@implementation TSRootViewController

@synthesize theTableView, stampButtonRow, intervalTimeLabelRow, currentDateLabel, currentAbsoluteTimeLabel, currentErrorLabel, logoView;
@synthesize loadedTVCellWithTwoRowsWithZero, loadedTVCellWithOneRowWithZero, loadedTVCellWithTwoRowsNoZero, loadedTVCellWithOneRowNoZero;
@synthesize bottomToolbar;

static UIColor *gettingSyncColor = NULL;

extern "C" {
bool isIpad() {
    static bool initialized = false;
    static bool isIpad = false;
    if (!initialized) {
	if ([UIDevice instancesRespondToSelector:@selector(userInterfaceIdiom)]) {
	    isIpad = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
	    //printf("sez it's %s\n", isIpad ? "ipad" : "not ipad");
	} else {
	    isIpad = false;
	}
    }
    return isIpad;
}
}

-(BOOL)prefersHomeIndicatorAutoHidden{
    return true;
}

- (void)setGettingSyncColor {
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        printf("Changed to dark\n");
        gettingSyncColor = [UIColor yellowColor];
    } else {
        printf("Changed to light\n");
        gettingSyncColor = [UIColor yellowColor];  // [UIColor lightGrayColor];
    }
}

// Detect dark-mode entry or exit
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange: previousTraitCollection];
    if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
        [self setGettingSyncColor];
        [self syncStatusChangedInMainThread];
    }
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (NSArray *)keyCommands
{
    return @[ 
        [UIKeyCommand keyCommandWithInput:@"\r"                modifierFlags:0 action:@selector(fakePressButton1)],
        [UIKeyCommand keyCommandWithInput:@" "                 modifierFlags:0 action:@selector(fakePressButton1)],

        // These are used for AirTurn-like pseudo-keyboards:
        [UIKeyCommand keyCommandWithInput:UIKeyInputUpArrow    modifierFlags:0 action:@selector(fakePressButton1)],
        [UIKeyCommand keyCommandWithInput:UIKeyInputDownArrow  modifierFlags:0 action:@selector(fakePressButton2)],
        [UIKeyCommand keyCommandWithInput:UIKeyInputLeftArrow  modifierFlags:0 action:@selector(fakePressButton3)],
        [UIKeyCommand keyCommandWithInput:UIKeyInputRightArrow modifierFlags:0 action:@selector(fakePressButton4)],

        [UIKeyCommand keyCommandWithInput:@"1"                 modifierFlags:0 action:@selector(fakePressButton1)],
        [UIKeyCommand keyCommandWithInput:@"2"                 modifierFlags:0 action:@selector(fakePressButton2)],
        [UIKeyCommand keyCommandWithInput:@"3"                 modifierFlags:0 action:@selector(fakePressButton3)],
        [UIKeyCommand keyCommandWithInput:@"4"                 modifierFlags:0 action:@selector(fakePressButton4)],
        [UIKeyCommand keyCommandWithInput:@"5"                 modifierFlags:0 action:@selector(fakePressButton5)],
        [UIKeyCommand keyCommandWithInput:@"6"                 modifierFlags:0 action:@selector(fakePressButton6)],
        [UIKeyCommand keyCommandWithInput:@"7"                 modifierFlags:0 action:@selector(fakePressButton7)],
        [UIKeyCommand keyCommandWithInput:@"8"                 modifierFlags:0 action:@selector(fakePressButton8)],
        [UIKeyCommand keyCommandWithInput:@"9"                 modifierFlags:0 action:@selector(fakePressButton9)],
        [UIKeyCommand keyCommandWithInput:@"0"                 modifierFlags:0 action:@selector(fakePressButton10)],
              ];
}

- (void)fakePressButtonNumber:(int)buttonNumberStartingAt1
{
    NSArray *buttons = stampButtonRow.subviews;
    if (buttonNumberStartingAt1 <= [buttons count]) {
        UIButton *button = [buttons objectAtIndex:(buttonNumberStartingAt1 - 1)];
        [self stampDownAction:button];
        [self stampUpAction:button];
    }
}

- (void)fakePressButton1
{
    [self fakePressButtonNumber:1];
}

- (void)fakePressButton2
{
    [self fakePressButtonNumber:2];
}

- (void)fakePressButton3
{
    [self fakePressButtonNumber:3];
}

- (void)fakePressButton4
{
    [self fakePressButtonNumber:4];
}

- (void)fakePressButton5
{
    [self fakePressButtonNumber:5];
}

- (void)fakePressButton6
{
    [self fakePressButtonNumber:6];
}

- (void)fakePressButton7
{
    [self fakePressButtonNumber:7];
}

- (void)fakePressButton8
{
    [self fakePressButtonNumber:8];
}

- (void)fakePressButton9
{
    [self fakePressButtonNumber:9];
}

- (void)fakePressButton10
{
    [self fakePressButtonNumber:10];
}

static TSDisplayOrder  displayOrder = TSOrderAuto;

// First-run quick-start alert part 1 of 2 start
static NSString *firstVersionRun = nil;
static NSString *thisVersion = nil;
static bool isNewbie = false;
static int shouldShowQuickStart = false;

-(void)showQuickStart {
    if (!shouldShowQuickStart) {
	return;
    }
    shouldShowQuickStart = false;  // Only once per sesssion
    assert(thisVersion != nil);
    NSString *versionSummaryString;
    NSString *quickStartButtonText;
    versionSummaryString = NSLocalizedString(@"This app will be removed from the store on Nov 1 2023.\n\nPlease read the Details via the button below.", @"Version 2.3.5 first-run alert summary");
    // USE scripts/resetSimulatorLastVersionRun.pl <prior-version> <prior-version> IN SIMULATOR (WHILE APP NOT RUNNING) TO FORCE THIS MESSAGE THE NEXT TIME THE SIMULATOR RUNS
    quickStartButtonText = NSLocalizedString(@"Details", @"Details about Emerald Sequoia shutdown");

    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"WARNING", @"WARNING")
                                message:[NSString stringWithFormat:versionSummaryString, thisVersion]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
    // Show help
    [alert addAction:[UIAlertAction actionWithTitle:quickStartButtonText
                      style:UIAlertActionStyleDefault
                      handler:^(UIAlertAction *action) {
                // Invoke external browser on details
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://emeraldsequoia.com/ts/shutdown.html"] options:@{} completionHandler:NULL];
            }]];

    // Later
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Later", @"First-run alert button to skip release notes for now")
                      style:UIAlertActionStyleDefault
                      handler:^(UIAlertAction *action) {}]];

    // Never
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Never", @"First-run alert button to permanently skip release notes")
                      style:UIAlertActionStyleDefault
                      handler:^(UIAlertAction *action) {
                          [[NSUserDefaults standardUserDefaults] setObject:thisVersion forKey:@"VersionMsg"];
                          [[NSUserDefaults standardUserDefaults] synchronize];  // make sure we get written to disk (helpful for poor developers)
                      }]];

    [self presentViewController:alert animated:YES completion:nil];
}
// First-run quick-start alert part 1 of 2 end

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    //printf("numberOfSectionsInTableView %d\n", [TSTimeHistory numberOfPastDays]);
    return [TSTimeHistory numberOfPastDays];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    assert(tableView == theTableView);
    NSInteger numberOfRows = [TSTimeHistory numberOfPastTimesWithinDay:(int)section];
    //printf("Number of rows in section %d is %d\n", section, numberOfRows);
    return numberOfRows;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    assert(tableView == theTableView);
#if 0
    // Looks kind of ugly with no section title
    if ([TSTimeHistory numberOfPastDays] <= 1 && [TSTimeHistory firstPastDayIsTodayOrNil]) {
	return nil;
    }
#endif
    TSTimeHistory *event = [TSTimeHistory pastTimeAtOffsetFromPresent:0 withinDay:(int)section];
    return descriptionForDateOnly(event.time);
}

static BOOL isEditing = NO;

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

enum ESToolbarState {
    ESToolbarEditing,
    ESToolbarNoEventsNotEditing,
    ESToolbarWithEventsNotEditing
};
static ESToolbarState currentToolbarState = ESToolbarWithEventsNotEditing;

- (void)setEditButton {
    ESToolbarState newState = isEditing ? ESToolbarEditing : [TSTimeHistory numberOfPastTimes] == 0 ? ESToolbarNoEventsNotEditing : ESToolbarWithEventsNotEditing;
    if (newState != currentToolbarState) {
        NSArray *oldItems = [bottomToolbar items];
        assert(oldItems);
        assert([oldItems count] == 5);
        UIBarButtonItem *leftItem = [oldItems objectAtIndex:0];
        UIBarButtonItem *leftSpacer = [oldItems objectAtIndex:1];
        UIBarButtonItem *centerItem = [oldItems objectAtIndex:2];
        UIBarButtonItem *rightSpacer = [oldItems objectAtIndex:3];
        UIBarButtonItem *rightItem = [oldItems objectAtIndex:4];
        switch (newState) {
          case ESToolbarEditing:
            {
                UIButton *deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
                theDeleteButton = [deleteButton retain];
                theDeleteButton.titleLabel.font = [UIFont systemFontOfSize:18];
                assert(theTableView);
                setDeleteButtonText(theTableView);
                [theDeleteButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
                [deleteButton addTarget:self action:@selector(deleteDownAction:)      forControlEvents:UIControlEventTouchDown];
                [deleteButton addTarget:self action:@selector(deleteAction:)          forControlEvents:UIControlEventTouchUpInside];
                [deleteButton addTarget:self action:@selector(deleteCancelAction:)    forControlEvents:UIControlEventTouchUpOutside];
                [deleteButton addTarget:self action:@selector(deleteCancelAction:)    forControlEvents:UIControlEventTouchCancel];
                [deleteButton addTarget:self action:@selector(deleteDragExitAction:)  forControlEvents:UIControlEventTouchDragExit];
                [deleteButton addTarget:self action:@selector(deleteDragEnterAction:) forControlEvents:UIControlEventTouchDragEnter];
                leftItem = [[[UIBarButtonItem alloc] initWithCustomView:deleteButton] autorelease];
                leftItem.possibleTitles = [NSSet setWithObjects:@"Delete all", @"Help", nil];
                centerItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil] autorelease];
                rightItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(editMode)] autorelease];
                rightItem.enabled = YES;
                rightItem.possibleTitles = [NSSet setWithObjects:@"Edit", @"Cancel", nil];
            }
            break;
          case ESToolbarNoEventsNotEditing:
            leftItem = [[[UIBarButtonItem alloc] initWithTitle:@"Help" style:UIBarButtonItemStylePlain target:self action:@selector(startHelp)] autorelease];
            leftItem.possibleTitles = [NSSet setWithObjects:@"Delete all", @"Help", nil];
            centerItem = [[[UIBarButtonItem alloc] initWithTitle:@"Options" style:UIBarButtonItemStylePlain target:self action:@selector(startOptions)] autorelease];
            rightItem = [[[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStylePlain target:nil action:nil] autorelease];
            rightItem.enabled = NO;
            rightItem.possibleTitles = [NSSet setWithObjects:@"Edit", @"Cancel", nil];
            break;
          case ESToolbarWithEventsNotEditing:
            leftItem = [[[UIBarButtonItem alloc] initWithTitle:@"Help" style:UIBarButtonItemStylePlain target:self action:@selector(startHelp)] autorelease];
            leftItem.possibleTitles = [NSSet setWithObjects:@"Delete all", @"Help", nil];
            centerItem = [[[UIBarButtonItem alloc] initWithTitle:@"Options" style:UIBarButtonItemStylePlain target:self action:@selector(startOptions)] autorelease];
            rightItem = [[[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStylePlain target:self action:@selector(editMode)] autorelease];
            rightItem.enabled = YES;
            rightItem.possibleTitles = [NSSet setWithObjects:@"Edit", @"Cancel", nil];
            break;
          default:
            assert(0);
            break;
        }
        [bottomToolbar setItems:[NSArray arrayWithObjects:leftItem, leftSpacer, centerItem, rightSpacer, rightItem, nil]
                       animated:YES];
        currentToolbarState = newState;
    }
}

- (void)setEditMode:(BOOL)editMode {
    isEditing = editMode;
    if (!isEditing) {
        [TSTimeHistory clearAllDeleteFlags];
        [NSTimer scheduledTimerWithTimeInterval:0.35 target:theTableView selector:@selector(reloadData) userInfo:nil repeats:NO];
    }
    [theTableView setEditing:isEditing animated:YES];
    [self setEditButton];
#undef DEMO_HUGE_SELECT  // Huge meaning "all of the events"
#ifdef DEMO_HUGE_SELECT
    if (isEditing) {
        int numDays = [TSTimeHistory numberOfPastDays];
        for (int day = 0; day < numDays; day++) {
            int numTimesWithinDay = [TSTimeHistory numberOfPastTimesWithinDay:day];
            for (int timeWithinDay = 0; timeWithinDay < numTimesWithinDay; timeWithinDay++) {
                TSTimeHistory *pastTime = [TSTimeHistory pastTimeAtOffsetFromPresent:timeWithinDay withinDay:day];
                [pastTime toggleDeleteFlag];
            }
        }
        setDeleteButtonText(theTableView);
        [theTableView reloadData];
    }
#endif
}

- (void)editMode {
    [self setEditMode:!theTableView.editing];
}

- (IBAction)startHelp {
    UIViewController *vc = [[TSHelpViewController alloc] initWithNibName:@"TSHelpViewController" bundle:nil];
    [self.navigationController pushViewController:vc animated:true];
}

- (IBAction)startOptions {
    UIViewController *vc = [[TSTopOptionsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:true];
}

- (IBAction)startEdit {
    [self setEditMode:YES];
}

static TSRootViewController *theController = nil;

+ (TSRootViewController *)theController {
    return theController;
}

extern "C" {
bool buttonClick() {
    id buttonClickDefaultPresent = [[NSUserDefaults standardUserDefaults] objectForKey:@"TSButtonClick"];
    if (buttonClickDefaultPresent) {
	return [buttonClickDefaultPresent boolValue];
    } else {
	return true;
    }
}
}

static bool firstLoad = true;

- (void)setButtonColorsForNewConfidence:(TSConfidenceLevel)newConfidence {
    assert(stampButtonRow);
    NSArray *buttons = [stampButtonRow subviews];
    assert(buttons);
    for (UIButton *button in buttons) {
        NSString *bgImageName;
        if (button.titleLabel.text == nil) {  // Must be The Big Button
            if (newConfidence == TSConfidenceLevelGreen) {
                bgImageName = @"ConfidentButtonBG.png";
            } else {
                bgImageName = @"NotConfidentButtonBG.png";
            }
        } else {
            UIColor *titleColor;
            if (newConfidence == TSConfidenceLevelGreen) {
                bgImageName = @"ConfidentButtonOutlineBG.png";
                titleColor = [UIColor colorWithRed:(16/255.0) green:(140/255.0) blue:(68/255.0) alpha:1.0];
            } else {
                bgImageName = @"NotConfidentButtonOutlineBG.png";
                // Can't read this:
                // titleColor = [UIColor colorWithRed:(240/255.0) green:(211/255.0) blue:(49/255.0) alpha:1.0];
                titleColor =    [UIColor colorWithRed:(120/255.0) green:(105.5/255.0) blue:(24.5/255.0) alpha:1.0];
            }
            [button setTitleColor:titleColor forState:UIControlStateNormal];
        }
        UIImage *bgImage = [UIImage imageNamed:bgImageName];
        assert(bgImage);
        bgImage = [bgImage stretchableImageWithLeftCapWidth:150 topCapHeight:31];
        assert(bgImage);
        [button setBackgroundImage:bgImage forState:UIControlStateNormal];
    }
}

- (UIButton *)newButtonWithText:(NSString *)text {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setBackgroundImage:[UIImage imageNamed:@"RefZeroOn.png"] forState:UIControlStateNormal];
    [button setTitle:text forState:UIControlStateNormal];
    [button sizeToFit];
    return button;
}

- (void)stampDownAction:(id)sender {
    UIButton *button = (UIButton *)sender;
    [button setNeedsDisplay];
    [self buttonDown:sender];
    //printf("Down! Down! Down! sender is 0x%08x\n", (unsigned int)sender);
}

- (void)stampCancelAction:(id)sender {
    UIButton *button = (UIButton *)sender;
    [button setNeedsDisplay];
    //printf("Cancel! Cancel! Cancel! sender is 0x%08x\n", (unsigned int)sender);
}

- (void)stampUpAction:(id)sender {
    UIButton *button = (UIButton *)sender;
    [button setNeedsDisplay];
    [NSTimer scheduledTimerWithTimeInterval:0.2 target:button selector:@selector(setNeedsDisplay) userInfo:nil repeats:NO];
    //printf("Up! Up! Up! sender is 0x%08x\n", (unsigned int)sender);
}

- (void)stampDragExitAction:(id)sender {
    UIButton *button = (UIButton *)sender;
    [button setNeedsDisplay];
    //printf("Drag exit! Drag exit! Drag exit! sender is 0x%08x\n", (unsigned int)sender);
}

- (void)stampDragEnterAction:(id)sender {
    UIButton *button = (UIButton *)sender;
    [button setNeedsDisplay];
    //printf("Drag enter! Drag enter! Drag enter! sender is 0x%08x\n", (unsigned int)sender);
}

NSMutableArray *intervalLabels = nil;
BOOL timeLabelsSetToInterval = false;

- (void)setupAndAddButton:(UIButton *)button {
    [button addTarget:self action:@selector(stampDownAction:)      forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(stampUpAction:)        forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(stampCancelAction:)    forControlEvents:UIControlEventTouchUpOutside];
    [button addTarget:self action:@selector(stampCancelAction:)    forControlEvents:UIControlEventTouchCancel];
    [button addTarget:self action:@selector(stampDragExitAction:)  forControlEvents:UIControlEventTouchDragExit];
    [button addTarget:self action:@selector(stampDragEnterAction:) forControlEvents:UIControlEventTouchDragEnter];

    button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [stampButtonRow addSubview:button];
}

- (void)setupAndAddLabel:(UILabel *)label {
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.adjustsFontSizeToFitWidth = YES;
    // label.font = [UIFont fontWithName:@"Helvetica-Bold" size:36];
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor blackColor];
    label.backgroundColor = nil;
    label.opaque = NO;
    label.hidden = !timeLabelsSetToInterval;
    [intervalTimeLabelRow addSubview:label];
}

#if 0
- (void)setButtonTitleLabelsForStopwatch:(int)stopwatchNumber isRunning:(bool)isRunning containerViewArray:(NSArray *)buttons {
    assert([TSTopOptionsViewController masterMode] == TSMasterModeStopwatch);
    if (!buttons) {
        buttons = stampButtonRow.subviews;
    }
    assert(buttons);  // Only call this when we know we're in stopwatch mode and the buttons have been created
    int numStopwatches = [TSModeOptionsViewController numberOfStopwatches];
    NSString *ident = numStopwatches == 1 ? @"" : [NSString stringWithFormat:@" %d", stopwatchNumber + 1];
    UIButton *startStopButton = [buttons objectAtIndex:(stopwatchNumber * 2)];
    assert(startStopButton);
    [startStopButton setTitle:[NSString stringWithFormat:(isRunning ? @"Stop%@" : @"Start%@"), ident] forState:UIControlStateNormal];
    UIButton *lapResetButton = [buttons objectAtIndex:(stopwatchNumber * 2 + 1)];
    assert(lapResetButton);
    [lapResetButton setTitle:[NSString stringWithFormat:(isRunning ? @"Lap%@" : @"Reset%@"), ident] forState:UIControlStateNormal];
}
#endif

- (void)makeNewButtons {
    assert(stampButtonRow);
    for (UIView *oldView in stampButtonRow.subviews) {
        [oldView removeFromSuperview];
    }
    for (UIView *oldView in intervalTimeLabelRow.subviews) {
        [oldView removeFromSuperview];
    }
    if (intervalLabels) {
        [intervalLabels removeAllObjects];
    } else {
        intervalLabels = [[NSMutableArray arrayWithCapacity:5] retain];
    }
    TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
    assert(masterMode >= 0 && masterMode < TSNumMasterModes);
    NSArray *arr = [TSCustomNameEditorViewController customNamesForMode:masterMode];
    NSInteger numButtons = 0;
    switch(masterMode) {
      case TSMasterModeClassic:
        if (arr) {
            numButtons = [arr count];
            for (NSString *buttonName in arr) {
                UIButton *button = [self newButtonWithText:buttonName];
                button.titleLabel.numberOfLines = 2;
                button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
                button.titleLabel.textAlignment = NSTextAlignmentCenter;
                button.titleLabel.adjustsFontSizeToFitWidth = YES;
                [self setupAndAddButton:button];
            }
        } else {
            numButtons = 1;
            // old style button
            NSString *bgImageName;
            TSConfidenceLevel newConfidence = [TSTimeHistory currentConfidence];
            if (newConfidence == TSConfidenceLevelGreen) {
                bgImageName = @"ConfidentButtonBG.png";
            } else {
                bgImageName = @"NotConfidentButtonBG.png";
            }
            UIImage *bgImage = [UIImage imageNamed:bgImageName];
            assert(bgImage);
            bgImage = [bgImage stretchableImageWithLeftCapWidth:149 topCapHeight:31];
            assert(bgImage);
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            [button setBackgroundImage:bgImage forState:UIControlStateNormal];
            [self setupAndAddButton:button];
        }
        break;
#if 0
      case TSMasterModeStopwatch:
        {
            int numStopwatches = [TSModeOptionsViewController numberOfStopwatches];
            assert(numStopwatches > 0);
            int buttonsPerStopwatch = 2;  // No lap button any more
            numButtons = numStopwatches * buttonsPerStopwatch;
            for (int stopwatchNumber = 0; stopwatchNumber < numStopwatches; stopwatchNumber++) {
                UIButton *button = [self newButtonWithText:@"Start/Stop"];
                button.titleLabel.numberOfLines = 2;
                button.titleLabel.lineBreakMode = UILineBreakModeWordWrap;
                button.titleLabel.textAlignment = UITextAlignmentCenter;
                button.titleLabel.adjustsFontSizeToFitWidth = YES;
                button.tag = TSTagForSpecialEvent(TSSpecialEventStart, stopwatchNumber);
                [self setupAndAddButton:button];

                button = [self newButtonWithText:@"Lap/Reset"];
                button.titleLabel.numberOfLines = 2;
                button.titleLabel.lineBreakMode = UILineBreakModeWordWrap;
                button.titleLabel.textAlignment = UITextAlignmentCenter;
                button.titleLabel.adjustsFontSizeToFitWidth = YES;
                button.tag = TSTagForSpecialEvent(TSSpecialEventReset, stopwatchNumber);
                [self setupAndAddButton:button];

                UILabel *label = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 10, 10)] autorelease];
                label.tag = stopwatchNumber;
                [self setupAndAddLabel:label];
                [intervalLabels addObject:label];
            }
            NSArray *buttons = stampButtonRow.subviews;
            for (int stopwatchNumber = 0; stopwatchNumber < numStopwatches; stopwatchNumber++) {
                [self setButtonTitleLabelsForStopwatch:stopwatchNumber isRunning:[TSTimeHistory timerIsRunning:stopwatchNumber] containerViewArray:buttons];
            }            
        }
        break;
#endif
      case TSMasterModeProject:
        {
            numButtons = arr ? [arr count] : 1;
            assert(arr);
            if (arr) {
                assert([arr count] != 0);  // should never leave the array in this state
                int i = 0;
                for (NSString *name in arr) {
                    UIButton *button = [self newButtonWithText:name];
                    button.titleLabel.numberOfLines = 2;
                    button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
                    button.titleLabel.textAlignment = NSTextAlignmentCenter;
                  button.titleLabel.adjustsFontSizeToFitWidth = YES;
                    int timerNumber = [TSTimeHistory timerNumberForProjectName:name createIfNecessary:true];
                    int tag = TSTagForSpecialEvent(TSSpecialEventProjectChange, timerNumber);
                    button.tag = tag;
                    [self setupAndAddButton:button];
                    i++;
                    UILabel *label = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 10, 10)] autorelease];
                    label.tag = timerNumber;
                    [self setupAndAddLabel:label];
                    [intervalLabels addObject:label];
                }
            } else {
                assert(false);
            }
        }
        break;
      default:
        assert(false);
        break;
    }
    if (numButtons <= 1) {
        stampButtonRow.edgeMargin = 9;  // reproduces old look
        intervalTimeLabelRow.spacing = 5;
        intervalTimeLabelRow.edgeMargin = 9;
    } else {
        intervalTimeLabelRow.spacing = 20;
        intervalTimeLabelRow.edgeMargin = 5;
    }
    [stampButtonRow setNeedsLayout];
}

+ (void)makeNewButtonsAndSetColors {
    if (theController) {  // If no controller, we'll make new buttons when the view loads again
        [theController makeNewButtons];
        [theController setButtonColorsForNewConfidence:[TSTimeHistory currentConfidence]];
        [TSTimeHistory recalculateAccumulatedTimes];
    }
}

- (void)viewDidLoad {
    [TSRootViewController reloadDefaults];  // Put this before the assignment of theController

    [self setGettingSyncColor];

    printf("TSRootViewController viewDidLoad\n");
    theController = self;
    [self setEditButton];

    assert(theTableView);
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = YES;
    }

    [self makeNewButtons];
    [TSTimeHistory recalculateAccumulatedTimes];
    [self setButtonColorsForNewConfidence:[TSTimeHistory currentConfidence]];

    // currentErrorLabel.textColor = [UIColor lightGrayColor];

    if (firstLoad) {
	firstLoad = false;
	// First-run quick-start alert part 2 of 2 start
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	firstVersionRun = [defaults objectForKey:@"FirstVersionRun"];
	thisVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	//printf("this version %s\n", [thisVersion UTF8String]);
	if (!firstVersionRun) {
	    // See if this user has run ETS before.
	    NSString *initString = [defaults objectForKey:@"TimeBase"];
	    if (initString) {
		firstVersionRun = @"1.1";
	    } else {
		firstVersionRun = thisVersion;
	    }
	    [defaults setObject:firstVersionRun forKey:@"FirstVersionRun"];
	    [defaults synchronize];
	}
	//printf("firstVersionRun version %s\n", [firstVersionRun UTF8String]);
	isNewbie = [firstVersionRun compare:thisVersion] == NSOrderedSame;
	shouldShowQuickStart = false;
	NSString *lastVersion = [defaults objectForKey:@"VersionMsg"];
	//printf("lastVersion %s\n", [lastVersion UTF8String]);
	if (lastVersion) {
	    if (thisVersion) {
		if ([thisVersion compare:lastVersion] != NSOrderedSame) {
                    if ([thisVersion compare:@"2.0.7"] == NSOrderedSame && ([lastVersion compare:@"2.0.6"] == NSOrderedSame ||
                                                                            [lastVersion compare:@"2.0.5"] == NSOrderedSame ||
                                                                            [lastVersion compare:@"2.0.4"] == NSOrderedSame ||
                                                                            [lastVersion compare:@"2.0.3"] == NSOrderedSame ||
                                                                            [lastVersion compare:@"2.0.2"] == NSOrderedSame)) {
                        // skip equivalent upgrade(s)
                    } else {
                        shouldShowQuickStart = true;
                    }
		}
	    }
	} else {
	    shouldShowQuickStart = true;
	}
	if (shouldShowQuickStart) {
	    [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(showQuickStart) userInfo:nil repeats:NO];
	}
	// First-run quick-start alert part 2 of 2 end
    }

    [super viewDidLoad];
}

- (void)dealloc {
    printf("TSRootViewController dealloc\n");
    theController = nil;
    [super dealloc];
}

static bool apparent;  // willAppear && !willDisappear
static NSTimer *updateTimer = nil;

static ESTimeInterval
timeUntilNextFractionalSecond(double fractionalSecond) {
    ESTimeInterval now = ESTime::currentTime();
    ESTimeInterval timeSinceLastFractionalSecond = ESUtil::fmod(now, fractionalSecond);
    return fractionalSecond - timeSinceLastFractionalSecond;
}

-(void)setCurrentTimeLabelsForTime:(ESTimeInterval)now liveLeapSecondCorrection:(ESTimeInterval)liveLeapSecondCorrection {
    BOOL useIntervalLabels = ([TSTimeHistory currentTimeBase] == TSTimeBaseInterval) && [TSTopOptionsViewController masterMode] != TSMasterModeClassic;
    if (useIntervalLabels != timeLabelsSetToInterval) {
        currentAbsoluteTimeLabel.hidden = useIntervalLabels;
        for (UILabel *label in intervalLabels) {
            label.hidden = !useIntervalLabels;
        }
        timeLabelsSetToInterval = useIntervalLabels;
    }
    if (useIntervalLabels) {
        for (UILabel *label in intervalLabels) {
            label.text = descriptionForTimeOnlyForTimerNumber(now, liveLeapSecondCorrection, label.tag);
        }
    } else {
        currentAbsoluteTimeLabel.text = descriptionForTimeOnlyForTimerNumber(now, liveLeapSecondCorrection, -1);
    }
}

- (void)refresh:(NSTimer *)theTimer {
    assert([NSThread isMainThread]);
    //[TSTime reportAllSkewsAndOffset:"refresh"];
    ESTimeInterval liveLeapSecondCorrection;
    ESTimeInterval now = ESTime::currentTimeWithLiveLeapSecondCorrection(&liveLeapSecondCorrection);
    [self setCurrentTimeLabelsForTime:now liveLeapSecondCorrection:liveLeapSecondCorrection];
    currentDateLabel.text = descriptionForDateOnly(now);
    float timeError = ESTime::currentTimeError();
    if (timeError > 1E7) {
	currentErrorLabel.text = NSLocalizedString(@"± ???", @"Main panel display when no sync obtained");
    } else {
	currentErrorLabel.text = [NSString stringWithFormat:NSLocalizedString(@"±%.2fs", @"Main panel display of sync error"), timeError];
    }
    updateTimer = [NSTimer scheduledTimerWithTimeInterval:timeUntilNextFractionalSecond(0.1) target:self selector:@selector(refresh:) userInfo:nil repeats:NO];
}

- (void)startRefresh {
    assert([NSThread isMainThread]);
    assert(!updateTimer);
    updateTimer = [NSTimer scheduledTimerWithTimeInterval:timeUntilNextFractionalSecond(0.1) target:self selector:@selector(refresh:) userInfo:nil repeats:NO];
}

- (void)stopRefresh {
    assert([NSThread isMainThread]);
    assert(updateTimer);
    [updateTimer invalidate];
    updateTimer = nil;
}

- (void)scrollToNext {
    if ([TSTimeHistory numberOfPastTimes] > 0) {
	NSIndexPath *firstRowOfNextSection = [NSIndexPath indexPathForRow:0 inSection:0];
	[theTableView scrollToRowAtIndexPath:firstRowOfNextSection atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
}

- (void)setLogoHidden:(BOOL)newHidden {
    [UIView animateWithDuration:2.0 animations:^{
        logoView.alpha = newHidden ? 0 : 1;
    }];
}

- (void)delayedStartupSync {
    ESTime::resync(false/*!userRequested*/);
}

static bool firstTime = true;

- (void)viewWillAppear:(BOOL)animated {
    //printf("root will appear\n");
    assert(!apparent);
    apparent = true;
    [theTableView reloadData];
    [self setLogoHidden:([TSTimeHistory numberOfPastTimes] != 0)];
    [self startRefresh];
    [self setEditButton];
    if (firstTime) {
        [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(delayedStartupSync) userInfo:nil repeats:NO];
        firstTime = false;
    }
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    //printf("root will disappear\n");
    assert(apparent);
    apparent = false;
    [self stopRefresh];
    [super viewWillDisappear:animated];
}

#define TIME_FONT_SIZE 20

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    //printf("cellForRowAtIndexPath %d %d\n", indexPath.section, indexPath.row);
    assert(tableView == theTableView);
    NSString *mainText = @"";
    NSString *detailText = @"";
    NSString *mainText2 = @"";
    NSString *detailText2 = @"";
    TSTimeHistory *pastTime = nil;
    TSConfidenceLevel confidenceLevel = TSConfidenceLevelYellow;  // Doesn't matter
    NSString *reuseID = @"StampCellOneRow";
    bool oneRow = true;
    bool deleteFlag = false;
    bool useProjectNib = false;
    bool intervalMode = [TSTimeHistory currentTimeBase] == TSTimeBaseInterval;
    bool withZero = intervalMode;
    if (indexPath.row < [TSTimeHistory numberOfPastTimesWithinDay:(int)indexPath.section]) {
	pastTime = [TSTimeHistory pastTimeAtOffsetFromPresent:(int)indexPath.row withinDay:(int)indexPath.section];
        deleteFlag = pastTime.deleteFlag;
	NSString *timeDesc = descriptionForTimeOnly(pastTime.time, pastTime.liveLeapSecondCorrection, pastTime.accumulatedTimeReference, pastTime.accumulatedTimeReferenceLiveLeap);
	NSString *firstComponent = [[timeDesc componentsSeparatedByString:@":"] objectAtIndex:0];
	if ([firstComponent length] == 1) {
	    timeDesc = [NSString stringWithFormat:@"  %@", timeDesc];
	}
        bool descriptionIsEmpty = [pastTime.description compare:@" "] == NSOrderedSame;
        switch(pastTime.specialType) {
          case TSSpecialEventProjectChange:
            reuseID = @"ProjectStampCellTwoRows";
            useProjectNib = true;
            mainText = pastTime.description;  // we stash the previous project in the description field
            if ([mainText compare:@" "] != NSOrderedSame || !intervalMode) {
                detailText = timeDesc;
            }
            if (pastTime.specialTimerNumber >= 0) {
                mainText2 = [TSTimeHistory projectNameForTimerNumber:pastTime.specialTimerNumber];
                detailText2 = descriptionForTimeOnly(pastTime.time, pastTime.liveLeapSecondCorrection, pastTime.time - pastTime.accumulatedProject2Time, 0);
            } else {
                mainText2 = @"";
                detailText2 = @"";
            }
            oneRow = false;
            break;
#if 0
          case TSSpecialEventStart:
          case TSSpecialEventStop:
          case TSSpecialEventLap:
          case TSSpecialEventReset:
            reuseID = @"StampCellTwoRows";
            mainText = [NSString stringWithFormat:@"%s%@",
                                 specialNames[pastTime.specialType],
                                 [TSModeOptionsViewController numberOfStopwatches] == 1 ? @"" : [NSString stringWithFormat:@" %d", pastTime.specialTimerNumber + 1]];
            if (displayOrder == TSOrderTimeFirst) {
                detailText = mainText;
                mainText = timeDesc;
            } else {
                detailText = timeDesc;
            }
            oneRow = false;
            withZero = false;  // Avoid confusion:  Stopwatches have their own zero mechanism
            break;

#endif
          default:
            if (displayOrder == TSOrderTimeFirst || (displayOrder != TSOrderDescFirst && descriptionIsEmpty)) {
                mainText = timeDesc;
                if (descriptionIsEmpty) {
                    detailText = nil;
                    reuseID = @"StampCellOneRow";
                    oneRow = true;
                } else {
                    detailText = pastTime.description;
                    reuseID = @"StampCellTwoRows";
                    oneRow = false;
                }
            } else {
                reuseID = @"StampCellTwoRows";
                oneRow = false;
                mainText = pastTime.description;
                detailText = timeDesc;
            }
            break;
        }
	confidenceLevel = pastTime.confidenceLevel;
    }
    reuseID = [reuseID stringByAppendingString:(withZero ? @"WithZero" : @"NoZero")];
    UITableViewCell *tableViewCell = [tableView dequeueReusableCellWithIdentifier:reuseID];
    if (!tableViewCell) {
        NSString *nibName = useProjectNib ? @"ProjectStampCell" : @"StampCell";
	[[NSBundle mainBundle] loadNibNamed:nibName owner:self options:nil];
	tableViewCell =
	    oneRow
	     ? withZero
	        ? loadedTVCellWithOneRowWithZero
	        : loadedTVCellWithOneRowNoZero
	     : withZero
	        ? loadedTVCellWithTwoRowsWithZero
	        : loadedTVCellWithTwoRowsNoZero;
	self.loadedTVCellWithTwoRowsNoZero = nil;
	self.loadedTVCellWithOneRowNoZero = nil;
	self.loadedTVCellWithTwoRowsWithZero = nil;
	self.loadedTVCellWithOneRowWithZero = nil;
    }
    assert(tableViewCell);
    UILabel *textLabel = (UILabel *)[tableViewCell viewWithTag:TEXT_LABEL_TAG];
    UILabel *detailTextLabel = (UILabel *)[tableViewCell viewWithTag:DETAIL_TEXT_LABEL_TAG];
    UILabel *text2Label = (UILabel *)[tableViewCell viewWithTag:TEXT_LABEL2_TAG];
    if (text2Label) {
        [text2Label setText:mainText2];
    }
    UILabel *detailText2Label = (UILabel *)[tableViewCell viewWithTag:DETAIL_TEXT_LABEL2_TAG];
    if (detailText2Label) {
        [detailText2Label setText:detailText2];
    }
    UIImageView *imageView = (UIImageView *)[tableViewCell viewWithTag:ACCURACY_IMAGE_TAG];
    if (withZero) {
	UIButton *zeroButton = (UIButton *)[tableViewCell viewWithTag:ZERO_BUTTON_TAG];
        assert(zeroButton);
	if ([TSTimeHistory eventIsReferenceZeroAtOffsetFromPresent:(int)indexPath.row withinDay:(int)indexPath.section]) {
	    [zeroButton setImage:[UIImage imageNamed:@"RefZeroOn.png"] forState:UIControlStateNormal];
	} else {
	    [zeroButton setImage:[UIImage imageNamed:@"RefZeroOff.png"] forState:UIControlStateNormal];
	}
    }
    textLabel.text = mainText;
    if (detailTextLabel) {
	detailTextLabel.text = detailText;
    }
//    textLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:TIME_FONT_SIZE];
    // detailTextLabel.textColor = [UIColor blackColor];
    if (confidenceLevel == TSConfidenceLevelGreen) {
	imageView.image = [UIImage imageNamed:@"GreenLED.png"];
    } else {
	imageView.image = [UIImage imageNamed:@"YellowLED.png"];
    }
    textLabel.adjustsFontSizeToFitWidth = YES;
    textLabel.minimumScaleFactor = 0.8;
    detailTextLabel.adjustsFontSizeToFitWidth = YES;
    return tableViewCell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(tableView == theTableView);
    TSTimeHistory *pastTime = [TSTimeHistory pastTimeAtOffsetFromPresent:(int)indexPath.row withinDay:(int)indexPath.section];
    if (tableView.editing) {
        bool nowFlagged = [pastTime toggleDeleteFlag];
        assert(nowFlagged);
        nowFlagged = nowFlagged;
        setDeleteButtonText(tableView);
    } else {
        int slot = [TSTimeHistory slotForOffset:(int)indexPath.row withinDay:(int)indexPath.section];
        NSString *nibName = isIpad() ? @"TSEventViewController_Pad" : @"TSEventViewController_Phone";
        UIViewController *vc = [[TSEventViewController alloc] initWithNibName:nibName bundle:nil event:pastTime slot:slot];
        [self.navigationController pushViewController:vc animated:true];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(tableView == theTableView);
    TSTimeHistory *pastTime = [TSTimeHistory pastTimeAtOffsetFromPresent:(int)indexPath.row withinDay:(int)indexPath.section];
    assert(tableView.editing);
    bool nowFlagged = [pastTime toggleDeleteFlag];
    assert(!nowFlagged);
    nowFlagged = nowFlagged;
    setDeleteButtonText(tableView);
}

- (IBAction)cellZero:(id)sender {
    assert(sender);
    assert([sender isKindOfClass:[UIButton class]]);
    UIView *grandparentView = ((UIButton *)sender).superview.superview;
    assert(grandparentView);
    // printf("My grandparent is %s\n", [[[grandparentView class] description] UTF8String]);
    UITableViewCell *cell;
    if ([grandparentView isKindOfClass:[UITableViewCell class]]) {
        cell = (UITableViewCell *)grandparentView;
    } else {
        assert([grandparentView.superview isKindOfClass:[UITableViewCell class]]);
        cell = (UITableViewCell *)grandparentView.superview;
    }
    NSIndexPath *indexPath = [theTableView indexPathForCell:cell];
    assert(indexPath);
    [TSTimeHistory toggleReferenceZeroForEventAtOffsetFromPresent:(int)indexPath.row withinDay:(int)indexPath.section];
    [theTableView reloadData];
}

static UIColor *grayColor = nil;
static UIColor *yellowColor = nil;
static UIColor *greenColor = nil;

UIColor *getColorForConfidenceLevel(TSConfidenceLevel confidenceLevel) {
    if (!yellowColor) {
	yellowColor = [[UIColor colorWithRed:1.0 green:1.0 blue:0.8 alpha:1] retain];
	greenColor =  [[UIColor colorWithRed:0.8 green:1.0 blue:0.8 alpha:1] retain];
	grayColor =  [[UIColor colorWithRed:0.80 green:0.80 blue:0.80 alpha:1] retain];
    }
    if (confidenceLevel == TSConfidenceLevelYellow) {
	return yellowColor;
    } else {
	assert(confidenceLevel == TSConfidenceLevelGreen);
	return greenColor;
    }
}

- (IBAction)buttonDown:(id)sender {
    TSTimeHistory *event = [TSTimeHistory addTimeAtNow];
    if (buttonClick()) {
	TSPlayButtonPressSound();
    }

    UIButton *button = (UIButton *)sender;
    NSString *buttonTitle = [button titleForState:UIControlStateNormal];
    NSInteger tag = button.tag;
    if (tag > 0) {  // Note that "not special" has value zero, so any special type will result in nonzero tag
        assert(false);  // stopwatch/project mode not supported
#if 0
        TSSpecialEventType specialType = TSSpecialEventTypeForTag(tag);
        int specialTimerNumber = TSSpecialTimerNumberForTag(tag);
        if ([TSTimeHistory timerIsRunning:specialTimerNumber]) {
            if (specialType == TSSpecialEventStart) {
                specialType = TSSpecialEventStop;
                [self setButtonTitleLabelsForStopwatch:specialTimerNumber isRunning:false containerViewArray:nil];
            } else if (specialType == TSSpecialEventReset) {
                specialType = TSSpecialEventLap;
            } else {
                specialTimerNumber = -1;
            }
        } else {
            if (specialType == TSSpecialEventStart) {
                [self setButtonTitleLabelsForStopwatch:specialTimerNumber isRunning:true containerViewArray:nil];
            }
        }
        [event setSpecialType:specialType timerNumber:specialTimerNumber];
#endif
    } else if (buttonTitle && [buttonTitle length]) {
        [event setDescription:buttonTitle];
    }
    [TSTimeHistory recalculateAccumulatedTimes];

    if ([TSTimeHistory numberOfPastTimes] > 1) { // If we didn't just add the only one
	[self scrollToNext];
    } else {
	// We did just add the only one:  Remove the logo
	[self setLogoHidden:YES];
        // and turn on the edit button
        [self setEditButton];
    }
    [theTableView beginUpdates];
    if (![TSTimeHistory firstTwoPastTimesAreOnSameDay]) {
	[theTableView insertSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationTop];
    }
    [theTableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationTop];
    [theTableView endUpdates];
}

- (IBAction)rotateTimeBase:(id)sender {
    [TSTimeHistory rotateTimeBase];
}

- (IBAction)resync:(id)sender {
    ESTime::resync(true/*userRequested*/);
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (void)viewWillTransitionToSize:(CGSize)size 
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    printf("viewWillTransitionToSize %g %g\n", size.width, size.height);
    // Figure out effective orientation here.  Or somewhere else.
    //     [TSSharedAppDelegate setNewOrientation:self.interfaceOrientation];
}

- (NSUInteger)supportedInterfaceOrientations {
    return  (1 << UIInterfaceOrientationPortrait) | (1 << UIInterfaceOrientationLandscapeLeft) |
             (1 << UIInterfaceOrientationLandscapeRight) | (1 << UIInterfaceOrientationPortraitUpsideDown);
}

- (void)reallyClear {
    NSInteger numSectionsBefore = [self numberOfSectionsInTableView:theTableView];
    [TSTimeHistory removeAllPastTimes];
    [TSTimeHistory setCurrentDescription:@" "];
    [theTableView beginUpdates];
    NSRange indexRange;
    indexRange.location = 0;
    indexRange.length = numSectionsBefore;
    [theTableView deleteSections:[NSIndexSet indexSetWithIndexesInRange:indexRange]
		withRowAnimation:UITableViewRowAnimationTop];
    [theTableView endUpdates];
    [TSTimeHistory recalculateAccumulatedTimes];
    [NSTimer scheduledTimerWithTimeInterval:0.5 target:theTableView selector:@selector(reloadData) userInfo:nil repeats:NO];
    [self setEditMode:NO];
    [self setLogoHidden:NO];
}

- (void)clearAction:(id)sender {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Clear", "Clear button title")
                                                                   message:NSLocalizedString(@"Remove all events and descriptions?", "")
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

- (void)deleteDownAction:(id)sender {
    //printf("Down! Down! Down! sender is 0x%08x\n", (unsigned int)sender);
}

- (void)deleteCancelAction:(id)sender {
    //printf("Cancel! Cancel! Cancel! sender is 0x%08x\n", (unsigned int)sender);
}

- (void)deleteAction:(id)sender {
    //printf("Delete! Delete! Delete! sender is 0x%08x\n", (unsigned int)sender);
    
    assert(theTableView);
    NSArray *indexPathsFlaggedForDelete = [theTableView indexPathsForSelectedRows];
    NSInteger deleteCount = [indexPathsFlaggedForDelete count];
    if (deleteCount == 0) {  // Means delete everybody
        [self clearAction:sender];
    } else {
        NSIndexSet *nowEmptySections = [TSTimeHistory deleteFlaggedTimes];

        if (deleteCount < 1000) {
            [theTableView beginUpdates];
            [theTableView deleteRowsAtIndexPaths:indexPathsFlaggedForDelete
                                withRowAnimation:UITableViewRowAnimationTop];
            [theTableView deleteSections:nowEmptySections
                        withRowAnimation:UITableViewRowAnimationTop];
            [theTableView endUpdates];
        }

        unsigned int numPastLeft = [TSTimeHistory numberOfPastTimes];
        if (numPastLeft == 0) {
            [self setLogoHidden:NO];
        }
    }
    [TSTimeHistory recalculateAccumulatedTimes];
    [self setEditMode:NO];
    [NSTimer scheduledTimerWithTimeInterval:0.5 target:theTableView selector:@selector(reloadData) userInfo:nil repeats:NO];  // in case the zero reference was deleted; then a new one needs to be turned on
}

- (void)deleteDragExitAction:(id)sender {
    //printf("Drag exit! Drag exit! Drag exit! sender is 0x%08x\n", (unsigned int)sender);
}

- (void)deleteDragEnterAction:(id)sender {
    //printf("Drag enter! Drag enter! Drag enter! sender is 0x%08x\n", (unsigned int)sender);
}

static TSConfidenceLevel displayedConfidence = TSConfidenceLevelYellow;  // as set in nib

- (void)reloadTablePreservingSelection {
    NSArray<NSIndexPath*> *selectedItems = theTableView.indexPathsForSelectedRows;
    [theTableView reloadData];
    for (NSIndexPath *selectedItem in selectedItems) {
        [theTableView selectRowAtIndexPath:selectedItem animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
}

- (void)syncStatusChangedInMainThread {
    assert([NSThread isMainThread]);
    TSConfidenceLevel newConfidence = [TSTimeHistory currentConfidence];
    if (ESTime::syncActive()) {
	currentErrorLabel.textColor = gettingSyncColor;
    } else {
	currentErrorLabel.textColor = [UIColor whiteColor];
    }
    if (newConfidence != displayedConfidence) {
	displayedConfidence = newConfidence;
        [self reloadTablePreservingSelection];
        [self setButtonColorsForNewConfidence:newConfidence];
    }
}

+ (void)syncStatusChangedInMainThread {
    if (theController) {
	[theController syncStatusChangedInMainThread];
    }
}

- (void)rotateTimeBaseCallback {
    [self reloadTablePreservingSelection];
}

- (void)reloadTableData {
    [self reloadTablePreservingSelection];
}

+ (void)rotateTimeBaseCallback {
    assert([NSThread isMainThread]);
    if (theController) {
	[theController rotateTimeBaseCallback];
    }
}

+ (void)reloadDefaults {
    assert([NSThread isMainThread]);
    NSString *defaultStr = [[NSUserDefaults standardUserDefaults] stringForKey:@"TSDisplayOrder"];
    if (!defaultStr) {
        displayOrder = TSOrderAuto;
    } else if ([defaultStr compare:@"timeFirst"] == NSOrderedSame) {
        displayOrder = TSOrderTimeFirst;
    } else if ([defaultStr compare:@"descFirst"] == NSOrderedSame) {
        displayOrder = TSOrderDescFirst;
    } else {
        assert([defaultStr compare:@"auto"] == NSOrderedSame);
        displayOrder = TSOrderAuto;
    }
    if (theController) {
	[theController reloadTableData];
    }
}

@end
