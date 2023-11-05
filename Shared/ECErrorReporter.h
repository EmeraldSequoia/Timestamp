//
//  ECErrorReporter.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

@interface ECErrorReporter : NSObject<UIAlertViewDelegate> {
}

-(void)reportError:(NSString *)errorDescription;
+(ECErrorReporter *)theErrorReporter;

@end
