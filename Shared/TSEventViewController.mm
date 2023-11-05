//
//  TSEventViewController.m
//  timestamp
//
//  Created by Steve Pucci on 5/3/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "TSEventViewController.h"
#import "TSRootViewController.h"
#import "TSSharedAppDelegate.h"
#import "TSTimeHistory.h"
#import "ECErrorReporter.h"

#include "ESUtil.hpp"
#include "ESTime.hpp"

enum EmailUseTSVorCSV {
    EmailUseNeitherTSVNorCSV,
    EmailUseTSV,
    EmailUseCSV
};

@interface TSEventViewController (TSEventViewControllerPrivate)
- (void)registerForKeyboardNotifications;
- (void)unregisterForKeyboardNotifications;
@end

static bool keyboardIsShown = false;

@implementation TSEventViewController

@synthesize theTableView, scrollContentView, eventDateLabel, eventTimeLabel, zeroReferenceButton;

 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil event:(TSTimeHistory *)anEvent slot:(int)aSlot {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
	event = [anEvent retain];
	slot = aSlot;
    }
    return self;
}


#if 0 // No way to easily cram in a picker on the iPhone detail view
//  Picker View --------------------------------
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    assert(component == 0);
    return TSNumTimeBases;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    assert(row >= 0 && row < TSNumTimeBases);
    return [TSTimeHistory userStringFromTimeBase:((TSTimeBase)row)];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    [TSTimeHistory setTimeBase:((TSTimeBase)row)];
}
#endif

//  Table View --------------------------------
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    assert(tableView == theTableView);
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    assert(tableView == theTableView);
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    assert(tableView == theTableView);
    if (section == 0) {
	return @" ";
    } else {
	return nil;
    }
}

#define EDIT_HEIGHT 30

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
	bool biggerSpacingRequired = [UIDevice instancesRespondToSelector:@selector(userInterfaceIdiom)];  // Changed in 3.2
	return biggerSpacingRequired ? 80 : 70;
	return 80;
    } else {
	return 5;
    }
}

#if 0
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!isIpad() && indexPath.section == 0 && indexPath.row == 0) {
	return 80;
    }
    return tableView.rowHeight;
}
#endif

static NSString *accuracyDescription(float timeError) {
    NSString *format =
	[TSTimeHistory currentTimeBase] == TSTimeBaseInterval
	? (timeError > 1E7)
	   ? isIpad()
	     ? NSLocalizedString(@"Accuracy (including 0 event): Unknown", @"Accuracy value including zero event when unsynchronized, displayed on iPad")
	     : NSLocalizedString(@"Accur (incl 0 event): Unknown", @"Accuracy value including zero event when unsynchronized")
	   : isIpad()
	     ? NSLocalizedString(@"Accuracy (including 0 event): ±%.2fs", @"Format for accuracy value including zero event, displayed on iPad")
	     : NSLocalizedString(@"Accur (incl 0 event): ±%.2fs", @"Format for accuracy value including zero event")
	: (timeError > 1E7)
	   ? NSLocalizedString(@"Accuracy: Unknown", "Accuracy value not including zero event when unsynchronized")
           : NSLocalizedString(@"Accuracy: ±%.2fs", @"Format for accuracy value not including zero event");
    return [NSString stringWithFormat:format, timeError];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    //printf("cellForRowAtIndexPath\n");
    assert(tableView == theTableView);
    assert(indexPath.row == 0);
    UITableViewCell *tableViewCell;
    if (indexPath.section == 0) {
	tableViewCell = [tableView dequeueReusableCellWithIdentifier:@"AccCell"];
	if (!tableViewCell) {
	    tableViewCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"AccCell"];
	}
	assert(tableViewCell);
	assert(event);
	tableViewCell.textLabel.text = accuracyDescription(event.timeError);
	TSConfidenceLevel confidenceLevel = event.confidenceLevel;
	if (confidenceLevel == TSConfidenceLevelGreen) {
	    tableViewCell.imageView.image = [UIImage imageNamed:@"GreenLED.png"];
	} else {
	    tableViewCell.imageView.image = [UIImage imageNamed:@"YellowLED.png"];
	}
    } else {
	assert(indexPath.section == 1);
	tableViewCell = [tableView dequeueReusableCellWithIdentifier:@"DescCell"];
	UITextField *textField;
#define TEXT_TAG 1
	if (!tableViewCell) {
	    tableViewCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"DescCell"];
	    textField = [[[UITextField alloc] initWithFrame:CGRectMake(10, 10, 300, EDIT_HEIGHT)] autorelease];
	    textField.tag = TEXT_TAG;
	    textField.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
	    textField.returnKeyType = UIReturnKeyDone;
	    textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;  // None?
	    textField.autocorrectionType = UITextAutocorrectionTypeNo;
	    textField.placeholder = NSLocalizedString(@"Event description", "Placeholder text in text field when description is empty");
	    [tableViewCell.contentView addSubview:textField];
	} else {
	    textField = (UITextField *)[tableViewCell.contentView viewWithTag:TEXT_TAG];
	}
	assert(tableViewCell);
	NSString *descriptionText = event.description;
	if (!descriptionText || [descriptionText length] == 0 || ([descriptionText compare:@" "] == NSOrderedSame)) {
	    descriptionText = nil;
	}
	textField.text = descriptionText;
	textField.delegate = self;
	[textField addTarget:self action:@selector(descriptionChanged:) forControlEvents:UIControlEventEditingChanged];
    }
    tableViewCell.selectionStyle = UITableViewCellSelectionStyleNone;
    return tableViewCell;
}

