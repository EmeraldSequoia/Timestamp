//
//  TSTopOptionsViewController.m
//
//  Created by Steve Pucci 05 Feb 2012
//  Copyright Emerald Sequoia LLC 2012. All rights reserved.
//

#import "TSTopOptionsViewController.h"
#import "TSRootViewController.h"
#import "TSEmailOptionsViewController.h"
#import "TSCustomNameEditorViewController.h"

#define SECTION_CUSTOMIZE     0
#define SECTION_DISPLAY_ORDER 1
#define SECTION_AUTO_LOCK     2
#define SECTION_THRESHOLD     3
#define SECTION_SOUNDS        4
#define SECTION_DISPLAY_CYCLE 5
#define SECTION_EMAIL         6
#define SECTION_MULTI_ZERO    7
#define NUM_SECTIONS 8

//#define SECTION_JD            5

#define ROW_AUTO_LOCK_PWR 0
#define ROW_AUTO_LOCK_BAT 1

#define ROW_DISPLAY_TIME_FIRST        0
#define ROW_DISPLAY_DESCRIPTION_FIRST 1
#define ROW_DISPLAY_ORDER_AUTO        2

#define ROW_EMAIL_FORMAT     0
#define ROW_EMAIL_MAX_DAYS   1
#define ROW_EMAIL_MAX_EVENTS 2

#define CURRENT_MODE_LABEL_TAG 1
#define VALUE_FIELD_TAG 1
#define TITLE_FIELD_TAG 2
#define STEPPER_FIELD_TAG 3

#define MIN_THRESH 0.16
#define MAX_THRESH 1.0
#define STEP_THRESH 0.02

bool classicCycleFlags[TSNumTimeBases];
static TSMasterModeType masterMode = TSMasterModeClassic;

@implementation TSTopOptionsViewController

- (id)init {
    [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

+(TSMasterModeType)masterMode {
    return masterMode;
}

+(void)saveDefaults {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:TSNumTimeBases];
    for (int i = 0; i < TSNumTimeBases; i++) {
        [arr addObject:[NSNumber numberWithBool:classicCycleFlags[i]]];
    }
    [userDefaults setObject:arr forKey:@"TSClassicDisplayCycleFlags"];
}

+(void)loadDefaults {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    // set classicCycleFlags
    BOOL useTTForJD = [userDefaults boolForKey:@"TSUseTTForJD"];
    NSArray *arr = [userDefaults arrayForKey:@"TSClassicDisplayCycleFlags"];
    if (!arr) {
        classicCycleFlags[TSTimeBaseLocal12] = true;
        classicCycleFlags[TSTimeBaseLocal24] = true;
        classicCycleFlags[TSTimeBaseUTC24] = true;
        if (useTTForJD) { 
            classicCycleFlags[TSTimeBaseJDTT] = true;
            classicCycleFlags[TSTimeBaseJDUTC] = false;
        } else {
            classicCycleFlags[TSTimeBaseJDTT] = false;
            classicCycleFlags[TSTimeBaseJDUTC] = true;
        }
        classicCycleFlags[TSTimeBaseInterval] = true;
    } else {
        assert([arr count] >= TSNumTimeBases);
        int i = 0;
        bool foundOne = 0;
        for (NSNumber *obj in arr) {
            if (i < TSNumTimeBases) {
                if ((classicCycleFlags[i++] = [obj boolValue])) {
                    foundOne = true;
                }
            }
        }
        if (!foundOne) {
            classicCycleFlags[TSTimeBaseLocal12] = true;
        }
    }
}

// UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return NUM_SECTIONS;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch(section) {
        //case SECTION_JD:
      case SECTION_AUTO_LOCK:
      case SECTION_SOUNDS:
      case SECTION_CUSTOMIZE:
        return nil;
      case SECTION_DISPLAY_ORDER:
        return @"Auto means put the description on top unless it's empty";
      case SECTION_EMAIL:
        return @"To send unlimited days or events, specify 0 for max";
      case SECTION_MULTI_ZERO:
        return @"If multiple zeroes are allowed, intervals always measure forward from previous zero.  If they are not allowed, intervals measure forward and backward from a single zero.";
      case SECTION_THRESHOLD:
        return @"Events and buttons turn green when the error is less than this number of seconds.\nValues must be between 0.16 and 1.0";
      case SECTION_DISPLAY_CYCLE:
        return @"Tap on any time in Timestamp to cycle among the selected displays above";
    }
    assert(false);
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch(section) {
      case SECTION_AUTO_LOCK:
        return @"Disable Auto-Lock";
      case SECTION_DISPLAY_ORDER:
        return @"Time and Description";
      case SECTION_SOUNDS:
        return @"Sounds";
      case SECTION_CUSTOMIZE:
        return @"Customize";
      case SECTION_THRESHOLD:
        return @"Error Threshold";
      case SECTION_DISPLAY_CYCLE:
        return @"Display Cycle";
        //case SECTION_JD:
        //return @"JD";
      case SECTION_EMAIL:
        return @"Email";
      case SECTION_MULTI_ZERO:
        return @"Intervals";
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch(section) {
      case SECTION_AUTO_LOCK:
        return 2;
      case SECTION_DISPLAY_ORDER:
        return 3;
      case SECTION_SOUNDS:
        return 1;
      case SECTION_CUSTOMIZE:
        return 1;
      case SECTION_THRESHOLD:
        return 1;
      case SECTION_DISPLAY_CYCLE:
        return TSNumTimeBases;
        //case SECTION_JD:
        //return 1;
      case SECTION_EMAIL:
        return 3;
      case SECTION_MULTI_ZERO:
        return 1;
    }
    assert(false);
    return 0;
}

