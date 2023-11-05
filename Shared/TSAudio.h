//
//  TSAudio.h
//  timestamp
//
//  Created by Steve Pucci on 5/4/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TSAudio : NSObject {

}

+(void)startOfMain;

@end

#ifdef __cplusplus
extern "C" {
#endif
void TSPlayButtonPressSound(void);
#ifdef __cplusplus
}
#endif