static TSEventViewController *theController = nil;

- (void)loadHeaderLabels {
    assert(eventTimeLabel);
    assert(eventDateLabel);
    eventTimeLabel.text = descriptionForTimeOnly(event.time, event.liveLeapSecondCorrection, event.accumulatedTimeReference, event.accumulatedTimeReferenceLiveLeap);
    eventDateLabel.text = descriptionForEventDetailHeader(event.time, event.liveLeapSecondCorrection, event.accumulatedTimeReference, event.accumulatedTimeReferenceLiveLeap);
    bool isReferenceZero = [TSTimeHistory eventIsReferenceZero:event];
    UIImage *buttonImage = isReferenceZero ? [UIImage imageNamed:@"RefZeroOn.png"] : [UIImage imageNamed:@"RefZeroOff.png"];
    [zeroReferenceButton setImage:buttonImage forState:UIControlStateNormal];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
//    assert(theTableView);
    assert(event);

    UIView *bgView = [[UIView alloc] init];
    // [bgView setBackgroundColor:[UIColor secondarySystemBackgroundColor]];
    [(id)theTableView setBackgroundView:bgView];
    if (!isIpad()) {
        [self registerForKeyboardNotifications];
        UIScrollView *scrollView = (UIScrollView *)self.view;
        assert(scrollView);

        CGFloat contentWidth = scrollView.frame.size.width;
        CGFloat contentHeight = scrollView.frame.size.height;
        if (contentHeight < 416) {
            contentHeight = 416;
        }

        scrollView.contentSize = CGSizeMake(contentWidth, contentHeight);
    }

    [self loadHeaderLabels];
    theController = self;
    //printf("event viewDidLoad\n");
}

- (IBAction)descriptionChanged:(id)sender {
    NSString *description = [(UITextField *)sender text];
    //printf("Description changed to '%s'\n", [description UTF8String]);
    if (slot == 0) {
	[TSTimeHistory setCurrentDescription:description];
    } else if (slot > 0) {
	//printf("Setting past description for offset %d...\n", slot-1);
	[TSTimeHistory setPastDescriptionAtOffsetFromPresent:slot-1 description:description];
    } else {
        assert(false);
	//[TSTimeHistory setFutureDescriptionAtOffsetFromPresent:-1-slot description:description];                
    }
}

- (IBAction)rotateTimeBase:(id)sender {
    [TSTimeHistory rotateTimeBase];
}