static bool
rowCheckedForOrderDefault(NSUserDefaults *userDefaults,
                          TSDisplayOrder order) {
    NSString *defaultStr = [userDefaults stringForKey:@"TSDisplayOrder"];
    if (!defaultStr) {
        return order == TSOrderAuto;
    }
    switch(order) {
      case TSOrderTimeFirst:
        return [defaultStr compare:@"timeFirst"] == NSOrderedSame;
      case TSOrderDescFirst:
        return [defaultStr compare:@"descFirst"] == NSOrderedSame;
      case TSOrderAuto:
        return [defaultStr compare:@"auto"] == NSOrderedSame;
      default:
        assert(false);
        return false;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *reuseIdentifier = nil;
    switch(indexPath.section) {
      case SECTION_AUTO_LOCK:
      case SECTION_SOUNDS:
      case SECTION_DISPLAY_CYCLE:
        //case SECTION_JD:
      case SECTION_MULTI_ZERO:
      case SECTION_DISPLAY_ORDER:
        reuseIdentifier = @"TSTopOptionCheck";
        break;
      case SECTION_CUSTOMIZE:
        reuseIdentifier = @"TSTopOptionPullright";
        break;
      case SECTION_THRESHOLD:
        if ([UIStepper class]) {
            reuseIdentifier = @"TSTopOptionStepper";
        } else {
            reuseIdentifier = @"TSTopOptionNumber";
        }
        break;
      case SECTION_EMAIL:
        switch(indexPath.row) {
          case ROW_EMAIL_FORMAT:
            reuseIdentifier = @"TSTopOptionPullright";
            break;
          case ROW_EMAIL_MAX_DAYS:
          case ROW_EMAIL_MAX_EVENTS:
            reuseIdentifier = @"TSTopOptionNumber";
            break;
          default:
            assert(false);
        }
        break;
      default:
        assert(false);
    }
    UITableViewCell *tableViewCell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (!tableViewCell) {
        switch(indexPath.section) {
          case SECTION_AUTO_LOCK:
          case SECTION_SOUNDS:
            //case SECTION_JD:
          case SECTION_DISPLAY_CYCLE:
          case SECTION_DISPLAY_ORDER:
          case SECTION_MULTI_ZERO:
          case SECTION_CUSTOMIZE:
            tableViewCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier] autorelease];
            break;
          case SECTION_THRESHOLD:
            {
                if ([UIStepper class]) {
                    tableViewCell = [[[NSBundle mainBundle] loadNibNamed:@"TopOptionStepperCell" owner:self options:nil] objectAtIndex:0];
                    //printf("Loaded stepper cell from nib, got back identifier %s\n", [tableViewCell.reuseIdentifier UTF8String]);
                } else {
                    tableViewCell = [[[NSBundle mainBundle] loadNibNamed:@"TopOptionNumberCell" owner:self options:nil] objectAtIndex:0];
                    //printf("Loaded number cell from nib, got back identifier %s\n", [tableViewCell.reuseIdentifier UTF8String]);
                }
                assert(tableViewCell);
            }
            break;
          case SECTION_EMAIL:
            switch(indexPath.row) {
              case ROW_EMAIL_FORMAT:
                tableViewCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier] autorelease];
                tableViewCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
              case ROW_EMAIL_MAX_DAYS:
              case ROW_EMAIL_MAX_EVENTS:
                {
                    tableViewCell = [[[NSBundle mainBundle] loadNibNamed:@"TopOptionNumberCell" owner:self options:nil] objectAtIndex:0];
                    //printf("Loaded number cell from nib, got back identifier %s\n", [tableViewCell.reuseIdentifier UTF8String]);
                    assert(tableViewCell);
                }
                break;
              default:
                assert(false);
            }
            break;
          default:
            assert(false);
        }
        tableViewCell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    assert(tableViewCell);
    NSString *cellLabel = nil;
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    switch(indexPath.section) {
      case SECTION_AUTO_LOCK:
        switch(indexPath.row) {
          case ROW_AUTO_LOCK_PWR:
            cellLabel = @"... when Plugged In";
            tableViewCell.accessoryType = [userDefaults boolForKey:@"TSDisableAutoLockPwr"] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
            break;
          case ROW_AUTO_LOCK_BAT:
            cellLabel = @"... when on Battery";
            tableViewCell.accessoryType = [userDefaults boolForKey:@"TSDisableAutoLockBat"] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
            break;
          default:
            assert(false);
        }
        break;
      case SECTION_DISPLAY_ORDER:
        switch(indexPath.row) {
          case ROW_DISPLAY_TIME_FIRST:
            cellLabel = @"Time on top";
            tableViewCell.accessoryType = rowCheckedForOrderDefault(userDefaults, TSOrderTimeFirst) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
            break;
          case ROW_DISPLAY_DESCRIPTION_FIRST:
            cellLabel = @"Description on top";
            tableViewCell.accessoryType = rowCheckedForOrderDefault(userDefaults, TSOrderDescFirst) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
            break;
          case ROW_DISPLAY_ORDER_AUTO:
            cellLabel = @"Auto";
            tableViewCell.accessoryType = rowCheckedForOrderDefault(userDefaults, TSOrderAuto) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
            break;
          default:
            assert(false);
        }
        break;
      case SECTION_SOUNDS:
        cellLabel = @"Button Clicks Enabled";
        tableViewCell.accessoryType = buttonClick() ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        break;
      case SECTION_CUSTOMIZE:
        cellLabel = @"Custom Event Names";
        tableViewCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        break;
      //case SECTION_JD:
        //cellLabel = @"Use TT for JD";
        //tableViewCell.accessoryType = [userDefaults boolForKey:@"TSUseTTForJD"] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        //break;
      case SECTION_MULTI_ZERO:
        cellLabel = @"Allow Multiple Zeroes";
        tableViewCell.accessoryType = [TSTimeHistory allowMultipleReferenceZeroes] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        break;
      case SECTION_THRESHOLD:
        {
            UILabel *titleLabel = (UILabel *)[tableViewCell viewWithTag:TITLE_FIELD_TAG];
            titleLabel.text = @"Green Limit";
            UIStepper *stepper = (UIStepper *)[tableViewCell viewWithTag:STEPPER_FIELD_TAG];
            double value = [userDefaults doubleForKey:@"TSGreenThreshold"];
            if (stepper) {
                stepper.minimumValue = MIN_THRESH;
                stepper.maximumValue = MAX_THRESH;
                stepper.stepValue = STEP_THRESH;
                stepper.value = value;
                UILabel *valueLabel = (UILabel *)[tableViewCell viewWithTag:VALUE_FIELD_TAG];
                assert(valueLabel);
                assert([valueLabel isKindOfClass:[UILabel class]]);
                valueLabel.text = [NSString stringWithFormat:@"%.2fs", value];
            } else {
                UITextField *valueField = (UITextField *)[tableViewCell viewWithTag:VALUE_FIELD_TAG];
                assert(valueField);
                assert([valueField isKindOfClass:[UITextField class]]);
                valueField.text = [NSString stringWithFormat:@"%.2f", value];
                valueField.placeholder = @"seconds";
            }
        }
        break;
      case SECTION_DISPLAY_CYCLE:
        switch(indexPath.row) {
          case TSTimeBaseLocal12:
            cellLabel = @"Local 12-hour time";
            break;
          case TSTimeBaseLocal24:
            cellLabel = @"Local 24-hour time";
            break;
          case TSTimeBaseUTC24:
            cellLabel = @"UTC 24-hour time";
            break;
          case TSTimeBaseJDTT:
            cellLabel = @"Julian Date (TT-based)";
            break;
          case TSTimeBaseJDUTC:
            cellLabel = @"Julian Date (UTC-based)";
            break;
          case TSTimeBaseInterval:
            cellLabel = @"Interval from zero";
            break;
        }
        {
            bool *flagsPtr = classicCycleFlags;
            tableViewCell.accessoryType = flagsPtr[indexPath.row] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        }
        break;
      case SECTION_EMAIL:
        switch(indexPath.row) {
          case ROW_EMAIL_FORMAT:
            {
                NSString *emailFormat = [userDefaults stringForKey:@"TSEmailFormat"];
                bool useTSV = emailFormat && ([emailFormat compare:@"tsv"] == NSOrderedSame);
                cellLabel = @"Email format";
                tableViewCell.detailTextLabel.text = useTSV ? @"Tab separ. value" : @"Plain text";
            }
            break;
          case ROW_EMAIL_MAX_DAYS:
            {
                UILabel *titleLabel = (UILabel *)[tableViewCell viewWithTag:TITLE_FIELD_TAG];
                titleLabel.text = @"Max days to send";
                UITextField *valueField = (UITextField *)[tableViewCell viewWithTag:VALUE_FIELD_TAG];
                //assert(valueField);
                //printf("cell for maxdays has reuse %s\n", [tableViewCell.reuseIdentifier UTF8String]);
                valueField.text = [NSString stringWithFormat:@"%ld", (long)[userDefaults integerForKey:@"TSEmailMaxDays"]];
                valueField.placeholder = @"days";
            }
            break;
          case ROW_EMAIL_MAX_EVENTS:
            {
                UILabel *titleLabel = (UILabel *)[tableViewCell viewWithTag:TITLE_FIELD_TAG];
                titleLabel.text = @"Max events to send";
                UITextField *valueField = (UITextField *)[tableViewCell viewWithTag:VALUE_FIELD_TAG];
                //assert(valueField);
                //printf("cell for maxevents has reuse %s\n", [tableViewCell.reuseIdentifier UTF8String]);
                valueField.text = [NSString stringWithFormat:@"%ld", (long)[userDefaults integerForKey:@"TSEmailMaxEvents"]];
                valueField.placeholder = @"events";
            }
            break;
          default:
            assert(false);
        }
        break;
      default:
        assert(false);
    }
    tableViewCell.textLabel.text = cellLabel;
    return tableViewCell;
}

