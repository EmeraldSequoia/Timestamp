//
//  TSModeOptionsViewController.m
//
//  Created by Steve Pucci 06 Feb 2012
//  Copyright Emerald Sequoia LLC 2012. All rights reserved.
//

#import "TSModeOptionsViewController.h"
#import "TSTopOptionsViewController.h"
#import "TSCustomNameEditorViewController.h"
#import "TSRootViewController.h"
#import "TSNumStopwatchesViewController.h"

#define SECTION_MODE          0
#define SECTION_CUSTOM_NAMES  1
#define SECTION_DISPLAY_CYCLE 2   
#define NUM_SECTIONS 3

#define ROW_NUM_STOPWATCHES   0

bool classicCycleFlags[TSNumTimeBases];
bool stopwatchCycleFlags[TSNumTimeBases];
bool projectCycleFlags[TSNumTimeBases];

int numberOfStopwatches = 1;

static TSModeOptionsViewController *theController = nil;

@implementation TSModeOptionsViewController

static TSMasterModeType masterMode = TSMasterModeClassic;


+(TSMasterModeType)masterMode {
    return masterMode;
}

+(void)saveDefaults {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *txt = nil;
    switch(masterMode) {
      case TSMasterModeClassic:
        txt = @"classic";
        break;
      case TSMasterModeStopwatch:
        txt = @"stopwatch";
        break;
      case TSMasterModeProject:
        txt = @"project";
        break;
      default:
        assert(false);
    }
    [userDefaults setObject:txt forKey:@"TSMasterMode"];

    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:TSNumTimeBases];
    for (int i = 0; i < TSNumTimeBases; i++) {
        [arr addObject:[NSNumber numberWithBool:classicCycleFlags[i]]];
    }
    [userDefaults setObject:arr forKey:@"TSClassicDisplayCycleFlags"];
    arr = [NSMutableArray arrayWithCapacity:TSNumTimeBases];
    for (int i = 0; i < TSNumTimeBases; i++) {
        [arr addObject:[NSNumber numberWithBool:stopwatchCycleFlags[i]]];
    }
    [userDefaults setObject:arr forKey:@"TSStopwatchDisplayCycleFlags"];
    arr = [NSMutableArray arrayWithCapacity:TSNumTimeBases];
    for (int i = 0; i < TSNumTimeBases; i++) {
        [arr addObject:[NSNumber numberWithBool:projectCycleFlags[i]]];
    }
    [userDefaults setObject:arr forKey:@"TSProjectDisplayCycleFlags"];
    [userDefaults setObject:[NSNumber numberWithInt:numberOfStopwatches] forKey:@"TSNumberOfStopwatches"];
}

+(void)setNumberOfStopwatches:(int)num {
    numberOfStopwatches = num;
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:numberOfStopwatches] forKey:@"TSNumberOfStopwatches"];
    [theController.tableView reloadData];
    [TSRootViewController makeNewButtonsAndSetColors];
}

+(int)numberOfStopwatches {
    return numberOfStopwatches;
}

+(int)maxNumStopwatchesForDevice {
    if (isIpad()) {
        return 4;
    } else {
        return 2;
    }
}

+(void)loadDefaults {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *str = [userDefaults stringForKey:@"TSMasterMode"];
    if (!str) {
        masterMode = TSMasterModeClassic;
    } else if ([str compare:@"stopwatch"] == NSOrderedSame) {
        masterMode = TSMasterModeStopwatch;
    } else if ([str compare:@"project"] == NSOrderedSame) {
        masterMode = TSMasterModeProject;
    } else {
        assert([str compare:@"classic"] == NSOrderedSame);
        masterMode = TSMasterModeClassic;
    }
    masterMode = TSMasterModeClassic;  // Override any prior saved setting
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
        for (NSNumber *obj in arr) {
            if (i < TSNumTimeBases) {
                classicCycleFlags[i++] = [obj boolValue];
            }
        }
    }
    // set stopwatchCycleFlags
    arr = [userDefaults arrayForKey:@"TSStopwatchDisplayCycleFlags"];
    if (!arr) {
        stopwatchCycleFlags[TSTimeBaseLocal12] = true;
        stopwatchCycleFlags[TSTimeBaseLocal24] = false;
        stopwatchCycleFlags[TSTimeBaseUTC24] = false;
        stopwatchCycleFlags[TSTimeBaseJDTT] = false;
        stopwatchCycleFlags[TSTimeBaseJDUTC] = false;
        stopwatchCycleFlags[TSTimeBaseInterval] = true;
    } else {
        assert([arr count] >= TSNumTimeBases);
        int i = 0;
        for (NSNumber *obj in arr) {
            if (i < TSNumTimeBases) {
                stopwatchCycleFlags[i++] = [obj boolValue];
            }
        }
    }
    // set projectCycleFlags
    arr = [userDefaults arrayForKey:@"TSProjectDisplayCycleFlags"];
    if (!arr) {
        projectCycleFlags[TSTimeBaseLocal12] = true;
        projectCycleFlags[TSTimeBaseLocal24] = false;
        projectCycleFlags[TSTimeBaseUTC24] = false;
        projectCycleFlags[TSTimeBaseJDTT] = false;
        projectCycleFlags[TSTimeBaseJDUTC] = false;
        projectCycleFlags[TSTimeBaseInterval] = true;
    } else {
        assert([arr count] >= TSNumTimeBases);
        int i = 0;
        for (NSNumber *obj in arr) {
            if (i < TSNumTimeBases) {
                projectCycleFlags[i++] = [obj boolValue];
            }
        }
    }
    numberOfStopwatches = [userDefaults integerForKey:@"TSNumberOfStopwatches"];
    if (numberOfStopwatches == 0) {  // Must be first time
        numberOfStopwatches = 1;
    } else if (numberOfStopwatches > [self maxNumStopwatchesForDevice]) {
        numberOfStopwatches = [self maxNumStopwatchesForDevice];  // should never happen unless somebody loads settings from a different device
    }
}

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
    theController = self;
    UINavigationItem *navItem = self.navigationItem;
    navItem.title = @"Mode Options";
    navItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Mode" style:UIBarButtonItemStyleBordered target:nil action:nil] autorelease];
    [navItem setRightBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(popToTop)] autorelease]];
}

