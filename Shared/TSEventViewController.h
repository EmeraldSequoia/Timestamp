//
//  TSEventViewController.h
//  timestamp
//
//  Created by Steve Pucci on 5/3/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MFMailComposeViewController.h>

@class TSTimeHistory;

@interface TSEventViewController : UIViewController<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, MFMailComposeViewControllerDelegate/*, UIPickerViewDataSource, UIPickerViewDelegate*/> {
    UILabel       *eventDateLabel;
    UILabel       *eventTimeLabel;
    UIButton      *zeroReferenceButton;
    //UIPickerView  *timeBasePicker;
    UITableView   *theTableView;
    UIView        *scrollContentView;
    TSTimeHistory *event;
    int           slot;
}

@property (nonatomic, retain) IBOutlet UITableView *theTableView;
@property (nonatomic, retain) IBOutlet UIView *scrollContentView;
@property (nonatomic, retain) IBOutlet UILabel *eventDateLabel;
@property (nonatomic, retain) IBOutlet UILabel *eventTimeLabel;
@property (nonatomic, retain) IBOutlet UIButton *zeroReferenceButton;
//@property (nonatomic, retain) IBOutlet UIPickerView *timeBasePicker;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil event:(TSTimeHistory *)anEvent slot:(int)slot;

+ (void)syncStatusChangedInMainThread;

- (IBAction)emailEventAction:(id)sender;
- (IBAction)emailAllEventsAction:(id)sender;

- (IBAction)rotateTimeBase:(id)sender;
- (IBAction)toggleReferenceZero:(id)sender;

@end