NSTimer *thresholdChangeTimer = nil;

-(void)reloadForThresholdChange {
    printf("Reloading data based on threshold change to %.2f\n", [[NSUserDefaults standardUserDefaults] doubleForKey:@"TSGreenThreshold"]);
    [TSTimeHistory reloadDefaults];
    [TSRootViewController syncStatusChangedInMainThread];
}

-(void)reloadForThresholdChange:(NSTimer *)timer {
    assert(timer == thresholdChangeTimer);
    thresholdChangeTimer = nil;
    [self reloadForThresholdChange];
}

-(void)resetThresholdChangeTimer {
    if (thresholdChangeTimer) {
        [thresholdChangeTimer invalidate];
    }
    thresholdChangeTimer = [NSTimer scheduledTimerWithTimeInterval:1. target:self selector:@selector(reloadForThresholdChange:) userInfo:nil repeats:NO];
}

static void setIntValueDefault(NSString       *keyName,
                               int            value) {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:value] forKey:keyName];
}

-(void)textFieldChanged:(id)sender
{
    UITextField *textField = (UITextField *)sender;
    NSString *placeholder = [textField placeholder];
    NSString *txt = [textField text];
    while ([txt length] >= 1 && [txt characterAtIndex:0] == ' ') {
        txt = [txt substringFromIndex:1];
    }
    int val = 0;
    if ([txt length] != 0) {
        val = atoi([txt UTF8String]);
        //[textField setText:[NSString stringWithFormat:@"%d", val]];
    }
    if ([placeholder compare:@"days"] == NSOrderedSame) {
        setIntValueDefault(@"TSEmailMaxDays", val);
    } else if ([placeholder compare:@"seconds"] == NSOrderedSame) {
        // Do nothing here (although a badge or overlay for an invalid value would be helpful)
        //  because the value might be invalid and we don't want to pepper the user with messages until he's done
        double dval = 0;
        if ([txt length] != 0) {
            dval = atof([txt UTF8String]);
        }
        printf("New threshold value is %.04f (not yet updated)\n", dval);
    } else {
        assert([placeholder compare:@"events"] == NSOrderedSame);
        setIntValueDefault(@"TSEmailMaxEvents", val);
    }
}

