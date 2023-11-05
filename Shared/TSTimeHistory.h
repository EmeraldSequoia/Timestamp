//
//  NSTimeHistory.h
//  timestamp
//
//  Created by Steve Pucci on 5/6/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#undef ES_FAKE_TIME

#import <Foundation/Foundation.h>

typedef enum {
    TSTimeBaseLocal12,
    TSTimeBaseLocal24,
    TSTimeBaseUTC24,
    TSTimeBaseJDTT,
    TSTimeBaseJDUTC,
    TSTimeBaseInterval
} TSTimeBase;
#define TSNumTimeBases 6

typedef enum TSConfidenceLevel {
    TSConfidenceLevelYellow,
    TSConfidenceLevelGreen
} TSConfidenceLevel;

// If more than 16 types (including notSpecial) are added, update #defines immediately below
typedef enum TSSpecialEventType {
    TSSpecialEventNotSpecial,  // Must be zero
    TSSpecialEventReset,
    TSSpecialEventStart,
    TSSpecialEventStop,
    TSSpecialEventLap,
    TSSpecialEventProjectChange,
} TSSpecialEventType;
#define TSSpecialEventTypeForTag(tag) ((TSSpecialEventType)(tag & 0xf))
#define TSSpecialTimerNumberForTag(tag) (tag >> 4)
#define TSTagForSpecialEvent(specialType, timerNumber) ((timerNumber << 4) | (unsigned int)specialType)

extern const char *specialNames[];

#ifdef __cplusplus
extern "C" {
#endif
extern NSString *descriptionForEventDetailHeader(NSTimeInterval timeInterval,
                                                 NSTimeInterval liveLeapSecondCorrection,
                                                 NSTimeInterval referenceZeroTimeInterval,
                                                 NSTimeInterval referenceZeroTimeLiveLeap);
extern NSString *descriptionForTimeOnly(NSTimeInterval timeInterval,
                                        NSTimeInterval liveLeapSecondCorrection,
                                        NSTimeInterval referenceZeroTimeInterval,
                                        NSTimeInterval referenceZeroTimeLiveLeap);
extern NSString *descriptionForTimeOnlyForTimerNumber(NSTimeInterval timeInterval,
                                                      NSTimeInterval liveLeapSecondCorrection,
                                                      NSInteger      timerNumber);
extern NSString *descriptionForDateOnly(NSTimeInterval timeInterval);
extern NSString *descriptionForTimeAndDateForExcel(NSTimeInterval timeInterval,
                                                   NSTimeInterval liveLeapSecondCorrection,
                                                   NSTimeInterval referenceZeroTimeInterval,
                                                   NSTimeInterval referenceZeroTimeLiveLeap,
						   TSTimeBase     timeBase);
#ifdef __cplusplus
}
#endif

@interface TSTimeHistory : NSObject {
@private
    NSTimeInterval     time;
    NSTimeInterval     mediaTime;
    NSTimeInterval     liveLeapSecondCorrection;
    NSTimeInterval     accumulatedTimeReference;  // Either the actual reference time, or, for projects and stopwatches, a pseudo event time back from this event exactly by the accumulated time
    NSTimeInterval     accumulatedTimeReferenceLiveLeap;  // And its live leap  (zero for projects and stopwatches)
    NSTimeInterval     accumulatedProject2Time;
    TSConfidenceLevel  accumulatedConfidenceLevel;
    float              accumulatedTimeError;
    float              timeError;
    NSString           *description;
    int                syncIndex;
    bool               deleteFlag;
    bool               isReferenceZero;
    TSSpecialEventType specialType;
    int                specialTimerNumber;
}

