//
//  TSSharedAppDelegate.mm
//  timestamp
//
//  Created by Steve Pucci on 5/6/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "TSSharedAppDelegate.h"
#import "TSRootViewController.h"
//#import "TSModeOptionsViewController.h"
#import "TSTopOptionsViewController.h"
#import "TSCustomNameEditorViewController.h"
#import "TSTimeHistory.h"

#include "ESUtil.hpp"
#include "ESTime.hpp"

@implementation TSSharedAppDelegate

static UIWindow *theWindow = nil;

- (UIWindow *)window {
    return nil;  // overridden in derived classes
}

///// DAL and battery monitoring
// static const char *batteryStateNameForState(NSInteger batteryState) {
//     const char *stateName;
//     switch (batteryState) {
// 	case 1:
// 	    stateName = "unplugged";
// 	    break;
// 	case 2:
// 	    stateName = "charging";
// 	    break;
// 	case 3:
// 	    stateName = "full";
// 	    break;
// 	default:
// 	case 0:
// 	    stateName = "unknown";
// 	    break;
//     }
//     return stateName;
// }

static bool batteryStatesAreEquivalent(NSInteger batteryState1,
				       NSInteger batteryState2) {
    return
    batteryState1 == batteryState2
    || (batteryState1 == 2 && batteryState2 == 3)  // Charging == Full
    || (batteryState1 == 3 && batteryState2 == 2); // Full == Charging
}

static BOOL currentDAL;

- (void)setDAL:(bool)newVal {
#if 0
    NSString *msg;
    if (newVal) {
	msg = @"will not lock";
    } else {
	msg = @"may auto-lock";
    }
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Device" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
#endif
    currentDAL = newVal;
    UIApplication *theApplication = [UIApplication sharedApplication];
    theApplication.idleTimerDisabled = !newVal;
    theApplication.idleTimerDisabled = newVal;
}

- (void)setDALHeartbeatFire:(NSTimer *)timer {
    if (currentDAL) {
	UIApplication *theApplication = [UIApplication sharedApplication];
	theApplication.idleTimerDisabled = !currentDAL;
	theApplication.idleTimerDisabled = currentDAL;
    }
}

- (void)setDALForBatteryState:(NSInteger)batteryState {
//  printf("power: %s\n", batteryStateNameForState(batteryState));
    
    BOOL dalDefault;
    if (batteryState == 2 // charging
	|| batteryState == 3) { // full
	dalDefault = [[NSUserDefaults standardUserDefaults] boolForKey:@"TSDisableAutoLockPwr"];
    } else {
	dalDefault = [[NSUserDefaults standardUserDefaults] boolForKey:@"TSDisableAutoLockBat"];
    }
    [self setDAL:dalDefault];
}

- (void)delayedSetDal:(NSTimer *)timer {
    [self setDALForBatteryState:[[UIDevice currentDevice] batteryState]];
}

static NSInteger lastBatteryState = -1;

- (void)batteryStateDidChange:(id)foo {
    NSInteger newState = [[UIDevice currentDevice] batteryState];
#if 0
    NSString *msg = [NSString stringWithFormat:@"%s", batteryStateNameForState(newState)];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"The battery state is now:" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
#endif
    if (!batteryStatesAreEquivalent(newState,lastBatteryState)) {
	[self setDALForBatteryState:newState];
    }
    lastBatteryState = newState;
}

///// end battery monitoring

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    // [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;  // Done by NTP directly
    theWindow = [self window];

    // set up battery state notifications
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(batteryStateDidChange:)
                                                 name:@"UIDeviceBatteryStateDidChangeNotification" object:nil];
    // Toggle DAL state to work around apparent bug in OS
    [self setDAL:false];
    [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(delayedSetDal:) userInfo:nil repeats:false];
    [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(setDALHeartbeatFire:) userInfo:nil repeats:YES];

    [TSTopOptionsViewController loadDefaults];
    [TSCustomNameEditorViewController loadDefaults];

    return YES;
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    ESUtil::leavingBackground();
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    ESUtil::enteringBackground();
}

- (void)applicationSignificantTimeChange:(UIApplication *)application {
    ESUtil::significantTimeChange();
}

- (void)applicationWillResignActive:(UIApplication *)application {
    ESUtil::goingToSleep();
    [TSTimeHistory goingToSleep];  // Set flag indicating button should be yellow
    [TSRootViewController syncStatusChangedInMainThread];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [TSTimeHistory wakingUp];    // Unforce yellow
    ESUtil::wakingUp();
}

- (void)applicationWillTerminate:(UIApplication *)application {
//    ESUtil::willTerminate();
}

UIInterfaceOrientation currentOrientation = UIInterfaceOrientationPortrait;

+ (void)setNewOrientation:(UIInterfaceOrientation)newOrient {
    currentOrientation = newOrient;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    NSUInteger val = (1 << UIInterfaceOrientationPortrait) | (1 << UIInterfaceOrientationLandscapeLeft) |
             (1 << UIInterfaceOrientationLandscapeRight) | (1 << UIInterfaceOrientationPortraitUpsideDown);
    return val;
}

+ (CGSize)applicationSize {
    CGSize untranslatedAppSize = [[UIScreen mainScreen] bounds].size;
    if (currentOrientation == UIInterfaceOrientationPortrait || currentOrientation == UIInterfaceOrientationPortraitUpsideDown) {
	return untranslatedAppSize;
    } else {
	return CGSizeMake(untranslatedAppSize.height, untranslatedAppSize.width);
    }
}

@end