-(IBAction)textfieldEditingDidEnd:(id)sender {
    // Was: ->changed
    UITextField *textField = (UITextField *)sender;
    NSString *placeholder = [textField placeholder];
    //printf("textfieldEditingDidEnd %s\n", [placeholder UTF8String]);
    NSString *txt = [textField text];
    while ([txt length] >= 1 && [txt characterAtIndex:0] == ' ') {
        txt = [txt substringFromIndex:1];
    }
    if ([placeholder compare:@"seconds"] == NSOrderedSame) {
        double dval = 0;
        if ([txt length] != 0) {
            dval = atof([txt UTF8String]);
        }
        printf("New threshold value is %.04f (checking)\n", dval);
        if (dval < MIN_THRESH || dval > MAX_THRESH) {
            // Error message, do nothing
            NSString *messageString = [NSString stringWithFormat:NSLocalizedString(@"Green Limit must be between %.2f and %.2f", @"Text for out-of-limit green threshold message"),
                                                MIN_THRESH, MAX_THRESH];
            UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Green Limit Error", @"Text for out-of-limit green threshold message title")
                                                                           message:messageString
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                                       style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction *action) {}]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:dval] forKey:@"TSGreenThreshold"];
            [self reloadForThresholdChange];
        }
    }
}

-(IBAction)textfieldDidEndOnExit:(id)sender {
    //printf("textfieldDidEndOnExit\n");
    [sender resignFirstResponder];
}

