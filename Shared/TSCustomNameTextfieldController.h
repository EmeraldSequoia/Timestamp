//
//  TSCustomNameTextfieldController.h
//
//  Created by Steve Pucci 11 Feb 2012
//  Copyright Emerald Sequoia LLC 2012. All rights reserved.
//

#ifndef _TSCUSTOMNAMETEXTFIELDCONTROLLER_H_
#define _TSCUSTOMNAMETEXTFIELDCONTROLLER_H_

@class TSCustomNameEditorViewController;

/*! View controller for textfield to enter (or change) a custom name */
@interface TSCustomNameTextfieldController : UIViewController {
    TSCustomNameEditorViewController *editorViewController;
    UITextField                      *textField;
}

@property (nonatomic, readonly) TSCustomNameEditorViewController *editorViewController;
@property (nonatomic, assign) IBOutlet UITextField *textField;

- (id)initWithCustomNameEditorController:(TSCustomNameEditorViewController *)controller;

- (IBAction)editingChanged:(id)sender;
- (IBAction)editingDidEnd:(id)sender;
- (IBAction)editingDidEndOnExit:(id)sender;

@end

#endif  // _TSCUSTOMNAMETEXTFIELDCONTROLLER_H_
