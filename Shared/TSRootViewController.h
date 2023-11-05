//
//  TSRootViewController.h
//
//  Created by Steve Pucci on 4/30/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "TSTimeHistory.h"


extern UIColor *getColorForConfidenceLevel(TSConfidenceLevel confidenceLevel);
#ifdef __cplusplus
extern "C" {
#endif
extern bool buttonClick(void);
extern bool isIpad(void);
extern void ESGiveButtonAGradient(UIButton *button,
                                  bool     forHighlight,
                                  bool     initialization);
#ifdef __cplusplus
}
#endif


@class ESUniformRowView;

typedef enum {
    TSOrderTimeFirst,
    TSOrderDescFirst,
    TSOrderAuto
} TSDisplayOrder;

@interface TSRootViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate, UIActionSheetDelegate> {
@private
    UITableView     *theTableView;
    ESUniformRowView *stampButtonRow;
    ESUniformRowView *intervalTimeLabelRow;
    UILabel         *currentAbsoluteTimeLabel;
    UILabel         *currentDateLabel;
    UILabel         *currentErrorLabel;
    UIToolbar       *bottomToolbar;
    UIImageView     *logoView;
    UITableViewCell *loadedTVCellWithTwoRowsWithZero;
    UITableViewCell *loadedTVCellWithOneRowWithZero;
    UITableViewCell *loadedTVCellWithTwoRowsNoZero;
    UITableViewCell *loadedTVCellWithOneRowNoZero;
}

@property (nonatomic, retain) IBOutlet UITableView *theTableView;
@property (nonatomic, retain) IBOutlet UILabel *currentDateLabel;
@property (nonatomic, retain) IBOutlet UILabel *currentAbsoluteTimeLabel;
@property (nonatomic, retain) IBOutlet UILabel *currentErrorLabel;
@property (nonatomic, retain) IBOutlet UIImageView *logoView;
@property (nonatomic, assign) IBOutlet UITableViewCell *loadedTVCellWithTwoRowsWithZero;
@property (nonatomic, assign) IBOutlet UITableViewCell *loadedTVCellWithOneRowWithZero;
@property (nonatomic, assign) IBOutlet UITableViewCell *loadedTVCellWithTwoRowsNoZero;
@property (nonatomic, assign) IBOutlet UITableViewCell *loadedTVCellWithOneRowNoZero;
@property (nonatomic, assign) IBOutlet ESUniformRowView *stampButtonRow;
@property (nonatomic, assign) IBOutlet ESUniformRowView *intervalTimeLabelRow;
@property (nonatomic, assign) IBOutlet UIToolbar *bottomToolbar;
@property(nonatomic, readonly) BOOL prefersHomeIndicatorAutoHidden;


- (IBAction)buttonDown:(id)sender;
- (IBAction)rotateTimeBase:(id)sender;
- (IBAction)resync:(id)sender;

- (IBAction)cellZero:(id)sender;

+ (void)makeNewButtonsAndSetColors;

- (IBAction)startHelp;
- (IBAction)startOptions;
- (IBAction)startEdit;

+ (void)syncStatusChangedInMainThread;
+ (void)rotateTimeBaseCallback;
+ (void)reloadDefaults;

@end