-(IBAction)textfieldEditingChanged:(id)sender {
    //printf("textfieldEditingChanged\n");
    [self textFieldChanged:sender];
}

-(IBAction)stepperValueChanged:(id)sender {
    assert([sender isKindOfClass:[UIStepper class]]);
    UIStepper *stepper = (UIStepper *)sender;
    double dval = [stepper value];
    // For deterministic behavior, round to nearest hundredth
    char valString[24];
    sprintf(valString, "%.2f", dval);
    dval = atof(valString);
    //printf("...           rounded to .%04f\n", dval);
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:dval] forKey:@"TSGreenThreshold"];
    UIView *tableViewCell = [stepper superview];
    //assert([tableViewCell isKindOfClass:[UITableViewCell class]]);
    UILabel *valueLabel = (UILabel *)[tableViewCell viewWithTag:VALUE_FIELD_TAG];
    assert(valueLabel);
    valueLabel.text = [NSString stringWithFormat:@"%.2fs", dval];
    [self resetThresholdChangeTimer];
}

static BOOL toggleCheck(NSUserDefaults  *userDefaults,
                        NSString        *keyName) {
    BOOL newValue = ![userDefaults boolForKey:keyName];
    [userDefaults setObject:[NSNumber numberWithBool:newValue] forKey:keyName];
    return newValue;
}

// UITableViewDelegate methods

