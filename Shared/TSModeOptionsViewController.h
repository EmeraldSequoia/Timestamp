//
//  TSModeOptionsViewController.h
//
//  Created by Steve Pucci 06 Feb 2012
//  Copyright Emerald Sequoia LLC 2012. All rights reserved.
//

#ifndef _TSMODEOPTIONSVIEWCONTROLLER_H_
#define _TSMODEOPTIONSVIEWCONTROLLER_H_

typedef enum {
    TSMasterModeClassic,
    TSMasterModeStopwatch,
    TSMasterModeProject
} TSMasterModeType;
#define TSNumMasterModes 3

#import "TSTimeHistory.h"

extern bool classicCycleFlags[TSNumTimeBases];
extern bool stopwatchCycleFlags[TSNumTimeBases];
extern bool projectCycleFlags[TSNumTimeBases];

extern int numberOfStopwatches;

@class TSTopOptionsViewController;

/*! View controller for setting the mode options */
@interface TSModeOptionsViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource> {
    TSTopOptionsViewController *topOptionsController;
}

-(id)initWithTopOptionsController:(TSTopOptionsViewController *)controller;

+(void)setNumberOfStopwatches:(int)num;
+(int)numberOfStopwatches;
+(int)maxNumStopwatchesForDevice;

+(TSMasterModeType)masterMode;
+(void)loadDefaults;
+(void)saveDefaults;
+(void)checkJDCyclesForNewUseOption:(BOOL)newValue;
@end

#endif  // _TSMODEOPTIONSVIEWCONTROLLER_H_