- (void)reloadData {
    [self loadHeaderLabels];
// The problem with the following two approaches is the description field gets reset even if it's not being reloaded
//    [theTableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];  // reload accuracy field in case it came in
//    [theTableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];  // reload accuracy field in case it came in    
    UITableViewCell *tableViewCell = [theTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    assert(tableViewCell);
    assert(event);
    tableViewCell.textLabel.text = accuracyDescription(event.timeError);
    TSConfidenceLevel confidenceLevel = event.confidenceLevel;
    if (confidenceLevel == TSConfidenceLevelGreen) {
	tableViewCell.imageView.image = [UIImage imageNamed:@"GreenLED.png"];
    } else {
	tableViewCell.imageView.image = [UIImage imageNamed:@"YellowLED.png"];
    }
}

- (IBAction)toggleReferenceZero:(id)sender {
    [TSTimeHistory toggleReferenceZeroForEvent:event];
    [self reloadData];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    // the user pressed the "Done" button, so dismiss the keyboard
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    //[textField becomeFirstResponder];
    //printf("did it\n");
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    //printf("textFieldDidEndEditing\n");
    //[self descriptionChanged:nil];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)syncStatusChangedInMainThread {
    assert([NSThread isMainThread]);
    [self reloadData];
}

+ (void)syncStatusChangedInMainThread {
    if (theController) {
	[theController syncStatusChangedInMainThread];
    }
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return  (1 << UIInterfaceOrientationPortrait) | (1 << UIInterfaceOrientationLandscapeLeft) |
             (1 << UIInterfaceOrientationLandscapeRight) | (1 << UIInterfaceOrientationPortraitUpsideDown);
}

- (void)viewWillTransitionToSize:(CGSize)size 
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    printf("viewWillTransitionToSize %g %g\n", size.width, size.height);
    // Figure out effective orientation here.  Or somewhere else.
    //     [TSSharedAppDelegate setNewOrientation:self.interfaceOrientation];
    // Then possibly call panViewToRevealTextField:
    // if (!isIpad() && UIInterfaceOrientationIsLandscape(self.interfaceOrientation) && keyboardIsShown) {
    //     [self panViewToRevealTextField];
    // }

}

- (void)panViewToRevealTextField {
    if (!isIpad()) {
        UIScrollView *scrollView = (UIScrollView *)self.view;
        assert(scrollView);
        assert([scrollView isKindOfClass:[UIScrollView class]]);
        //printf("didBeginEditing, view size is %.1f, %.1f\n", scrollView.frame.size.width, scrollView.frame.size.height);
        if (scrollView.frame.size.height < 300) {
            //printf("animating up\n");
            [scrollView setContentOffset:CGPointMake(0, 80) animated:YES];
        }
    }
}

+ (NSString *)eventDescriptionCore:(TSTimeHistory *)anEvent useTSVorCSV:(EmailUseTSVorCSV)useTSVorCSV useTTForJD:(bool)useTTForJD printDateToo:(bool)printDateToo {
    NSString *description = anEvent.description;
    NSTimeInterval timeInterval = anEvent.time;
    if (useTSVorCSV == EmailUseCSV || useTSVorCSV == EmailUseTSV) {
        char separator = useTSVorCSV == EmailUseTSV ? '\t' : ',';
	NSString *dateTimeString = [NSString stringWithFormat:@"%@%c%@%c%@%c%@",
                                             descriptionForTimeAndDateForExcel(timeInterval, anEvent.liveLeapSecondCorrection,
                                                                               anEvent.accumulatedTimeReference, anEvent.accumulatedTimeReferenceLiveLeap, TSTimeBaseLocal24),
                                             separator,
					     descriptionForTimeAndDateForExcel(timeInterval, anEvent.liveLeapSecondCorrection,
                                                                               anEvent.accumulatedTimeReference, anEvent.accumulatedTimeReferenceLiveLeap, TSTimeBaseUTC24),
                                             separator,
					     descriptionForTimeAndDateForExcel(timeInterval, anEvent.liveLeapSecondCorrection,
                                                                               anEvent.accumulatedTimeReference, anEvent.accumulatedTimeReferenceLiveLeap, useTTForJD ? TSTimeBaseJDTT : TSTimeBaseJDUTC),
                                             separator,
					     descriptionForTimeAndDateForExcel(timeInterval, anEvent.liveLeapSecondCorrection,
                                                                               anEvent.accumulatedTimeReference, anEvent.accumulatedTimeReferenceLiveLeap, TSTimeBaseInterval)];
	if (!description || ([description length] == 0) || [description compare:@" "] == NSOrderedSame) {
	    description = @" ";
	}
	if (anEvent.timeError > 1E7) {
	    return [NSString stringWithFormat:@"%@%c9999%c%@",
                             dateTimeString, separator, separator, description];
	} else {
	    return [NSString stringWithFormat:@"%@%c%.2f%c%@",
                             dateTimeString, separator, anEvent.timeError, separator, description];
	}
    } else {
	NSString *dateString = descriptionForDateOnly(timeInterval);
	NSString *timeString = descriptionForTimeOnly(timeInterval, anEvent.liveLeapSecondCorrection, anEvent.accumulatedTimeReference, anEvent.accumulatedTimeReferenceLiveLeap);
	NSString *dateAndTimeString = printDateToo ? [NSString stringWithFormat:@"%@\n%@", dateString, timeString] : timeString;
	NSString *accDesc = accuracyDescription(anEvent.timeError);
	if (!description || ([description length] == 0) || [description compare:@" "] == NSOrderedSame) {
	    return [NSString stringWithFormat:@"%@\n%@\n", dateAndTimeString, accDesc];
	} else {
	    return [NSString stringWithFormat:@"%@\n%@\n%@\n", description, dateAndTimeString, accDesc];
	}
    }
}

