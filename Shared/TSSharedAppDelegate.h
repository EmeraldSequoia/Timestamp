//
//  TSSharedAppDelegate.h
//  timestamp
//
//  Created by Steve Pucci on 5/6/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface TSSharedAppDelegate : NSObject<UIApplicationDelegate> {

}

+ (void)setNewOrientation:(UIInterfaceOrientation)newOrient;

- (UIWindow *)window;

@end
