//
//  AppDelegate.m
//  timestamp
//
//  Created by Steve Pucci on 4/30/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize window, navController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
	
    [super application:application didFinishLaunchingWithOptions:launchOptions];
	
    // Override point for customization after application launch
    if ([window respondsToSelector:@selector(rootViewController)]) {
        window.rootViewController = navController;
    } else {
        [window addSubview:[navController view]];
    }
    [window makeKeyAndVisible];

    return YES;
}

- (void)dealloc {
    [window release];
    [super dealloc];
}

@end
