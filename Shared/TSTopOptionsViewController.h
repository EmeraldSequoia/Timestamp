//
//  TSTopOptionsViewController.h
//
//  Created by Steve Pucci 05 Feb 2012
//  Copyright Emerald Sequoia LLC 2012. All rights reserved.
//

#ifndef _TSTOPOPTIONSVIEWCONTROLLER_H_
#define _TSTOPOPTIONSVIEWCONTROLLER_H_

#import "TSTimeHistory.h"

/*! View controller for the top-level options view */
@interface TSTopOptionsViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource> {
}

typedef enum {
    TSMasterModeClassic,
    TSMasterModeStopwatch,
    TSMasterModeProject
} TSMasterModeType;
#define TSNumMasterModes 3

extern bool classicCycleFlags[TSNumTimeBases];

-(IBAction)textfieldDidEndOnExit:(id)sender;
-(IBAction)textfieldEditingDidEnd:(id)sender;
-(IBAction)textfieldEditingChanged:(id)sender;


-(void)reloadTableData;

+(void)checkJDUseOptionAgainstCycle:(bool [])flagsPtr;

+(TSMasterModeType)masterMode;
+(void)loadDefaults;

@end

#endif  // _TSTOPOPTIONSVIEWCONTROLLER_H_