@property(readonly, nonatomic) TSConfidenceLevel confidenceLevel;
@property(readonly, nonatomic) NSTimeInterval time;
@property(readonly, nonatomic) NSTimeInterval liveLeapSecondCorrection;
@property(readonly, nonatomic) float timeError;
@property(readonly, nonatomic) int syncIndex;
@property(readonly, nonatomic) bool deleteFlag;
@property(readonly, nonatomic) bool isReferenceZero;
@property(nonatomic, retain) NSString *description;
@property(readonly, nonatomic) NSTimeInterval accumulatedTimeReference;
@property(readonly, nonatomic) NSTimeInterval accumulatedProject2Time;
@property(readonly, nonatomic) NSTimeInterval accumulatedTimeReferenceLiveLeap;
@property(readonly, nonatomic) TSSpecialEventType specialType;
@property(readonly, nonatomic) int specialTimerNumber;

-(bool)toggleDeleteFlag;  // returns new state

+ (void)startOfMain;

+(TSConfidenceLevel)currentConfidence;

+(TSTimeHistory *)addTimeAtNow;  // adds to past event array

+(NSString *)currentDescription;
+(void)setCurrentDescription:(NSString *)currentDescription;
-(void)setDescription:(NSString *)description;

-(void)setSpecialType:(TSSpecialEventType)specialType timerNumber:(int)specialTimerNumber;
#if 0
-(void)setSpecialProjectType:(TSSpecialEventType)specialType projectName:(NSString *)specialProjectName;
#endif
+(int)timerNumberForProjectName:(NSString *)projectName createIfNecessary:(bool)createIfNecessary;
+(NSString *)projectNameForTimerNumber:(int)timerNumber;
+(bool)timerIsRunning:(int)timerNumber;
+(void)recalculateAccumulatedTimes;

+ (NSString *)userStringFromTimeBase:(TSTimeBase)timeBase;  // For picker
+ (void)setTimeBase:(TSTimeBase)timeBase;
+ (TSTimeBase)currentTimeBase;

//+(TSTimeHistory *)pastTimeAtOffsetFromPresent:(unsigned int)offsetFromPresent;
+(TSTimeHistory *)pastTimeAtOffsetFromPresent:(unsigned int)offsetFromPresent withinDay:(unsigned int)withinDay;
+(void)setPastDescriptionAtOffsetFromPresent:(unsigned int)offsetFromPresent description:(NSString *)description;
+(void)setPastDescriptionAtOffsetFromPresent:(unsigned int)offsetFromPresent withinDay:(unsigned int)withinDay description:(NSString *)description;

+(unsigned int)numberOfPastTimes;
+(unsigned int)numberOfPastDays;
+(unsigned int)numberOfPastTimesWithinDay:(unsigned int)withinDay;
+(bool)firstTwoPastTimesAreOnSameDay;
+(bool)firstPastDayIsTodayOrNil;
+(int)slotForOffset:(unsigned int)offset withinDay:(unsigned int)withinDay;

+(void)removeAllPastTimes;
+(void)removePastTimeAtOffsetFromPresent:(unsigned int)offsetFromPresent withinDay:(unsigned int)withinDay;

+(void)rotateTimeBase;
+(void)reloadDefaults;
+(void)goingToSleep;
+(void)wakingUp;

+ (void)toggleReferenceZeroForEventAtOffsetFromPresent:(unsigned int)row withinDay:(unsigned int)section;
+ (void)toggleReferenceZeroForEvent:(TSTimeHistory *)event;

+ (void)setAllowMultipleReferenceZeroes:(bool)newAllowMultipleAllowReferenceZeroes;
+ (bool)allowMultipleReferenceZeroes;

+ (NSIndexSet *)deleteFlaggedTimes;  // returns empty sections (days) to be deleted in UI
+ (void)clearAllDeleteFlags;
+ (void)toggleDeleteFlagForRow:(unsigned int)row withinDay:(unsigned int)withinDay;
+ (bool)eventIsReferenceZeroAtOffsetFromPresent:(unsigned int)offsetFromPresent withinDay:(unsigned int)withinDay;
+ (bool)eventIsReferenceZero:(TSTimeHistory *)event;

+ (void)printAllTimes;

@end
