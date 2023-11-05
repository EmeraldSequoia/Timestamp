//
//  TSNavController.m
//
//  Created by Steve Pucci 29 Sep 2012
//  Copyright Emerald Sequoia LLC 2012. All rights reserved.
//

#import "TSNavController.h"

@implementation TSNavController

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

@end