-(void)viewDidUnload {
    theController = nil;
}

// UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return NUM_SECTIONS;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch(section) {
      case SECTION_MODE:
        switch(masterMode) {
          case TSMasterModeClassic:
            return @"In classic mode there is either a single unnamed button or a group of prenamed buttons which initialize events with their names.";
          case TSMasterModeStopwatch:
            return @"In stopwatch mode, there are one or more stopwatches, which create special start and stop events.";
          case TSMasterModeProject:
            return @"In project mode, there are one or more named projects that act like stopwatches, but starting one project stops the currently running one.";
          default:
            assert(false);
            return nil;
        }
      case SECTION_CUSTOM_NAMES:
        return nil;
      case SECTION_DISPLAY_CYCLE:
        return @"Tap on any time in Timestamp to cycle among the selected displays above; this set changes based on the master mode above";
      default:
        assert(false);
        return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch(section) {
      case SECTION_MODE:
        return @"Master mode";
      case SECTION_CUSTOM_NAMES: 
        switch(masterMode) {
          case TSMasterModeClassic:
            return @"Classic-mode event names";
          case TSMasterModeStopwatch:
            return @"Stopwatch options";
          case TSMasterModeProject:
            return @"Project names";
          default:
            assert(false);
            return nil;
        }
     case SECTION_DISPLAY_CYCLE:
        switch(masterMode) {
          case TSMasterModeClassic:
            return @"Classic-mode display cycle";
          case TSMasterModeStopwatch:
            return @"Stopwatch display cycle";
          case TSMasterModeProject:
            return @"Project display cycle";
          default:
            assert(false);
            return nil;
        }
      default:
        assert(false);
        return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch(section) {
      case SECTION_MODE:
        return 3;
      case SECTION_CUSTOM_NAMES:
        return 1;
      case SECTION_DISPLAY_CYCLE:
        return TSNumTimeBases;
      default:
        assert(false);
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    bool isNumPullright = (masterMode == TSMasterModeStopwatch && indexPath.section == SECTION_CUSTOM_NAMES && indexPath.row == ROW_NUM_STOPWATCHES);
    NSString *reuseIdentifier = isNumPullright ? @"TSModeOptionsNumPullright" : @"TSModeOptionsCell";
    UITableViewCell *tableViewCell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (!tableViewCell) {
        if (isNumPullright) {
            tableViewCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier];
            tableViewCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            tableViewCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
        }
        [tableViewCell autorelease];
        tableViewCell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    assert(tableViewCell);
    NSString *txt = nil;
    switch(indexPath.section) {
      case SECTION_MODE:
        tableViewCell.accessoryType = (masterMode == indexPath.row) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        switch(indexPath.row) {
          case TSMasterModeClassic:
            txt = @"Classic";
            break;
          case TSMasterModeStopwatch:
            txt = @"Stopwatch";
            break;
          case TSMasterModeProject:
            txt = @"Project";
            break;
          default:
            assert(false);
            return nil;
        }
        break;
      case SECTION_CUSTOM_NAMES:
        switch(masterMode) {
          case TSMasterModeClassic:
            txt = @"Custom event names";
            tableViewCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
          case TSMasterModeStopwatch:
            assert(indexPath.row == ROW_NUM_STOPWATCHES);
            txt = @"Number of stopwatches";
            tableViewCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            tableViewCell.detailTextLabel.text = [NSString stringWithFormat:@"%d", numberOfStopwatches];
            break;
          case TSMasterModeProject:
            txt = @"Project names";
            tableViewCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
          default:
            assert(false);
            return nil;
        }
        break;
      case SECTION_DISPLAY_CYCLE:
        switch(indexPath.row) {
          case TSTimeBaseLocal12:
            txt = @"Local 12-hour time";
            break;
          case TSTimeBaseLocal24:
            txt = @"Local 24-hour time";
            break;
          case TSTimeBaseUTC24:
            txt = @"UTC 24-hour time";
            break;
          case TSTimeBaseJDTT:
            txt = @"Julian Date (TT-based)";
            break;
          case TSTimeBaseJDUTC:
            txt = @"Julian Date (UTC-based)";
            break;
          case TSTimeBaseInterval:
            txt = @"Interval from last zero";
            break;
        }
        {
            bool *flagsPtr = classicCycleFlags;
            switch(masterMode) {
              case TSMasterModeClassic:
                flagsPtr = classicCycleFlags;  
                break;
              case TSMasterModeStopwatch:
                flagsPtr = stopwatchCycleFlags;  
                break;
              case TSMasterModeProject:
                flagsPtr = projectCycleFlags;  
                break;
              default:
                assert(false);
                return nil;
            }
            tableViewCell.accessoryType = flagsPtr[indexPath.row] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        }
        break;
      default:
        assert(false);
        break;
    }
    tableViewCell.textLabel.text = txt;
    return tableViewCell;
}

// UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *stringValue = nil;
    switch(indexPath.section) {
      case SECTION_MODE:
        switch(indexPath.row) {
          case TSMasterModeClassic:
            stringValue = @"classic";
            break;
          case TSMasterModeStopwatch:
            stringValue = @"stopwatch";
            break;
          case TSMasterModeProject:
            stringValue = @"project";
            break;
          default:
            assert(false);
            return;
        }
        masterMode = indexPath.row;
        [userDefaults setObject:stringValue forKey:@"TSMasterMode"];
        [topOptionsController reloadTableData];
        [TSRootViewController makeNewButtonsAndSetColors];
        break;
      case SECTION_CUSTOM_NAMES:
        {
            if (masterMode == TSMasterModeStopwatch) {
                assert(indexPath.row == ROW_NUM_STOPWATCHES);
                UIViewController *vc = [[TSNumStopwatchesViewController alloc] initWithNibName:@"NumStopwatches" bundle:nil];
                [self.navigationController pushViewController:vc animated:true];
            } else {
                UIViewController *vc = [[TSCustomNameEditorViewController alloc] initWithNibName:@"CustomNameEditor" bundle:nil];
                [self.navigationController pushViewController:vc animated:true];
            }
        }
        return;
      case SECTION_DISPLAY_CYCLE:
        {
            bool *flagsPtr = classicCycleFlags;
            switch(masterMode) {
              case TSMasterModeClassic:
                flagsPtr = classicCycleFlags;  
                break;
              case TSMasterModeStopwatch:
                flagsPtr = stopwatchCycleFlags;  
                break;
              case TSMasterModeProject:
                flagsPtr = projectCycleFlags;  
                break;
              default:
                assert(false);
                return;
            }
            flagsPtr[indexPath.row] = !flagsPtr[indexPath.row];
            [TSModeOptionsViewController saveDefaults];
            if (indexPath.row == TSTimeBaseJDTT || indexPath.row == TSTimeBaseJDUTC) {
                [TSTopOptionsViewController checkJDUseOptionAgainstCycle:flagsPtr];
            }
        }
        break;
      default:
        assert(false);
        break;
    }
    [tableView reloadData];
}

static bool
checkJDCyclesForNewUseOption(bool newUseTT,
                             bool flagsPtr[]) {
    if (flagsPtr[TSTimeBaseJDTT] != flagsPtr[TSTimeBaseJDUTC]) {
        // We've previously indicated a preference
        if (newUseTT != flagsPtr[TSTimeBaseJDTT]) {  // and it's different than the new one
            flagsPtr[TSTimeBaseJDTT] = newUseTT;    // swap to match flag
            flagsPtr[TSTimeBaseJDUTC] = !newUseTT;
            return true;
        }
    }
    return false;
}

+(void)checkJDCyclesForNewUseOption:(BOOL)newValue {
    bool newUseTT = (newValue != NO);
    bool didSomethingForClassic   = checkJDCyclesForNewUseOption(newUseTT, classicCycleFlags);
    bool didSomethingForStopwatch = checkJDCyclesForNewUseOption(newValue, stopwatchCycleFlags);
    bool didSomethingForProject   = checkJDCyclesForNewUseOption(newValue, projectCycleFlags);
    // Don't try to eliminate these variables or C will short-circuit the OR
    if (didSomethingForClassic || didSomethingForStopwatch || didSomethingForProject) {
        [self saveDefaults];
    }
}

@end
