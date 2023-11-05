//
//  TSCustomNameTextfieldController.m
//
//  Created by Steve Pucci 11 Feb 2012
//  Copyright Emerald Sequoia LLC 2012. All rights reserved.
//

#import "TSCustomNameTextfieldController.h"
#import "TSCustomNameEditorViewController.h"
#import "TSTopOptionsViewController.h"
#import "TSRootViewController.h"

@implementation TSCustomNameTextfieldController

@synthesize editorViewController, textField;

- (id)initWithCustomNameEditorController:(TSCustomNameEditorViewController *)callingController {
    [super initWithNibName:@"CustomNameTextField" bundle:nil];
    editorViewController = [callingController retain];
    return self;
}

- (void)dealloc {
    [editorViewController release];
    [super dealloc];
}

-(void)popToTop {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)viewDidLoad {
    [textField becomeFirstResponder];
    NSInteger rowBeingEdited = [editorViewController rowNumberBeingEdited];
    textField.text = [editorViewController currentTextForRow:rowBeingEdited];
    NSString *titleTxt;
    switch ([TSTopOptionsViewController masterMode]) {
      case TSMasterModeClassic:
        titleTxt = @"Custom Name";
        break;
      case TSMasterModeStopwatch:
        titleTxt = @"Stopwatch Name";
        break;
      case TSMasterModeProject:
        titleTxt = @"Project Name";
        break;
      default:
        assert(false);
        titleTxt = nil;
        break;
    }
    UINavigationItem *navItem = self.navigationItem;
    navItem.title = [NSString stringWithFormat:([editorViewController addingNotEditing] ? @"Add %@" : @"Edit %@"), titleTxt];
    [navItem setRightBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(popToTop)] autorelease]];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (IBAction)editingChanged:(id)sender {
    UITextField *notifyingTextfield = (UITextField *)sender;
    [editorViewController textFieldChangedTo:[notifyingTextfield text]];
}

- (IBAction)editingDidEnd:(id)sender {
    [TSRootViewController makeNewButtonsAndSetColors];
}

- (IBAction)editingDidEndOnExit:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
