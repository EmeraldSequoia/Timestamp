//
//  TSAudio.m
//  timestamp
//
//  Created by Steve Pucci on 5/4/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "TSAudio.h"

#import <AudioToolbox/AudioToolbox.h>
#import <CoreFoundation/CoreFoundation.h>
#import <AVFoundation/AVAudioPlayer.h>
#import <AVFoundation/AVAudioSession.h>

@implementation TSAudio

static AVAudioPlayer *audioPlayer;

+ (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    //printf("Sound finished, prepping for next play\n");
    [audioPlayer prepareToPlay];
}

+(void)startOfMain {
    // New for iOS 7 support:  Use singleton AVAudioSession
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    NSError *error;
    BOOL st = [audioSession setCategory:AVAudioSessionCategoryAmbient error:&error];
    if (st != YES) {
#ifndef NDEBUG
        NSLog(@"audioSession setCategory failed with error: %@", [error localizedDescription]);
#endif
    }
   
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Tock" ofType:@"aiff"];
    NSURL *url = [NSURL fileURLWithPath:path];

    audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if (!audioPlayer) {
	NSLog(@"Audio player initialization failure: %@", [error description]);
	return;
    }
    audioPlayer.delegate = (id<AVAudioPlayerDelegate>)self;
    [audioPlayer prepareToPlay];

    printf("Audio setup ok\n");
}

void TSPlayButtonPressSound(void) {
    if ([audioPlayer isPlaying]) {
	//printf("Stopping playing player\n");
	[audioPlayer stop];
    }
    [audioPlayer play];
}

@end