+ (NSString *)TSVOrCSVHeaderUsingTTForJD:(bool)useTTForJD useTSVorCSV:(EmailUseTSVorCSV)useTSVorCSV {
    char separator = useTSVorCSV == EmailUseTSV ? '\t' : ',';
    return [NSString stringWithFormat:NSLocalizedString(@"Local%cUTC%c%s%cInterval%cAccuracy%cDescription\n", @"Header for tab-or-comma-separated-value mail"),
            separator, separator,
            useTTForJD ? "JD(TT)" : "JD(UTC)",
            separator, separator, separator];
}

static EmailUseTSVorCSV
findEmailFormat() {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *emailFormat = [userDefaults stringForKey:@"TSEmailFormat"];
    if (emailFormat) {
        if ([emailFormat isEqualToString:@"tsv"]) {
            return EmailUseTSV;
        } else if ([emailFormat isEqualToString:@"csv"]) {
            return EmailUseCSV;
        } else {
            return EmailUseNeitherTSVNorCSV;
        }
    } else {
        return EmailUseNeitherTSVNorCSV;
    }
}

+ (NSString *)eventDescriptionForMail:(TSTimeHistory *)anEvent {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    EmailUseTSVorCSV useTSVorCSV = findEmailFormat();
    bool useTTForJD = [userDefaults boolForKey:@"TSUseTTForJD"] ? true : false;
    if (useTSVorCSV == EmailUseNeitherTSVNorCSV) {
	return [self eventDescriptionCore:anEvent useTSVorCSV:useTSVorCSV useTTForJD:useTTForJD printDateToo:true];
    } else {
	return [[self TSVOrCSVHeaderUsingTTForJD:(bool)useTTForJD useTSVorCSV:useTSVorCSV] stringByAppendingString:[self eventDescriptionCore:anEvent useTSVorCSV:useTSVorCSV useTTForJD:useTTForJD printDateToo:true]];
    }
}

