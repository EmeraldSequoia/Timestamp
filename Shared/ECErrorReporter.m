//
//  ECErrorReporter.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import "ECErrorReporter.h"

#import <UIKit/UIKit.h>
#import "Foundation/Foundation.h"

@implementation ECErrorReporter

static ECErrorReporter *theErrorReporter = nil;

static int errorsShowing = 0;

-(void)reportError:(NSString *)errorDescription
{
    printf("Error: %s\n", [errorDescription UTF8String]);  // Should this be under debug only?
    fflush(stdout);
    fprintf(stderr, "Error: %s\n", [errorDescription UTF8String]);  // Should this be under debug only?
    fflush(stderr);
    if (errorsShowing == 3) {
	errorDescription = @">3 errors!";
	errorsShowing++;
    } else if (errorsShowing > 3) {
	return;
    } else {
	errorsShowing++;
    }
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                   message:errorDescription
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
                errorsShowing--;
            }]];
    UIViewController *iOSWantsAViewControllerToDoThisSoHereIsOne = [[UIViewController alloc] init];
    [iOSWantsAViewControllerToDoThisSoHereIsOne presentViewController:alert animated:YES completion:nil];
    [iOSWantsAViewControllerToDoThisSoHereIsOne release];
}

+(ECErrorReporter *)theErrorReporter
{
    if (!theErrorReporter) {
	theErrorReporter = [[ECErrorReporter alloc] init];
    }
    return theErrorReporter;
}


@end
