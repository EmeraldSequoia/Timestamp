//
//  TSCustomNameEditorViewController.h
//
//  Created by Steve Pucci 11 Feb 2012
//  Copyright Emerald Sequoia LLC 2012. All rights reserved.
//

#ifndef _TSCUSTOMNAMEEDITORVIEWCONTROLLER_H_
#define _TSCUSTOMNAMEEDITORVIEWCONTROLLER_H_

#import "TSTopOptionsViewController.h"  // For TSMasterModeType

@class TSTopOptionsViewController;

/*! View controller for the editor of custom names */
@interface TSCustomNameEditorViewController : UIViewController<UITableViewDelegate, UITableViewDataSource> {
    UIBarButtonItem         *addButtonItem;
    UIBarButtonItem         *editButtonItem;
    UIToolbar               *bottomToolbar;
    UITableView             *tableView;
    UILabel                 *hintLabel;
}

@property (nonatomic, assign) IBOutlet UIBarButtonItem *addButtonItem;
@property (nonatomic, assign) IBOutlet UIBarButtonItem *editButtonItem;
@property (nonatomic, assign) IBOutlet UITableView     *tableView;
@property (nonatomic, assign) IBOutlet UIToolbar       *bottomToolbar;
@property (nonatomic, assign) IBOutlet UILabel         *hintLabel;

- (IBAction)addNameAction:(id)sender;
- (IBAction)editAction:(id)sender;

+ (NSArray *)customNamesForMode:(TSMasterModeType)masterMode;
- (NSString *)currentTextForRow:(NSInteger)rowNumber;
- (NSInteger)rowNumberBeingEdited;
- (bool)addingNotEditing;
- (void)textFieldChangedTo:(NSString *)newValue;
+ (void)loadDefaults;

@end

#endif  // _TSCUSTOMNAMEEDITORVIEWCONTROLLER_H_
