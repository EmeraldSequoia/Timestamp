//
//  AppDelegate.h
//  timestamp
//
//  Created by Steve Pucci on 4/30/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "TSSharedAppDelegate.h"

@interface AppDelegate : TSSharedAppDelegate {
@protected
    UIWindow               *window;
    UINavigationController *navController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navController;

@end