static bool
isLastFlagSet(NSInteger flagNumber,
              bool      *flagsPtr) {
    for (int i = 0; i < TSNumTimeBases; i++) {
        if (i != flagNumber && flagsPtr[i]) {
            return false;
        }
    }
    return true;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == SECTION_DISPLAY_CYCLE) {
        bool *flagsPtr = classicCycleFlags;
        if (flagsPtr[indexPath.row] && isLastFlagSet(indexPath.row, classicCycleFlags)) {
            return nil;  // Don't allow last flag to be unset
        }
    }
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    switch(indexPath.section) {
      case SECTION_AUTO_LOCK:  // @"Disable Auto-Lock"
        switch(indexPath.row) {
          case ROW_AUTO_LOCK_PWR:  // @"... when Plugged In";
            toggleCheck(userDefaults, @"TSDisableAutoLockPwr");
            break;
          case ROW_AUTO_LOCK_BAT:  // @"... when on Battery";
            toggleCheck(userDefaults, @"TSDisableAutoLockBat");
            break;
          default:
            assert(false);
        }
        // We rely on the repeating setDALHeartbeatFire to pick up the change
        break;
      case SECTION_SOUNDS:  // @"Sounds"
        // @"Button Clicks Enabled";
        {
            BOOL newValue = !buttonClick();
            [userDefaults setObject:[NSNumber numberWithBool:newValue] forKey:@"TSButtonClick"];
        }
        break;
      case SECTION_CUSTOMIZE:  // @"Predefined Event Names"
        // @"Custom event names";        
        {
            UIViewController *vc = [[TSCustomNameEditorViewController alloc] initWithNibName:@"CustomNameEditor" bundle:nil];
            [self.navigationController pushViewController:vc animated:true];
        }
        break;
      case SECTION_DISPLAY_CYCLE:
        {
            bool *flagsPtr = classicCycleFlags;
            flagsPtr[indexPath.row] = !flagsPtr[indexPath.row];
            if (indexPath.row == [TSTimeHistory currentTimeBase]) {
                [TSTimeHistory rotateTimeBase];
            }
            [TSTopOptionsViewController saveDefaults];
            if (indexPath.row == TSTimeBaseJDTT || indexPath.row == TSTimeBaseJDUTC) {
                [TSTopOptionsViewController checkJDUseOptionAgainstCycle:flagsPtr];
            }
        }
        break;
      //case SECTION_JD:  // @"JD"
        //{
        //    BOOL newValue = toggleCheck(userDefaults, @"TSUseTTForJD");
        //    [TSTimeHistory reloadDefaults];
        //    [TSModeOptionsViewController checkJDCyclesForNewUseOption:newValue];  // for view cycle
        //}
        break;
      case SECTION_DISPLAY_ORDER:
        switch(indexPath.row) {
          case ROW_DISPLAY_TIME_FIRST:
            [userDefaults setObject:@"timeFirst" forKey:@"TSDisplayOrder"];
            break;
          case ROW_DISPLAY_DESCRIPTION_FIRST:
            [userDefaults setObject:@"descFirst" forKey:@"TSDisplayOrder"];
            break;
          case ROW_DISPLAY_ORDER_AUTO:
            [userDefaults setObject:@"auto" forKey:@"TSDisplayOrder"];
            break;
          default:
            assert(false);
            break;
        }
        [TSRootViewController reloadDefaults];
        break;
      case SECTION_MULTI_ZERO:
        {
            bool newValue = ![TSTimeHistory allowMultipleReferenceZeroes];
            [TSTimeHistory setAllowMultipleReferenceZeroes:newValue];
        }
        break;
      case SECTION_THRESHOLD:
        break;
      case SECTION_EMAIL:  // @"Email"
        switch(indexPath.row) {
          case ROW_EMAIL_FORMAT:
            {
                UIViewController *vc = [[TSEmailOptionsViewController alloc] initWithTopOptionsController:self];
                [self.navigationController pushViewController:vc animated:true];
            }
            break;
          case ROW_EMAIL_MAX_DAYS:
          case ROW_EMAIL_MAX_EVENTS:
            break;
          default:
            assert(false);
        }
        break;
      default:
        assert(false);
    }
    [tableView reloadData];
}

static UITableView *theTableView;

-(void)viewDidLoad {
    theTableView = (UITableView *)self.view;
    self.navigationItem.title = @"Options";
}

-(void)reloadTableData {
    if (theTableView) {
        [theTableView reloadData];
    }
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
 // // Return YES for supported orientations.
 //     return YES;
 // }

+(void)checkJDUseOptionAgainstCycle:(bool [])flagsPtr {
    if (flagsPtr[TSTimeBaseJDTT] != flagsPtr[TSTimeBaseJDUTC]) {
        // We've indicated a preference
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        BOOL currentValueBOOL = [userDefaults boolForKey:@"TSUseTTForJD"];
        bool currentValue = (currentValueBOOL != NO);
        if (currentValue != flagsPtr[TSTimeBaseJDTT]) {
            [userDefaults setObject:[NSNumber numberWithBool:!currentValueBOOL] forKey:@"TSUseTTForJD"];
            [TSTimeHistory reloadDefaults];
        }
    }
}

@end
