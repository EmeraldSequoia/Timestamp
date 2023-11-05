//
//  TSEmailOptionsViewController.h
//
//  Created by Steve Pucci 06 Feb 2012
//  Copyright Emerald Sequoia LLC 2012. All rights reserved.
//

#ifndef _TSEMAILOPTIONSVIEWCONTROLLER_H_
#define _TSEMAILOPTIONSVIEWCONTROLLER_H_

@class TSTopOptionsViewController;

/*! View controller for "email options" view */
@interface TSEmailOptionsViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource> {
    TSTopOptionsViewController *topOptionsController;
}

-(id)initWithTopOptionsController:(TSTopOptionsViewController *)controller;

@end

#endif  // _TSEMAILOPTIONSVIEWCONTROLLER_H_
