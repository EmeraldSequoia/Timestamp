    //
//  main.m
//  timestamp
//
//  Created by Steve Pucci on 4/30/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TSTimeHistory.h"
#import "TSAudio.h"

int main(int argc, char *argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    [TSTimeHistory startOfMain];
    [TSAudio startOfMain];
    int retVal = UIApplicationMain(argc, argv, nil, nil);
    [pool release];
    return retVal;
}