+ (NSString *)allEventsDescriptionForMail {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    EmailUseTSVorCSV useTSVorCSV = findEmailFormat();
    NSInteger numberOfPastDays = [TSTimeHistory numberOfPastDays];
    NSInteger maxDays = [userDefaults integerForKey:@"TSEmailMaxDays"];
    if (maxDays > 0 && numberOfPastDays > maxDays) {
	numberOfPastDays = maxDays;
    }
    NSInteger maxEvents = [userDefaults integerForKey:@"TSEmailMaxEvents"];
    if (maxEvents == 0) {
	maxEvents = 999999999;
    }
    bool useTTForJD = [userDefaults boolForKey:@"TSUseTTForJD"] ? true : false;
    NSString *bigString = useTSVorCSV == EmailUseNeitherTSVNorCSV ? @"" : [self TSVOrCSVHeaderUsingTTForJD:useTTForJD useTSVorCSV:useTSVorCSV];
    int eventsPrinted = 0;
    for (int dayNumber = 0; dayNumber < numberOfPastDays && eventsPrinted < maxEvents; dayNumber++) {
	TSTimeHistory *event = [TSTimeHistory pastTimeAtOffsetFromPresent:0 withinDay:dayNumber];
	if (useTSVorCSV != EmailUseNeitherTSVNorCSV) {
	    bigString = [bigString stringByAppendingString:[self eventDescriptionCore:event useTSVorCSV:useTSVorCSV useTTForJD:useTTForJD printDateToo:false]];
	} else {
	    bigString = [NSString stringWithFormat:@"%@--------------------\n%@\n\n%@",
				  bigString,
				  descriptionForDateOnly(event.time),
				  [self eventDescriptionCore:event useTSVorCSV:useTSVorCSV useTTForJD:useTTForJD printDateToo:false]];
	}
	eventsPrinted++;
	if (eventsPrinted < maxEvents) {
	    int numberOfPastTimesWithinDay = [TSTimeHistory numberOfPastTimesWithinDay:dayNumber];
	    for (int eventNumber = 1; eventNumber < numberOfPastTimesWithinDay; eventNumber++) {
		event = [TSTimeHistory pastTimeAtOffsetFromPresent:eventNumber withinDay:dayNumber];
		bigString = [bigString stringByAppendingString:@"\n"];  // space before next event
		bigString = [bigString stringByAppendingString:[self eventDescriptionCore:event useTSVorCSV:useTSVorCSV useTTForJD:useTTForJD printDateToo:false]];
		eventsPrinted++;
		if (eventsPrinted >= maxEvents) {
		    break;
		}
                if ((eventsPrinted % 20) == 0) {
                    //printf("Re-allocating pool at event %d\n", eventsPrinted);
                    [bigString retain];  // Don't delete bigString from original pool
                    [pool release];
                    pool = [[NSAutoreleasePool alloc] init];
                    [bigString autorelease];  // But it needs to go into the new pool
                }
	    }
	    if (dayNumber + 1 < numberOfPastDays && eventsPrinted < maxEvents) {
		bigString = [bigString stringByAppendingString:@"\n"];  // space before next day
	    }
	}
    }
    [bigString retain];
    [pool release];
    [bigString autorelease];
    return bigString;
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)emailEventAction:(id)sender {
    assert(event);
    if (!event) {
	return;
    }
    if (![MFMailComposeViewController canSendMail]) {
	[[ECErrorReporter theErrorReporter] reportError:@"Can't send mail on this device"];
	return;
    }
    //printf("email event\n");
    NSString *mailString = [TSEventViewController eventDescriptionForMail:event];

    MFMailComposeViewController *viewController = [[[MFMailComposeViewController alloc] init] autorelease];
    [viewController setSubject:@"Emerald Timestamp Event"];
    [viewController setMessageBody:mailString isHTML:NO];
    [viewController setMailComposeDelegate:self];
    [self presentViewController:viewController animated:YES completion:nil];
}

- (IBAction)emailAllEventsAction:(id)sender {
    if (![MFMailComposeViewController canSendMail]) {
	[[ECErrorReporter theErrorReporter] reportError:@"Can't send mail on this device"];
	return;
    }
    //printf("email all events\n");
    NSString *mailString = [TSEventViewController allEventsDescriptionForMail];
    //printf("the big string is:\n%s\n", [mailString UTF8String]);

    MFMailComposeViewController *viewController = [[[MFMailComposeViewController alloc] init] autorelease];
    NSString *subject = @"Emerald Timestamp Event Log";
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSInteger maxDays = [userDefaults integerForKey:@"TSEmailMaxDays"];
    NSInteger maxEvents = [userDefaults integerForKey:@"TSEmailMaxEvents"];
    if (maxDays > 0) {
	subject = [NSString stringWithFormat:@"%@ (max days: %ld)", subject, (long)maxDays];
    }
    if (maxEvents > 0) {
	subject = [NSString stringWithFormat:@"%@ (max events: %ld)", subject, (long)maxEvents];
    }
    [viewController setSubject:subject];
    [viewController setMessageBody:mailString isHTML:NO];
    [viewController setMailComposeDelegate:self];
    [self presentViewController:viewController animated:YES completion:nil];
}

- (void)dealloc {
    [event release];
    [self unregisterForKeyboardNotifications];
    [super dealloc];
}

- (void)registerForKeyboardNotifications {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(keyboardWasShown:)
                   name:UIKeyboardDidShowNotification object:nil];
 
    [center addObserver:self
               selector:@selector(keyboardWillBeHidden:)
                   name:UIKeyboardWillHideNotification object:nil];
}

- (void)unregisterForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)keyboardWasShown:(NSNotification*)aNotification {
    keyboardIsShown = true;
    [self panViewToRevealTextField];
}

- (void)keyboardWillBeHidden:(NSNotification*)aNotification {
    keyboardIsShown = false;
}
@end
