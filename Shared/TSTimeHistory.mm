//
//  TSTimeHistory.mm
//  timestamp
//
//  Created by Steve Pucci on 5/6/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "TSTimeHistory.h"

#import "TSRootViewController.h"
#import "TSEventViewController.h"
#import "TSTopOptionsViewController.h"

#include "ESUtil.hpp"
#include "ESThread.hpp"
#include "ESTime.hpp"
#include "ESLeapSecond.hpp"
#include "ESNTPDriver.hpp"
#include "ESLocationTimeHelper.hpp"
#include "ESErrorReporter.hpp"
#define ESTRACE
#include "ESTrace.hpp"

#ifdef ES_FAKE_TIME
#include "ESCalendar.hpp"
#endif

#define TS_RELIABLE_SYNC_INDEX_START 10000000  // Sync indices less than this number are bogus because current sync was not saved across app restart.

const char *specialNames[] = {
    "Not Special",
    "Reset",
    "Start",
    "Stop",
    "Lap",
    "Project"
};

#include <libkern/OSAtomic.h>  // For OSMemoryBarrier()

static bool startOfMainComplete = false;

#define DEFAULT_GREEN_THRESHOLD 0.40
static NSTimeInterval greenThreshold = DEFAULT_GREEN_THRESHOLD;

static TSConfidenceLevel confidenceLevelFromTimeError(float timeError) {
    if (timeError <= greenThreshold) {
	return TSConfidenceLevelGreen;
    } else {
	return TSConfidenceLevelYellow;
    }
}

@interface TSTimeHistory (Private)
+(void)recalculateAccumulatedTimes;
@end

@implementation TSTimeHistory

/*! TimerData is used to accumulate information when walking from older events to newer */
class TimerData {
  public:
    NSTimeInterval    accumulator;      // The amount of interval accumulated on this timer through the last start or stop
    NSTimeInterval    activeStart;      // If the timer is running, the time at which it was last started (0 if stopped)
    NSTimeInterval    activeStartLeap;  // liveLeapSecondCorrection at last start, or zero if stopped
    float             accumulatedError; // sum of errors of contributing event until a reset
    int               lastSyncIndex;    // used for accumulating errors; if the last sync index is the same as this one, the two events are off in the same direction and the error doesn't need to be added
    TSConfidenceLevel accumulatedConfidence;  // green if all contributing events are green, else yellow

    void              reset() {
        accumulator = 0;
        activeStart = 0;
        activeStartLeap = 0;
        accumulatedError = 0;
        accumulatedConfidence = TSConfidenceLevelGreen;
        lastSyncIndex = -1;
    }

    void              mergeErrorData(TSTimeHistory *timeDescriptor) {
        if (timeDescriptor->syncIndex != lastSyncIndex) {
            accumulatedError += timeDescriptor->timeError;
            lastSyncIndex = timeDescriptor->syncIndex;
        }
        if (accumulatedConfidence == TSConfidenceLevelGreen &&
            confidenceLevelFromTimeError(timeDescriptor->timeError) == TSConfidenceLevelYellow) {
            accumulatedConfidence = TSConfidenceLevelYellow;
        }
    }

    void              captureTime(TSTimeHistory *timeDescriptor) {
        if (activeStart) {  // If running
            accumulator += ESLeapSecond::intervalBetweenUTCValuesWithLiveLeapCorrections(activeStart, activeStartLeap,
                                                                                         timeDescriptor->time, timeDescriptor->liveLeapSecondCorrection);
        }
        mergeErrorData(timeDescriptor);
        timeDescriptor->accumulatedTimeReference = timeDescriptor->time - accumulator;
        timeDescriptor->accumulatedTimeReferenceLiveLeap = 0;
        timeDescriptor->accumulatedTimeError = accumulatedError;
        timeDescriptor->accumulatedConfidenceLevel = accumulatedConfidence;
    }
};

static NSMutableArray *pastTimes;  // an array of all events
static NSMutableArray *pastTimesSinceMediaTimeReset;
static NSMutableArray *pastDays;  // an array by date of arrays by time of all events
static NSString *currentDescription = @" ";

static TimerData *timerDatas;
static NSInteger timerDatasCapacity;

static NSTimeInterval lastNonProjectZero = 0;  // meaning: "last zero for non-project events", not "last zero in a non-project event"
static NSTimeInterval lastNonProjectZeroLiveLeap = 0;

static NSMutableArray *projectNamesByNumber = nil;
static NSMutableDictionary *projectNumbersByName = nil;
static NSInteger numTotalProjects = 0;
#define RESERVE_STOPWATCHES (20)  // We won't actually have 20 stopwatches, but this offsets all of the project timer numbers by 20
#define NUM_TOTAL_TIMERS (numTotalProjects + RESERVE_STOPWATCHES)

static TSTimeBase currentTimeBase = TSTimeBaseLocal12;
static NSInteger currentSyncIndex;

static bool useTTForJD = true;

static bool allowMultipleReferenceZeroes = false;

// Forward decl:
static void setCurrentTimeBase(TSTimeBase timeBase,
                               bool       alsoRecalculateAccumulatedTimes);

@synthesize time, description, syncIndex, liveLeapSecondCorrection, deleteFlag, specialType, specialTimerNumber, isReferenceZero,
    accumulatedTimeReference, accumulatedTimeReferenceLiveLeap, accumulatedProject2Time;

-(id)initWithTime:(NSTimeInterval)aTime
        timeError:(float)aTimeError
liveLeapSecondCorrection:(NSTimeInterval)aLiveLeapSecondCorrection
      description:(NSString *)aDescription
      specialType:(TSSpecialEventType)aSpecialType
specialTimerNumber:(int)aSpecialTimerNumber
        mediaTime:(NSTimeInterval)aMediaTime
        syncIndex:(int)aSyncIndex {
    [super init];
    time = aTime;
    mediaTime = aMediaTime;
    timeError = aTimeError;
    liveLeapSecondCorrection = aLiveLeapSecondCorrection;
    syncIndex = aSyncIndex;
    description = [aDescription retain];
    specialType = aSpecialType;
    specialTimerNumber = aSpecialTimerNumber;
    accumulatedTimeReference = 0;
    accumulatedTimeReferenceLiveLeap = 0;
    accumulatedProject2Time = 0;
    accumulatedConfidenceLevel = TSConfidenceLevelGreen;
    accumulatedTimeError = 0;
    deleteFlag = false;
    return self;
}

-(void)dealloc {
    [description release];
    [super dealloc];
}

static void qualifyDescription(NSString **description) {
    if ([*description length] == 0) {
	*description = @" ";
    }
}

static NSDateFormatter *dateFormatter = nil;
static NSDateFormatter *timeFormatter = nil;
static NSDateFormatter *ampmFormatter = nil;
static NSCalendar *utcCalendar = nil;

#define kECJulianDateOf1990Epoch (2447891.5)
#define kEC1990Epoch (-347241600.0)  // 12/31/1989 GMT - 1/1/2001 GMT, calculated as 24 * 3600 * (365 * 8 + 366 * 3 + 1) /*1992, 1996, 2000*/ and verified with NSCalendar

static inline double
julianDateUTCForDate(NSTimeInterval dateInterval) {
    double secondsSince1990Epoch = dateInterval - kEC1990Epoch;
    return kECJulianDateOf1990Epoch + (secondsSince1990Epoch / (24 * 3600));
}

static double
julianDateTTForDate(NSTimeInterval dateInterval,
                    NSTimeInterval liveLeapSecondCorrection) {
    double tt = dateInterval + 32.184 + 10 + ESLeapSecond::cumulativeLeapSecondsForUTC(dateInterval);
    if (liveLeapSecondCorrection > 1) {
        tt += liveLeapSecondCorrection - 1;
    }
    return julianDateUTCForDate(tt);
}

static int dateRepFor(NSTimeInterval theTime) {
    assert(dateFormatter);
    NSCalendar *calendar = [dateFormatter calendar];
    assert(calendar);
    NSDateComponents *comps = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:theTime]];
    NSInteger rep = comps.year * 10000 + comps.month * 100 + comps.day;
    //printf("dateRepFor %d\n", rep);
    return (int)rep;
}    

static void reconstructPastDates() {
    assert(pastDays);
    [pastDays removeAllObjects];
    int lastDateRep = 0;
    NSMutableArray *timesForThisDay = nil;
    NSInteger pastTimeCount = [pastTimes count];
    for (TSTimeHistory *event in pastTimes) {
	int dateRep = dateRepFor(event.time);
	if (dateRep != lastDateRep) {
	    timesForThisDay = [NSMutableArray arrayWithCapacity:pastTimeCount];
	    [pastDays addObject:timesForThisDay];
	    lastDateRep = dateRep;
	}
	assert(timesForThisDay);
	[timesForThisDay addObject:event];
    }
}

// Preload any values for which the default value when missing isn't what we want
+ (void)registerDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *defaultsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								 [NSNumber numberWithBool:YES],	    @"ECUseNTP",
								 [NSNumber numberWithBool:NO],	    @"TSUseTTForJD",
                                                                 [NSNumber numberWithInteger:TS_RELIABLE_SYNC_INDEX_START], @"TSReliableSyncIndex",
                                                                 [NSNumber numberWithDouble:DEFAULT_GREEN_THRESHOLD], @"TSGreenThreshold",
							         nil];
    [defaults registerDefaults:defaultsDict];
}

// Save current values on "disk"
+ (void)saveDefaults {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSInteger pastTimeCount = [pastTimes count];
    NSMutableArray *timeArray = [NSMutableArray arrayWithCapacity:pastTimeCount];
    NSMutableArray *errorArray = [NSMutableArray arrayWithCapacity:pastTimeCount];
    NSMutableArray *descriptionArray = [NSMutableArray arrayWithCapacity:pastTimeCount];
    NSMutableArray *syncIndexArray = [NSMutableArray arrayWithCapacity:pastTimeCount];
    NSMutableArray *liveLeapSecondCorrectionArray = [NSMutableArray arrayWithCapacity:pastTimeCount];
    NSMutableArray *specialTypeArray = [NSMutableArray arrayWithCapacity:pastTimeCount];
    NSMutableArray *specialTimerNumberArray = [NSMutableArray arrayWithCapacity:pastTimeCount];
    NSMutableArray *referenceZeroFlags = [NSMutableArray arrayWithCapacity:pastTimeCount];
    int timeIndex = 0;
    for (TSTimeHistory *timeDescriptor in pastTimes) {
        [referenceZeroFlags addObject:[NSNumber numberWithBool:timeDescriptor->isReferenceZero]];
	[timeArray addObject:[NSNumber numberWithDouble:timeDescriptor->time]];
	[errorArray addObject:[NSNumber numberWithFloat:timeDescriptor->timeError]];
        [liveLeapSecondCorrectionArray addObject:[NSNumber numberWithDouble:timeDescriptor->liveLeapSecondCorrection]];
	NSString *description = timeDescriptor->description;
	qualifyDescription(&description);
	[descriptionArray addObject:description];
        [specialTypeArray addObject:[NSNumber numberWithInteger:(int)timeDescriptor->specialType]];
        [specialTimerNumberArray addObject:[NSNumber numberWithInteger:timeDescriptor->specialTimerNumber]];
	[syncIndexArray addObject:[NSNumber numberWithInteger:timeDescriptor->syncIndex]];
	timeIndex++;
    }
    [userDefaults setObject:referenceZeroFlags forKey:@"event-reference-zero-flags"];
    [userDefaults setObject:timeArray forKey:@"event-times"];
    [userDefaults setObject:errorArray forKey:@"event-errors"];
    [userDefaults setObject:liveLeapSecondCorrectionArray forKey:@"event-leap-second-corrections"];
    [userDefaults setObject:descriptionArray forKey:@"event-descriptions"];
    [userDefaults setObject:specialTypeArray forKey:@"event-special-types"];
    [userDefaults setObject:specialTimerNumberArray forKey:@"event-special-timer-numbers"];
    [userDefaults setObject:syncIndexArray forKey:@"event-sync-indices"];
    [userDefaults setObject:currentDescription forKey:@"current-description"];
    [userDefaults setObject:[NSNumber numberWithDouble:greenThreshold] forKey:@"TSGreenThreshold"];
    [userDefaults setObject:[NSNumber numberWithInteger:currentSyncIndex] forKey:@"TSReliableSyncIndex"];
    [userDefaults setObject:[NSNumber numberWithBool:allowMultipleReferenceZeroes] forKey:@"TSAllowMultZero"];
}

+ (void)saveProjectNameDefaults {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:projectNamesByNumber forKey:@"project-names"];
}

+ (NSString *)userStringFromTimeBase:(TSTimeBase) timeBase {  // For picker
    assert(timeBase >= 0 && timeBase < TSNumTimeBases);
    switch (timeBase) {
      default:
      case TSTimeBaseLocal12:
	return NSLocalizedString(@"Local 12-hour time", @"User-visible description of 12-hour time base");
      case TSTimeBaseLocal24:
	return NSLocalizedString(@"Local 24-hour time", @"User-visible description of 24-hour time base");
      case TSTimeBaseUTC24:
	return NSLocalizedString(@"UTC (24-hour) time", @"User-visible description of UTC time base");
      case TSTimeBaseJDTT:
	return NSLocalizedString(@"Julian Date (TT based)", @"User-visible description of Julian Date time base");
      case TSTimeBaseJDUTC:
	return NSLocalizedString(@"Julian Date (UTC based)", @"User-visible description of Julian Date time base");
      case TSTimeBaseInterval:
	return NSLocalizedString(@"Interval from last zero", @"User-visible description of interval base");
    }
}

+ (void)setTimeBase:(TSTimeBase)timeBase {
    assert(timeBase >= 0 && timeBase < TSNumTimeBases);
    setCurrentTimeBase(timeBase, true/*alsoRecalculateAccumulatedTimes*/);
}

static TSTimeBase timeBaseFromString(NSString *timeBaseString) {
    //printf("time base from defaults is %s\n", [timeBaseString UTF8String]);
    if ([timeBaseString caseInsensitiveCompare:@"local12"] == NSOrderedSame) {
	return TSTimeBaseLocal12;
    } else if ([timeBaseString caseInsensitiveCompare:@"local24"] == NSOrderedSame) {
	return TSTimeBaseLocal24;
    } else if ([timeBaseString caseInsensitiveCompare:@"UTC"] == NSOrderedSame) {
	return TSTimeBaseUTC24;
    } else if ([timeBaseString caseInsensitiveCompare:@"Julian"] == NSOrderedSame) {
	return useTTForJD ? TSTimeBaseJDTT : TSTimeBaseJDUTC;
    } else if ([timeBaseString caseInsensitiveCompare:@"Julian(TT)"] == NSOrderedSame) {
	return TSTimeBaseJDTT;
    } else if ([timeBaseString caseInsensitiveCompare:@"Julian(UTC)"] == NSOrderedSame) {
	return TSTimeBaseJDUTC;
    } else if ([timeBaseString caseInsensitiveCompare:@"interval"] == NSOrderedSame) {
	return TSTimeBaseInterval;
    }
    assert(false);
    return TSTimeBaseLocal12;
}

static NSString *stringFromTimeBase(TSTimeBase timeBase) {
    switch (timeBase) {
      default:
      case TSTimeBaseLocal12:
	return @"local12";
      case TSTimeBaseLocal24:
	return @"local24";
      case TSTimeBaseUTC24:
	return @"UTC";
      case TSTimeBaseJDTT:
	return @"Julian(TT)";
      case TSTimeBaseJDUTC:
	return @"Julian(UTC)";
      case TSTimeBaseInterval:
	return @"interval";
    }
}

// Load current values from "disk"
+ (void)loadDefaults {
    int nonReliableSyncIndexFakeValue = 0;
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    currentSyncIndex = [userDefaults integerForKey:@"TSReliableSyncIndex"];
    assert(currentSyncIndex >= TS_RELIABLE_SYNC_INDEX_START);  // Because we didn't use to store it at all
    greenThreshold = [userDefaults doubleForKey:@"TSGreenThreshold"];
    NSArray *timeArray = [userDefaults arrayForKey:@"event-times"];
    NSInteger timeArrayCount = [timeArray count];
    NSArray *errorArray = [userDefaults arrayForKey:@"event-errors"];
    NSInteger errorArrayCount = [errorArray count];
    NSArray *descriptionArray = [userDefaults arrayForKey:@"event-descriptions"];
    NSInteger descriptionArrayCount = [descriptionArray count];
    NSArray *syncIndexArray = [userDefaults arrayForKey:@"event-sync-indices"];
    NSInteger syncIndexArrayCount = [syncIndexArray count];
    NSArray *liveLeapSecondCorrectionArray = [userDefaults arrayForKey:@"event-leap-second-corrections"];
    NSInteger liveLeapSecondCorrectionArrayCount = [liveLeapSecondCorrectionArray count];
    NSArray *specialTypeArray = [userDefaults arrayForKey:@"event-special-types"];
    NSInteger specialTypeArrayCount = [specialTypeArray count];
    NSArray *specialTimerNumberArray = [userDefaults arrayForKey:@"event-special-timer-numbers"];
    NSInteger specialTimerNumberArrayCount = [specialTimerNumberArray count];
    NSArray *referenceZeroFlags = [userDefaults objectForKey:@"event-reference-zero-flags"];
    NSInteger referenceZeroFlagsCount = [referenceZeroFlags count];
    assert(!pastTimes);  // Only do this once
    pastTimes = [[NSMutableArray alloc] initWithCapacity:timeArrayCount];
    pastTimesSinceMediaTimeReset = [[NSMutableArray alloc] initWithCapacity:2];
    for (int i = 0; i < timeArrayCount; i++) {
	float timeError = i < errorArrayCount ? [[errorArray objectAtIndex:i] floatValue] : 1E9;
        double liveLeapSecondCorrection = i < liveLeapSecondCorrectionArrayCount ? [[liveLeapSecondCorrectionArray objectAtIndex:i] doubleValue] : 0;
	NSInteger syncIndex = syncIndexArray && i < syncIndexArrayCount ? [[syncIndexArray objectAtIndex:i] integerValue] : -1;
        if (syncIndex < TS_RELIABLE_SYNC_INDEX_START) {
            syncIndex = nonReliableSyncIndexFakeValue++;
        }
        TSSpecialEventType specialType = i < specialTypeArrayCount ? (TSSpecialEventType)([[specialTypeArray objectAtIndex:i] integerValue]) : TSSpecialEventNotSpecial;
        NSInteger specialTimerNumber = i < specialTimerNumberArrayCount ? [[specialTimerNumberArray objectAtIndex:i] integerValue] : 0;
	NSString *description = i < descriptionArrayCount ? [descriptionArray objectAtIndex:i] : @" ";
	qualifyDescription(&description);
        TSTimeHistory *event = [[[TSTimeHistory alloc] initWithTime:[[timeArray objectAtIndex:i] doubleValue]
                                                          timeError:timeError
                                           liveLeapSecondCorrection:liveLeapSecondCorrection
                                                        description:description
                                                        specialType:specialType
                                                 specialTimerNumber:(int)specialTimerNumber
                                                          mediaTime:-1e9
                                                          syncIndex:(int)syncIndex] autorelease];
        if (referenceZeroFlags && i < referenceZeroFlagsCount && [[referenceZeroFlags objectAtIndex:i] boolValue]) {
            event->isReferenceZero = true;
        }
	[pastTimes addObject:event];
    }
    id zeroTimeRefId = [userDefaults objectForKey:@"referenceZeroTime"];
    NSInteger zeroTimeIndex = -1;
    if (zeroTimeRefId) {
	zeroTimeIndex = [zeroTimeRefId integerValue];
        [userDefaults removeObjectForKey:@"referenceZeroTime"];  // This magic should only work once
        //assert([userDefaults objectForKey:@"event-reference-zero-flags"] == nil);  // And if there's magic there shouldn't be non-magic
    }
    NSInteger pastTimesCount = [pastTimes count];
    assert (zeroTimeIndex >= -1 && zeroTimeIndex < pastTimesCount);
    if (zeroTimeIndex >= 0 && zeroTimeIndex < pastTimesCount) {
        TSTimeHistory *event = [pastTimes objectAtIndex:zeroTimeIndex];
	event->isReferenceZero = true;
    }
    currentDescription = [[userDefaults stringForKey:@"current-description"] retain];
    qualifyDescription(&currentDescription);
    // The creation of the calendar should be controlled by a setting (UTC vs local)
    pastDays = [[NSMutableArray alloc] initWithCapacity:timeArrayCount];
    useTTForJD = [userDefaults boolForKey:@"TSUseTTForJD"] ? true : false;  // DO THIS BEFORE LOADING TIME BASE
    setCurrentTimeBase(timeBaseFromString([userDefaults stringForKey:@"TimeBase"]), false/* !alsoRecalculateAccumulatedTimes*/);
    NSArray *readonlyProjectNamesByNumber = [userDefaults arrayForKey:@"project-names"];
    if (readonlyProjectNamesByNumber) {
        projectNamesByNumber = [[NSMutableArray arrayWithArray:readonlyProjectNamesByNumber] retain];
        numTotalProjects = [readonlyProjectNamesByNumber count];
        projectNumbersByName = [[NSMutableDictionary dictionaryWithCapacity:numTotalProjects] retain];
        int projectNumber = 0;
        for (NSString *str in readonlyProjectNamesByNumber) {
            [projectNumbersByName setObject:[NSNumber numberWithInteger:projectNumber] forKey:str];
            projectNumber++;
        }
    } else {
        projectNamesByNumber = [[NSMutableArray arrayWithCapacity:5] retain];
        projectNumbersByName = [[NSMutableDictionary dictionaryWithCapacity:5] retain];
        numTotalProjects = 0;
    }
    allowMultipleReferenceZeroes = [userDefaults boolForKey:@"TSAllowMultZero"];
    [self recalculateAccumulatedTimes];
}

+(void)reloadDefaults {
    assert([NSThread isMainThread]);
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    bool oldTTForJD = useTTForJD;
    useTTForJD = [userDefaults boolForKey:@"TSUseTTForJD"] ? true : false;
    //printf("Reloaded defaults, new useTTForJD is %s\n", useTTForJD ? "true" : "false");
    if (oldTTForJD != useTTForJD) {
        if (oldTTForJD) {
            assert(!useTTForJD);
            // Switching from JD(TT) to JD(UTC)
            if (currentTimeBase == TSTimeBaseJDTT) {
                currentTimeBase = TSTimeBaseJDUTC;
            }
        } else {
            assert(!oldTTForJD);
            assert(useTTForJD);
            // Switching from JD(UTC) to JD(TT)
            if (currentTimeBase == TSTimeBaseJDUTC) {
                currentTimeBase = TSTimeBaseJDTT;
            }
        }
        [TSRootViewController rotateTimeBaseCallback];  // Fake it so we reload the table
    }
    NSTimeInterval newGreenThreshold = [userDefaults doubleForKey:@"TSGreenThreshold"];
    if (newGreenThreshold != greenThreshold) {
        greenThreshold = newGreenThreshold;
        [self recalculateAccumulatedTimes];
    }
}

static NSString *
projectNameForTimerNumber(int timerNumber) {
    int projectNumber = timerNumber - RESERVE_STOPWATCHES;
    assert(projectNumber >= 0);
    assert(projectNumber < numTotalProjects);
    return [projectNamesByNumber objectAtIndex:projectNumber];
}

static int
timerNumberForProjectName(NSString *name) {
    NSNumber *numObj = [projectNumbersByName objectForKey:name];
    if (numObj) {
        return [numObj intValue] + RESERVE_STOPWATCHES;
    }
    assert(false);
    return -1;
}

static int
timerNumberForProjectNameCreatingIfNecessary(NSString *name) {
    NSNumber *numObj = [projectNumbersByName objectForKey:name];
    if (!numObj) {
        numObj = [NSNumber numberWithInteger:numTotalProjects];
        [projectNamesByNumber addObject:name];
        [projectNumbersByName setObject:numObj forKey:name];
        numTotalProjects++;
        [TSTimeHistory saveProjectNameDefaults];
    }
    return [numObj intValue] + RESERVE_STOPWATCHES;
}

+(TSTimeHistory *)addTime:(NSTimeInterval)aTime
            withTimeError:(float)aTimeError
withLiveLeapSecondCorrection:(NSTimeInterval)liveLeapSecondCorrection
          withDescription:(NSString *)aDescription
                mediaTime:(NSTimeInterval)aMediaTime
       skipReconstruction:(bool)skipReconstruction {
    TSTimeHistory *timeDescriptor = [[TSTimeHistory alloc] initWithTime:aTime
                                                              timeError:aTimeError
                                               liveLeapSecondCorrection:liveLeapSecondCorrection
                                                            description:aDescription
                                                            specialType:TSSpecialEventNotSpecial
                                                     specialTimerNumber:0
                                                              mediaTime:aMediaTime
                                                              syncIndex:(int)currentSyncIndex];
    [currentDescription release];
    currentDescription = @" ";
    [pastTimes insertObject:timeDescriptor atIndex:0];
    timeDescriptor->isReferenceZero = ([pastTimes count] == 1);  // First one is always zero
    if (confidenceLevelFromTimeError(aTimeError) != TSConfidenceLevelGreen) {
	[pastTimesSinceMediaTimeReset addObject:timeDescriptor];
    }
    [timeDescriptor release];
    if (!skipReconstruction) {
        reconstructPastDates();
        [self saveDefaults];
    }
    return timeDescriptor;
}

-(TSConfidenceLevel)confidenceLevel {
    if (currentTimeBase == TSTimeBaseInterval) {
        return accumulatedConfidenceLevel;
    } else {
	return confidenceLevelFromTimeError(timeError);
    }
}

// static bool syncIndicesAreIdentical(int syncIndex1,
// 				    int syncIndex2) {
//     return syncIndex1 == syncIndex2 && syncIndex1 != -1;  // -1 means event captured before we started doing sync indices
// }

-(float)timeError {
    //if (currentTimeBase == TSTimeBaseInterval && referenceZeroTime && referenceZeroTime != self && !syncIndicesAreIdentical(syncIndex, referenceZeroTime->syncIndex)) {
    if (currentTimeBase == TSTimeBaseInterval) {
        return accumulatedTimeError;
    } else {
	return timeError;
    }
}

-(bool)toggleDeleteFlag {
    deleteFlag = !deleteFlag;
    return deleteFlag;
}

+(TSTimeHistory *)addTimeAtNow {
    assert(pastTimes);
    NSTimeInterval liveLeapSecondCorrection;
    NSTimeInterval mediaTime = ESTime::currentContinuousTime();
    NSTimeInterval now = ESTime::ntpTimeForCTimeWithLiveCorrection(mediaTime, &liveLeapSecondCorrection);
    return [self addTime:now withTimeError:ESTime::currentTimeError()
                 withLiveLeapSecondCorrection:liveLeapSecondCorrection
                 withDescription:currentDescription mediaTime:mediaTime
                 skipReconstruction:false];
}

+(NSString *)currentDescription {
    return currentDescription;
}

+(void)setCurrentDescription:(NSString *)aCurrentDescription {
    qualifyDescription(&aCurrentDescription);
    [currentDescription release];
    currentDescription = [aCurrentDescription retain];
    [self saveDefaults];
}

+(unsigned int)numberOfPastTimes {
    assert(pastTimes);
    return (unsigned int)[pastTimes count];
}

+(unsigned int)numberOfPastDays 
{
    assert(pastDays);
    return (unsigned int)[pastDays count];
}

+(unsigned int)numberOfPastTimesWithinDay:(unsigned int)withinDay {
    assert(pastDays);
    assert(withinDay < [pastDays count]);
    return (unsigned int)[[pastDays objectAtIndex:withinDay] count];
}

+(bool)firstTwoPastTimesAreOnSameDay {
    assert(pastDays);
    assert([pastTimes count] > 0);
    assert([pastDays count] > 0);
    return [[pastDays objectAtIndex:0] count] > 1;  // If the first day has only 1 element, the second element (if it exists) must be on a different day
}

+(bool)firstPastDayIsTodayOrNil {
    assert(pastDays);
    if ([pastDays count] == 0) {
	return true;
    }
    NSArray *withinDay = [pastDays objectAtIndex:0];
    assert(withinDay);
    assert([withinDay count] > 0);
    TSTimeHistory *timeDesc = [withinDay objectAtIndex:0];
    assert(timeDesc);
    return dateRepFor(timeDesc.time) == dateRepFor(ESTime::currentTime());
}

static bool isAsleep = false;

+(void)goingToSleep {
    isAsleep = true;
}
+(void)wakingUp {
    isAsleep = false;
}

+(TSConfidenceLevel)currentConfidence {
    return isAsleep ? TSConfidenceLevelYellow : confidenceLevelFromTimeError(ESTime::currentTimeError());
}

+(TSTimeHistory *)pastTimeAtOffsetFromPresent:(unsigned int)offsetFromPresent {
    assert(offsetFromPresent < [pastTimes count]);
    TSTimeHistory *timeDesc = [pastTimes objectAtIndex:offsetFromPresent];
    //printf("TSTime printADate sez: ");
    //printADate(timeDesc->time);
    //printf("\n");
    return timeDesc;
}

+(TSTimeHistory *)pastTimeAtOffsetFromPresent:(unsigned int)offsetFromPresent withinDay:(unsigned int)withinDay {
    assert(withinDay < [pastDays count]);
    NSArray *timesWithinDay = [pastDays objectAtIndex:withinDay];
    assert(offsetFromPresent < [timesWithinDay count]);
    TSTimeHistory *timeDesc = [timesWithinDay objectAtIndex:offsetFromPresent];
    //printf("TSTime printADate sez: ");
    //printADate(timeDesc->time);
    //printf("\n");
    return timeDesc;
}

+(int)slotForOffset:(unsigned int)offset withinDay:(unsigned int)withinDay {
    assert(withinDay < [pastDays count]);
    int slot = 1;  // Historically, slots start at 1
    int dayNumber = 0;
    for (NSArray *dayArray in pastDays) {
	if (dayNumber++ < withinDay) {
	    slot += [dayArray count];
	} else {
	    slot += offset;
	    break;
	}
    }
    return slot;
}

+(void)setPastDescriptionAtOffsetFromPresent:(unsigned int)offsetFromPresent description:(NSString *)description {
    assert(offsetFromPresent < [pastTimes count]);
    qualifyDescription(&description);
    TSTimeHistory *timeDesc = [pastTimes objectAtIndex:offsetFromPresent];
    timeDesc.description = description;
    [self saveDefaults];
}

+(void)setPastDescriptionAtOffsetFromPresent:(unsigned int)offsetFromPresent withinDay:(unsigned int)withinDay description:(NSString *)description {
    assert(withinDay < [pastDays count]);
    NSArray *timesWithinDay = [pastDays objectAtIndex:withinDay];
    assert(offsetFromPresent < [timesWithinDay count]);
    TSTimeHistory *timeDesc = [timesWithinDay objectAtIndex:offsetFromPresent];
    timeDesc.description = description;
    [self saveDefaults];
}

-(void)setDescription:(NSString *)desc {
    [description release];
    description = [desc retain];
    [TSTimeHistory saveDefaults];
}

-(void)setSpecialType:(TSSpecialEventType)aSpecialType timerNumber:(int)aSpecialTimerNumber {
    specialType = aSpecialType;
    specialTimerNumber = aSpecialTimerNumber;
    [TSTimeHistory saveDefaults];
}

+(int)timerNumberForProjectName:(NSString *)projectName createIfNecessary:(bool)createIfNecessary {
    if (createIfNecessary) {
        return timerNumberForProjectNameCreatingIfNecessary(projectName);
    } else {
        return timerNumberForProjectName(projectName);
    }
}

+(NSString *)projectNameForTimerNumber:(int)timerNumber {
    return projectNameForTimerNumber(timerNumber);
}

+(bool)timerIsRunning:(int)timerNumber {
    assert(NUM_TOTAL_TIMERS <= timerDatasCapacity);
    if (timerNumber < 0 ||
        timerNumber >= NUM_TOTAL_TIMERS) {
        return false;
    }
    return timerDatas[timerNumber].activeStart != 0;
}

+(void)recalculateAccumulatedTimes {
    if (NUM_TOTAL_TIMERS > timerDatasCapacity) {
        if (timerDatasCapacity) {
            delete timerDatas;
        }
        timerDatas = new TimerData[NUM_TOTAL_TIMERS];
        timerDatasCapacity = NUM_TOTAL_TIMERS;
    }
    float lastNonProjectTimeError;
    float lastNonProjectConfidence;
    int lastNonProjectSyncIndex;
    for (int i = 0; i < NUM_TOTAL_TIMERS; i++) {
        timerDatas[i].reset();
    }
    int lastActiveProjectTimerNumber = -1;
    int lastEffectiveTimerNumber = -1;
    lastNonProjectZero = 0;
    lastNonProjectZeroLiveLeap = 0;
    lastNonProjectSyncIndex = 0;
    TSMasterModeType masterMode = [TSTopOptionsViewController masterMode];
    bool isOldest = true;
    bool foundAReferenceZero = false;
    if (!allowMultipleReferenceZeroes) {
        // We need to find the single reference zero event in the list
        for (TSTimeHistory *timeDescriptor in pastTimes) {
            if (timeDescriptor->isReferenceZero) {
                foundAReferenceZero = true;
                lastNonProjectZero = timeDescriptor->time;
                lastNonProjectZeroLiveLeap = timeDescriptor->liveLeapSecondCorrection;
                lastNonProjectTimeError = timeDescriptor->timeError;
                lastNonProjectConfidence = confidenceLevelFromTimeError(timeDescriptor->timeError);
                lastNonProjectSyncIndex = timeDescriptor->syncIndex;
            }
        }
    }
    for (TSTimeHistory *timeDescriptor in [pastTimes reverseObjectEnumerator]) {
        if (isOldest) {
            if (allowMultipleReferenceZeroes || !foundAReferenceZero) {
                timeDescriptor->isReferenceZero = true;  // Earliest object is always reference zero whether it's set that way or not
            }
            isOldest = false;
        }
        if (timeDescriptor->isReferenceZero) {  // Stopwatch events don't follow this protocol, but a stopwatch event should never be a reference zero
            for (int i = 0; i < NUM_TOTAL_TIMERS; i++) {
                timerDatas[i].reset();  // Not that this always happens for the oldest event because we set isReferenceZero on oldest event
            }
            lastNonProjectZero = timeDescriptor->time;
            lastNonProjectZeroLiveLeap = timeDescriptor->liveLeapSecondCorrection;
            lastNonProjectTimeError = timeDescriptor->timeError;
            lastNonProjectConfidence = confidenceLevelFromTimeError(timeDescriptor->timeError);
            lastNonProjectSyncIndex = timeDescriptor->syncIndex;
        } 
        int timerNumber = timeDescriptor->specialTimerNumber;
        switch(timeDescriptor->specialType) {
          case TSSpecialEventProjectChange:
            {
                assert(timerNumber < 0 || timerNumber >= RESERVE_STOPWATCHES);
                float project1Error = 0;
                TSConfidenceLevel project1Confidence;
                if (lastActiveProjectTimerNumber >= 0) {
                    TimerData *lastTimerData = &timerDatas[lastActiveProjectTimerNumber];
                    if (lastTimerData->activeStart) {
                        lastTimerData->accumulator += ESLeapSecond::intervalBetweenUTCValuesWithLiveLeapCorrections(lastTimerData->activeStart,
                                                                                                                    lastTimerData->activeStartLeap,
                                                                                                                    timeDescriptor->time, timeDescriptor->liveLeapSecondCorrection);
                        lastTimerData->mergeErrorData(timeDescriptor);
                        project1Error = lastTimerData->accumulatedError;
                        project1Confidence = lastTimerData->accumulatedConfidence;
                        timeDescriptor->accumulatedTimeReference = timeDescriptor->time - lastTimerData->accumulator;
                        timeDescriptor->accumulatedTimeReferenceLiveLeap = 0;
                        lastTimerData->activeStart = 0;
                        lastTimerData->activeStartLeap = 0;
                    } else {
                        project1Confidence = confidenceLevelFromTimeError(timeDescriptor->timeError);  // No better than project 2
                        timeDescriptor->accumulatedTimeReference = timeDescriptor->time;
                        timeDescriptor->accumulatedTimeReferenceLiveLeap = timeDescriptor->liveLeapSecondCorrection;
                    }
                    [timeDescriptor setDescription:projectNameForTimerNumber(lastActiveProjectTimerNumber)];
                } else {
                    [timeDescriptor setDescription:@" "];
                }
                if (timerNumber >= 0) {
                    TimerData *newTimerData = &timerDatas[timerNumber];
                    timeDescriptor->accumulatedProject2Time = newTimerData->accumulator;
                    assert(!newTimerData->activeStart);  // How did we manage to get two projects running?
                    newTimerData->activeStart = timeDescriptor->time;
                    newTimerData->activeStartLeap = timeDescriptor->liveLeapSecondCorrection;
                    lastActiveProjectTimerNumber = timerNumber;
                    if (masterMode != TSMasterModeStopwatch) {
                        lastEffectiveTimerNumber = timerNumber;
                    }
                    newTimerData->mergeErrorData(timeDescriptor);
                    timeDescriptor->accumulatedTimeError = fmaxf(project1Error, newTimerData->accumulatedError);
                    timeDescriptor->accumulatedConfidenceLevel =
                        project1Confidence == TSConfidenceLevelGreen && newTimerData->accumulatedConfidence == TSConfidenceLevelGreen
                        ? TSConfidenceLevelGreen
                        : TSConfidenceLevelYellow;
                } else {
                    timeDescriptor->accumulatedConfidenceLevel = project1Confidence;
                    timeDescriptor->accumulatedTimeError = project1Error;
                    lastActiveProjectTimerNumber = -1;
                }
            }
            break;
          case TSSpecialEventStart:  // stopwatch start
            {
                assert(timerNumber < RESERVE_STOPWATCHES);
                TimerData *timerData = &timerDatas[timerNumber];
                timerData->captureTime(timeDescriptor);
                timerData->activeStart = timeDescriptor->time;
                timerData->activeStartLeap = timeDescriptor->liveLeapSecondCorrection;
                if (masterMode != TSMasterModeProject) {
                    lastEffectiveTimerNumber = timerNumber;
                }
            }
            break;
          case TSSpecialEventStop:  // stopwatch stop
            {
                assert(timerNumber < RESERVE_STOPWATCHES);
                TimerData *timerData = &timerDatas[timerNumber];
                timerData->captureTime(timeDescriptor);
                timerData->activeStart = 0;  // Set to not running
                timerData->activeStartLeap = 0;
                if (masterMode != TSMasterModeProject) {
                    lastEffectiveTimerNumber = timerNumber;
                }
            }
            break;
          case TSSpecialEventLap:
            {
                assert(timerNumber < RESERVE_STOPWATCHES);
                TimerData *timerData = &timerDatas[timerNumber];
                // Don't call captureTime here:  This event doesn't affect accuracy of future stop vs past start, so don't merge error data into timerData.  Also don't update accumulator
                NSTimeInterval accumulatedTime = timerData->accumulator;
                if (timerData->activeStart) {  // If running
                    accumulatedTime += ESLeapSecond::intervalBetweenUTCValuesWithLiveLeapCorrections(timerData->activeStart, timerData->activeStartLeap,
                                                                                                     timeDescriptor->time, timeDescriptor->liveLeapSecondCorrection);
                }
                timeDescriptor->accumulatedTimeReference = timeDescriptor->time - accumulatedTime;
                timeDescriptor->accumulatedTimeReferenceLiveLeap = 0;

                timeDescriptor->accumulatedTimeError =
                    timeDescriptor->syncIndex == timerData->lastSyncIndex
                    ? timerData->accumulatedError
                    : timerData->accumulatedError + timeDescriptor->timeError;
                timeDescriptor->accumulatedConfidenceLevel =
                    timerData->accumulatedConfidence == TSConfidenceLevelGreen && confidenceLevelFromTimeError(timeDescriptor->timeError) == TSConfidenceLevelGreen
                    ? TSConfidenceLevelGreen
                    : TSConfidenceLevelYellow;
                if (masterMode != TSMasterModeProject) {
                    lastEffectiveTimerNumber = timerNumber;
                }
            }
            break;
          case TSSpecialEventReset:  // stopwatch reset
            {
                assert(timerNumber < RESERVE_STOPWATCHES);
                TimerData *timerData = &timerDatas[timerNumber];
                timerData->reset();
                timerData->accumulatedError = timeDescriptor->timeError;
                timerData->accumulatedConfidence = confidenceLevelFromTimeError(timeDescriptor->timeError);
                timeDescriptor->accumulatedTimeReference = timeDescriptor->time;
                timeDescriptor->accumulatedTimeReferenceLiveLeap = timeDescriptor->liveLeapSecondCorrection;
                timeDescriptor->accumulatedTimeError = timeDescriptor->timeError;
                timeDescriptor->accumulatedConfidenceLevel = timerData->accumulatedConfidence;
                if (timerData->activeStart) {  // If it was running before, let it continue running
                    timerData->activeStart = timeDescriptor->time;
                    timerData->activeStartLeap = timeDescriptor->liveLeapSecondCorrection;
                } else {
                    assert(timerData->activeStartLeap == 0);
                    timerData->activeStartLeap = 0;
                }
                if (masterMode != TSMasterModeProject) {
                    lastEffectiveTimerNumber = timerNumber;
                }
            }
            break;
          default:
            timeDescriptor->accumulatedTimeReference = lastNonProjectZero;
            timeDescriptor->accumulatedTimeReferenceLiveLeap = lastNonProjectZeroLiveLeap;
            timeDescriptor->accumulatedTimeError =
                timeDescriptor->isReferenceZero
                ? timeDescriptor->timeError
                : (timeDescriptor->syncIndex == lastNonProjectSyncIndex)
                  ? timeDescriptor->timeError
                : lastNonProjectTimeError + timeDescriptor->timeError;
            timeDescriptor->accumulatedConfidenceLevel =
                lastNonProjectConfidence == TSConfidenceLevelGreen && confidenceLevelFromTimeError(timeDescriptor->timeError) == TSConfidenceLevelGreen
                ? TSConfidenceLevelGreen
                : TSConfidenceLevelYellow;
            if (masterMode == TSMasterModeClassic) {
                lastEffectiveTimerNumber = timerNumber;
            }
            break;
        }
    }
}

+(void)removeAllPastTimes {
    [pastTimes removeAllObjects];
    [pastDays removeAllObjects];
    [self saveDefaults];
}

+(void)removePastTimeAtOffsetFromPresent:(unsigned int)offsetFromPresent withinDay:(unsigned int)withinDay {
    assert(withinDay < [pastDays count]);
    NSMutableArray *timesWithinDay = [pastDays objectAtIndex:withinDay];
    assert(offsetFromPresent < [timesWithinDay count]);
    TSTimeHistory *timeDesc = [timesWithinDay objectAtIndex:offsetFromPresent];
    [pastTimes removeObject:timeDesc];
    [timesWithinDay removeObjectAtIndex:offsetFromPresent];
    reconstructPastDates();
    [self recalculateAccumulatedTimes];
    [self saveDefaults];
}

+(void)rotateTimeBase {
    bool *rotateCycleFlags = NULL;
    switch ([TSTopOptionsViewController masterMode]) {
      case TSMasterModeClassic:
        rotateCycleFlags = classicCycleFlags;
        break;
#if 0
      case TSMasterModeStopwatch:
        rotateCycleFlags = stopwatchCycleFlags;
        break;
      case TSMasterModeProject:
        rotateCycleFlags = projectCycleFlags;
        break;
#endif
      default:
        assert(false);
        break;
    }
    TSTimeBase newTimeBase = currentTimeBase;
    int infiniteLoopStopper = 0;  // Should never happen, but yust in case...
    while (1) {
        switch (newTimeBase) {
          case TSTimeBaseLocal12:
            newTimeBase = TSTimeBaseLocal24;
            break;
          case TSTimeBaseLocal24:
            newTimeBase = TSTimeBaseUTC24;
            break;
          case TSTimeBaseUTC24:
            newTimeBase = TSTimeBaseJDTT;
            break;
          case TSTimeBaseJDTT:
            newTimeBase = TSTimeBaseJDUTC;
            break;
          case TSTimeBaseJDUTC:
            newTimeBase = TSTimeBaseInterval;
            break;
          case TSTimeBaseInterval:
          default:
            newTimeBase = TSTimeBaseLocal12;
            break;
        }
        if (rotateCycleFlags[newTimeBase]) {
            break;
        }
        if (infiniteLoopStopper++ > TSNumTimeBases) {
            assert(false);
            newTimeBase = TSTimeBaseLocal12;
            break;
        }
    }
    setCurrentTimeBase(newTimeBase, true/*alsoRecalculateAccumulatedTimes*/);
    [TSRootViewController rotateTimeBaseCallback];
    [TSEventViewController syncStatusChangedInMainThread];
}

static int
daysInYear(NSCalendar     *calendar,
	   NSTimeInterval forTime)
{
    NSDateComponents *cs = [calendar components:(NSCalendarUnitEra|NSCalendarUnitYear) fromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:forTime]];
    [cs setDay:1];
    [cs setMonth:1];
    [cs setHour:0];
    [cs setMinute:0];
    [cs setSecond:0];
    double d1 = [[calendar dateFromComponents:cs] timeIntervalSinceReferenceDate];
    [cs setDay:31];
    [cs setMonth:12];
    [cs setHour:23];
    [cs setMinute:23];
    [cs setSecond:59];
    double d2 = [[calendar dateFromComponents:cs] timeIntervalSinceReferenceDate];
    return rint((d2 - d1) / (3600.0 * 24.0));
}

static NSString *
representationOfDeltaOffsetFromReferenceZero(NSTimeInterval time,
                                             NSTimeInterval liveLeapSecondCorrection,
                                             NSTimeInterval referenceZeroTimeInterval,
                                             NSTimeInterval referenceZeroTimeLiveLeap) {
    // Correct for leap seconds
    //if (time < 318645426.0000) {
    //    printf("leapSecondsDuringInterval %.1f for %.1f to %.1f\n", ESLeapSecond::leapSecondsDuringInterval(referenceZeroTimeInterval, time), referenceZeroTimeInterval, time);
    //}
    time += ESLeapSecond::leapSecondsDuringInterval(referenceZeroTimeInterval, time);
    if (referenceZeroTimeLiveLeap > 1) {
        time -= (referenceZeroTimeLiveLeap - 1);
    }
    if (liveLeapSecondCorrection > 1) {
        time += (liveLeapSecondCorrection - 1);
    }
    if (time == referenceZeroTimeInterval) {
	return @"00:00:00.0";
    }
    NSTimeInterval timeFloor = floor(time);
    NSTimeInterval referenceTimeFloor = floor(referenceZeroTimeInterval);
    NSTimeInterval fractionalDelta = (time - timeFloor) - (referenceZeroTimeInterval - referenceTimeFloor);
    while (fractionalDelta < 0) {
	fractionalDelta += 1.0;
	timeFloor -= 1.0;
    }
    int tenthsOfSeconds = round(fractionalDelta * 10);
    while (tenthsOfSeconds > 9) {
	tenthsOfSeconds -= 10;
	timeFloor += 1.0;
    }
    // OK, here we have tenthsOfSeconds presuming a positive overall delta
    const char *sign;
    NSTimeInterval delta = time - referenceZeroTimeInterval;  // already corrected for leap seconds above
    if ([TSTopOptionsViewController masterMode] == TSMasterModeProject) {
        assert(delta >= 0);
        delta -= tenthsOfSeconds;
        double hours = delta / 3600.0;
        int hoursI = floor(hours);
        double minutes = (hours - hoursI) * 60.0;
        int minutesI = floor(minutes);
        double seconds = (minutes - minutesI) * 60.0;
        int secondsI = floor(seconds);
        return [NSString stringWithFormat:@"%02d:%02d:%02d.%d",
                hoursI, minutesI, secondsI, tenthsOfSeconds];
    }

    NSTimeInterval date1Interval;
    NSTimeInterval date2Interval;
    if (delta > 0) {
        sign = "+";  // We no longer should have negative intervals so no need for the plus
	date1Interval = referenceTimeFloor;
	date2Interval = timeFloor;
    } else {
	sign = "-";
	date1Interval = timeFloor;
	date2Interval = referenceTimeFloor;
	if (tenthsOfSeconds) {
	    date2Interval -= 1.0;
	    tenthsOfSeconds = 10 - tenthsOfSeconds;
	}
    }
    NSDate *date1 = [NSDate dateWithTimeIntervalSinceReferenceDate:date1Interval];
    NSDate *date2 = [NSDate dateWithTimeIntervalSinceReferenceDate:date2Interval];
    //printf("\ndate 1: %s\n", [[date1 description] UTF8String]);
    //printf("date 2: %s\n", [[date2 description] UTF8String]);
    //printf("tenthsOfSeconds = %d\n", tenthsOfSeconds);
    assert(dateFormatter);
    NSCalendar *calendar = utcCalendar;  // Always do date calculations in UTC to avoid TZ oddities
    assert(calendar);
    // The NSCalendar routines have a bug attempting to find the delta between two dates when one is BCE and one is CE.  Possibly other BCE-related bugs too.
    // So we do our own math.  First we find the number of years, then we pick two years with the proper leap/noleap relationship in CE territory, and let the
    // NSCalendar routine do those, then we add the two together.
    NSDateComponents *cs1 = [calendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
					     fromDate:date1];
    NSDateComponents *cs2 = [calendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
					     fromDate:date2];
    NSInteger year1 = cs1.era ? cs1.year : 1 - cs1.year;  // 1 BCE => 0, 2 BCE => -1
    NSInteger year2 = cs2.era ? cs2.year : 1 - cs2.year;  // 1 BCE => 0, 2 BCE => -1
    NSInteger deltaYear = year2 - year1;
    assert(deltaYear >= 0);
    bool year1IsLeap = daysInYear(calendar, [date1 timeIntervalSinceReferenceDate]) > 365.25;
    bool year2IsLeap = daysInYear(calendar, [date2 timeIntervalSinceReferenceDate]) > 365.25;
    // Pick two years always 4 years apart
    if (year1IsLeap) {  // 1900
	if (year2IsLeap) {
	    cs1.year = 2004;  // leap
	    cs2.year = 2008;  // leap
	} else {
	    cs1.year = 1896;  // leap
	    cs2.year = 1900;  // not leap
	}
    } else {
	if (year2IsLeap) {
	    cs1.year = 1900;  // not leap
	    cs2.year = 1904;  // leap
	} else {
	    cs1.year = 2005;  // not leap
	    cs2.year = 2009;  // not leap
	}
    }
    cs1.era = 1;
    cs2.era = 1;
    NSDateComponents *cs
	= [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitDay | NSCalendarUnitYear | NSCalendarUnitEra)
			   fromDate:[calendar dateFromComponents:cs1]
			     toDate:[calendar dateFromComponents:cs2]
			    options:0];
    cs.year += deltaYear - 4;
    if (cs.year != 0) {
	return [NSString stringWithFormat:@"%s%ldy %ldd %02ld:%02ld:%02ld.%01d", sign, (long)cs.year, (long)cs.day, (long)cs.hour, (long)cs.minute, (long)cs.second, tenthsOfSeconds];
    } else if (cs.day != 0) {
	return [NSString stringWithFormat:@"%s%ldd %02ld:%02ld:%02ld.%01d", sign, (long)cs.day, (long)cs.hour, (long)cs.minute, (long)cs.second, tenthsOfSeconds];
    } else {
	return                   [NSString stringWithFormat:@"%s%02ld:%02ld:%02ld.%01d", sign, (long)cs.hour, (long)cs.minute, (long)cs.second, tenthsOfSeconds];
    }
}

static void initializeFormatters() {
#if 0
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSDateFormatter *bogus = [[NSDateFormatter alloc] init];
    [bogus setDateFormat:@"YYYY"];
    for (NSTimeInterval t = now; t < now + 7 * 24 * 3600; t += 3600) {
	NSDate *d = [NSDate dateWithTimeIntervalSinceReferenceDate:t];
	printf("[%s] => %s\n", [[d description] UTF8String], [[bogus stringFromDate:d] UTF8String]);
    }
    [bogus release];
#endif

    dateFormatter = [[NSDateFormatter alloc] init];
    //[dateFormatter setTimeStyle:NSDateFormatterLongStyle];
    //[dateFormatter setDateStyle:NSDateFormatterLongStyle];
    //[dateFormatter setDateFormat:@"h:mm:ss.S a E d MMM yyyy"];
    [dateFormatter setDateFormat:NSLocalizedString(@"E d MMM yyyy", "format pattern for date portion of stamp id; see http://unicode.org/reports/tr35/tr35-6.html#Date_Format_Patterns")];
    timeFormatter = [[NSDateFormatter alloc] init];
    [timeFormatter setDateFormat:NSLocalizedString(@"h:mm:", "format pattern for integer 12-hour time portion of stamp id; see http://unicode.org/reports/tr35/tr35-6.html#Date_Format_Patterns")];
    ampmFormatter = [[NSDateFormatter alloc] init];
    [ampmFormatter setDateFormat:NSLocalizedString(@"a", "format pattern for am/pm")];

    NSTimeZone *tz = [NSTimeZone timeZoneForSecondsFromGMT:0];
    utcCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    [utcCalendar setTimeZone:tz];
}

NSString *descriptionForTimeOnly(NSTimeInterval timeInterval,
                                 NSTimeInterval liveLeapSecondCorrection,
                                 NSTimeInterval referenceZeroTimeInterval,
                                 NSTimeInterval referenceZeroTimeLiveLeap) {
    if (currentTimeBase == TSTimeBaseInterval) {
        return representationOfDeltaOffsetFromReferenceZero(timeInterval, liveLeapSecondCorrection, referenceZeroTimeInterval, referenceZeroTimeLiveLeap);
    }
    if (currentTimeBase == TSTimeBaseJDTT) {
        return [NSString stringWithFormat:NSLocalizedString(@"%.6f JD(TT)", "format pattern for Julian Date (TT)"), julianDateTTForDate(timeInterval, liveLeapSecondCorrection)];
    } else if (currentTimeBase == TSTimeBaseJDUTC) {
        return [NSString stringWithFormat:NSLocalizedString(@"%.6f JD(UTC)", "format pattern for Julian Date (UTC)"), julianDateUTCForDate(timeInterval)];
    }
    double timeFloor = floor(timeInterval);
    ESDateComponents ltcs;
    ESCalendar_localDateComponentsFromTimeInterval(timeInterval, ESCalendar_localTimeZone(), &ltcs);
    double seconds = liveLeapSecondCorrection > 1 ? ltcs.seconds + liveLeapSecondCorrection - 1 : ltcs.seconds;
    int secondsI = floor(seconds);
    double fractionalSeconds = seconds - secondsI;
    int tenthsOfSeconds = round(fractionalSeconds * 10);
    if (tenthsOfSeconds > 9) {
        assert(tenthsOfSeconds == 10);
        tenthsOfSeconds = 0;
        ESAssert(liveLeapSecondCorrection >= 0);
        secondsI++;
        if (liveLeapSecondCorrection == 0) {
            timeFloor += 1;
            if (secondsI == 60) {
                secondsI = 0;
            }
        } else {
            if (secondsI == 61) {
                secondsI = 0;
                timeFloor += 1;
            }
            // Don't bump up timeFloor if secondsI == 60...
        }
    }
    assert(timeFormatter);
    NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:timeFloor];
    NSString *ampmDesc;
    NSCalendar *calendar = [timeFormatter calendar];
    NSString *tzName = [[timeFormatter timeZone] abbreviationForDate:date];
    if ([tzName compare:@"GMT"] == NSOrderedSame ||
	[tzName compare:@"GMT+00:00"] == NSOrderedSame) {
	tzName = @"UTC";
    }
    if (currentTimeBase == TSTimeBaseLocal12) {
	NSString *ampmString = [ampmFormatter stringFromDate:date];
	if ([ampmString length] == 0) {
	    NSDateComponents *dc = [calendar components:(NSCalendarUnitHour) fromDate:date];
	    ampmString = dc.hour < 12 ? NSLocalizedString(@"AM", @"Indicator for AM") : NSLocalizedString(@"PM", @"Indicator for PM");
	}
	ampmDesc = [NSString stringWithFormat:@"%@ %@", ampmString, tzName];
    } else {
	ampmDesc = tzName;
    }
    NSString *timeDesc = [timeFormatter stringFromDate:date];
    return [NSString stringWithFormat:NSLocalizedString(@"%@%02d.%0d %@", "format pattern to compose date and time from integer time portion, fractional seconds, am/pm"), timeDesc, secondsI, tenthsOfSeconds, ampmDesc];
}

NSString *descriptionForTimeOnlyForTimerNumber(NSTimeInterval timeInterval,
                                               NSTimeInterval liveLeapSecondCorrection,
                                               NSInteger      timerNumber) {
    if (timerNumber < 0) {
        NSTimeInterval referenceZeroTimeInterval;
        NSTimeInterval referenceZeroTimeLiveLeap;
        if (lastNonProjectZero) {
            referenceZeroTimeInterval = lastNonProjectZero;
            referenceZeroTimeLiveLeap = lastNonProjectZeroLiveLeap;
        } else {
            referenceZeroTimeInterval = timeInterval;
            referenceZeroTimeLiveLeap = liveLeapSecondCorrection;
        }
        return descriptionForTimeOnly(timeInterval, liveLeapSecondCorrection,
                                      referenceZeroTimeInterval, referenceZeroTimeLiveLeap);
    }
    assert(timerNumber >= 0);
    assert(timerNumber < NUM_TOTAL_TIMERS);
    assert(NUM_TOTAL_TIMERS <= timerDatasCapacity);
    TimerData *timerData = &timerDatas[timerNumber];
    NSTimeInterval referenceTime;
    NSTimeInterval referenceLiveLeap;
    if (timerData->activeStart) {  // Timer is running
        referenceTime = timerData->activeStart - timerData->accumulator;
        referenceLiveLeap = timerData->activeStartLeap;
    } else {
        referenceTime = timeInterval - timerData->accumulator;
        referenceLiveLeap = 0;
    }
    return descriptionForTimeOnly(timeInterval, liveLeapSecondCorrection,
                                  referenceTime, referenceLiveLeap);
}

NSString *descriptionForDateOnly(NSTimeInterval timeInterval) {
    double timeFloor = floor(timeInterval);
    double fractionalSeconds = timeInterval - timeFloor;
    int tenthsOfSeconds = round(fractionalSeconds * 10);
    if (tenthsOfSeconds == 10) {
	//tenthsOfSeconds = 0; // assignment not needed here, never used
	timeFloor += 1.0;
    }
    assert(dateFormatter);
    NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:timeFloor];
    NSString *dateDesc = [dateFormatter stringFromDate:date];
    return dateDesc;
}

// We presume Excel can't handle leap second representations of the form 23:59:60.3 unless in JD(TT)
NSString *descriptionForTimeAndDateForExcel(NSTimeInterval timeInterval,
                                            NSTimeInterval liveLeapSecondCorrection,
                                            NSTimeInterval referenceZeroTimeInterval,
                                            NSTimeInterval referenceZeroTimeLiveLeap,
					    TSTimeBase     timeBase) {
    if (timeBase == TSTimeBaseInterval) {
        assert(referenceZeroTimeInterval);
	if (referenceZeroTimeInterval) {
	    double delta = ESLeapSecond::intervalBetweenUTCValues(referenceZeroTimeInterval, timeInterval);
            if (referenceZeroTimeLiveLeap > 1) {
                delta -= (referenceZeroTimeLiveLeap - 1);
            }
            if (liveLeapSecondCorrection > 1) {
                delta += (liveLeapSecondCorrection - 1);
            }
	    const char *sign;
	    if (delta == 0) {
		return @"00:00:00.0";
	    } else if (delta > 0) {
		sign = "";
	    } else {
		sign = "-";
		delta = -delta;
	    }
	    double hours = delta / 3600;
	    int hoursT = (int)floor(hours);
	    double hoursF = hours - hoursT;
	    double minutes = hoursF * 60;
	    int minutesT = (int)floor(minutes);    // integer part of minutes
	    double minutesF = minutes - minutesT;  // fraction part of minutes
	    double seconds = minutesF * 60;
	    int secondsT = (int)floor(seconds);
	    double secondsF = seconds - secondsT;
	    int tenthsR = (int)rint(secondsF * 10);
	    if (tenthsR > 9) {
		tenthsR -= 10;
		secondsT++;
		if (secondsT > 59) {
		    minutesT++;
		    if (minutesT > 59) {
			hoursT++;
		    }
		}
	    }
	    // Format in Excel is [h]:mm:ss.00 for intervals with arbitrarily large hours
	    return [NSString stringWithFormat:@"%s%d:%02d:%02d.%d", sign, hoursT, minutesT, secondsT, tenthsR];
	} else {
	    return @"00:00:00.0";
	}
    }
    if (timeBase == TSTimeBaseJDTT) {
	return [NSString stringWithFormat:@"%.6f", julianDateTTForDate(timeInterval, liveLeapSecondCorrection)];
    } else if (timeBase == TSTimeBaseJDUTC) {
	return [NSString stringWithFormat:@"%.6f", julianDateUTCForDate(timeInterval)];
    }
    static NSDateFormatter *dateFormatterLocalForExcel = nil;
    static NSDateFormatter *dateFormatterUTCForExcel = nil;
    if (!dateFormatterLocalForExcel) {
	dateFormatterLocalForExcel = [[NSDateFormatter alloc] init];
	[dateFormatterLocalForExcel setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
	dateFormatterUTCForExcel = [[NSDateFormatter alloc] init];
	[dateFormatterUTCForExcel setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
	NSTimeZone *tz = [NSTimeZone timeZoneForSecondsFromGMT:0];
	NSCalendar *calendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
	[calendar setTimeZone:tz];
	[dateFormatterUTCForExcel setTimeZone:tz];
	[dateFormatterUTCForExcel setCalendar:calendar];
    }
    double timeFloor = floor(timeInterval);
    double fractionalSeconds = timeInterval - timeFloor;
    int tenthsOfSeconds = round(fractionalSeconds * 10);
    if (tenthsOfSeconds == 10) {
	tenthsOfSeconds = 0;
	timeFloor += 1.0;
    }
    NSDateFormatter *dateFormatter = (timeBase == TSTimeBaseUTC24) ? dateFormatterUTCForExcel : dateFormatterLocalForExcel;
    return [NSString stringWithFormat:@"%@.%d", [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:timeFloor]], tenthsOfSeconds];
}

NSString *descriptionForEventDetailHeader(NSTimeInterval timeInterval,
                                          NSTimeInterval liveLeapSecondCorrection,
                                          NSTimeInterval referenceZeroTimeInterval,
                                          NSTimeInterval referenceZeroTimeLiveLeap) {
    if (currentTimeBase == TSTimeBaseInterval) {
	currentTimeBase = TSTimeBaseLocal12;
	NSString *returnString = [NSString stringWithFormat:@"%@ %@",
                                           descriptionForDateOnly(timeInterval),
                                           descriptionForTimeOnly(timeInterval, liveLeapSecondCorrection, referenceZeroTimeInterval, referenceZeroTimeLiveLeap)];
	currentTimeBase = TSTimeBaseInterval;
	return returnString;
    } else {
	return descriptionForDateOnly(timeInterval);
    }
}

static void setCurrentTimeBase(TSTimeBase timeBase,
                               bool       alsoRecalculateAccumulatedTimes) {
    currentTimeBase = timeBase;
    if (!dateFormatter) {
	initializeFormatters();
    }
    NSTimeZone *tz;
    if (timeBase == TSTimeBaseUTC24) {
	tz = [NSTimeZone timeZoneForSecondsFromGMT:0];
    } else {
	tz = [NSTimeZone defaultTimeZone];
    }
    // The following bogus objects are to work around a bug introduced in iOS 7 where changing a timezone
    // after the app has been started failed to work properly, presumably because of an inappropriate
    // comparison when the timezone was changed.  We force a change by setting the timezone (and calendar)
    // to bogus values and then back to the correct ones.
    NSCalendar *bogusCalendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierBuddhist] autorelease];
    NSTimeZone *bogusTimeZone = [NSTimeZone timeZoneForSecondsFromGMT:42];
    NSCalendar *calendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    [calendar setTimeZone:bogusTimeZone];
    [calendar setTimeZone:tz];
    [dateFormatter setTimeZone:bogusTimeZone];
    [dateFormatter setTimeZone:tz];
    [timeFormatter setTimeZone:bogusTimeZone];
    [timeFormatter setTimeZone:tz];
    [ampmFormatter setTimeZone:bogusTimeZone];
    [ampmFormatter setTimeZone:tz];
    [dateFormatter setCalendar:bogusCalendar];
    [dateFormatter setCalendar:calendar];
    [timeFormatter setCalendar:bogusCalendar];
    [timeFormatter setCalendar:calendar];
    [ampmFormatter setCalendar:bogusCalendar];
    [ampmFormatter setCalendar:calendar];
    if (timeBase == TSTimeBaseLocal12) {
	[timeFormatter setDateFormat:NSLocalizedString(@"h:mm:", "format pattern for integer 12-hour time portion of stamp id; see http://unicode.org/reports/tr35/tr35-6.html#Date_Format_Patterns")];
    } else {
	[timeFormatter setDateFormat:NSLocalizedString(@"HH:mm:", "format pattern for integer 24-hour time portion of stamp id; see http://unicode.org/reports/tr35/tr35-6.html#Date_Format_Patterns")];
    }
    reconstructPastDates();  // Do after setting current time base...
    if (alsoRecalculateAccumulatedTimes) {
        [TSTimeHistory recalculateAccumulatedTimes];
    }
    [[NSUserDefaults standardUserDefaults] setObject:stringFromTimeBase(currentTimeBase) forKey:@"TimeBase"];
//    if (startOfMainComplete) {
//        [TSTimeHistory printAllTimes];
//    }
}

+ (TSTimeBase)currentTimeBase {
    return currentTimeBase;
}

class TSTimeSyncObserver : public ESTimeSyncObserver {
  public:
                            TSTimeSyncObserver()
    :   ESTimeSyncObserver(ESThread::mainThread())
    {}
    virtual void            syncValueChanged();
    virtual void            syncStatusChanged();
    virtual void            continuousTimeReset();
};

    // There was a (potential) jump in the absolute time
/*virtual*/ void 
TSTimeSyncObserver::syncValueChanged() {
    assert([NSThread isMainThread]);
    tracePrintf2("TSTimeSyncObserver::syncValueChanged(), time error %.4f, source is %s", ESTime::currentTimeError(), ESTime::currentTimeSourceName().c_str());
    float currentTimeError = ESTime::currentTimeError();
    for (TSTimeHistory *timeDesc in pastTimesSinceMediaTimeReset) {
	if (timeDesc.timeError > currentTimeError) {
	    timeDesc->time = ESTime::ntpTimeForCTime(timeDesc->mediaTime);
	    timeDesc->timeError = currentTimeError;
	}
    }
    [TSTimeHistory saveDefaults];
    [TSRootViewController syncStatusChangedInMainThread];
    [TSEventViewController syncStatusChangedInMainThread];
}

   // There was a change in the time source status (useful for indicators)
/*virtual*/ void 
TSTimeSyncObserver::syncStatusChanged() {
    assert([NSThread isMainThread]);
    tracePrintf2("TSTimeSyncObserver::syncStatusChanged() to %s, source is %s", ESTime::currentStatusEngrString().c_str(), ESTime::currentTimeSourceName().c_str());
    [TSRootViewController syncStatusChangedInMainThread];
    [TSEventViewController syncStatusChangedInMainThread];
    //printf("TSTH notifySyncStatusChanged to: %s\n", [[[ECTS statusText] stringByReplacingOccurrencesOfString:@"\n" withString:@" "] UTF8String]);
}

 // There was a (potential) jump in the continuous time
/*virtual*/ void 
TSTimeSyncObserver::continuousTimeReset() {
    assert([NSThread isMainThread]);
    currentSyncIndex++;
    [pastTimesSinceMediaTimeReset removeAllObjects];
}

+ (bool)eventIsReferenceZeroAtOffsetFromPresent:(unsigned int)offsetFromPresent withinDay:(unsigned int)withinDay {
    TSTimeHistory *thatEvent = [self pastTimeAtOffsetFromPresent:offsetFromPresent withinDay:withinDay];
    return (thatEvent->isReferenceZero);
}

+ (bool)eventIsReferenceZero:(TSTimeHistory *)event {
    return event->isReferenceZero;
}

+ (void)toggleReferenceZeroForEvent:(TSTimeHistory *)event {
    if (event->isReferenceZero) {
        if (!allowMultipleReferenceZeroes) {
            return;  // Can't turn it off
        }
        event->isReferenceZero = false;
    } else {
        // Find the previous one and turn it off
        if (!allowMultipleReferenceZeroes) {
            for (TSTimeHistory *timeDescriptor in pastTimes) {
                if (timeDescriptor->isReferenceZero) {
                    assert(timeDescriptor != event);  // Otherwise it would be caught with the first check in this method
                    timeDescriptor->isReferenceZero = false;
                }
            }
        }
        event->isReferenceZero = true;
    }
    [self saveDefaults];
    [self recalculateAccumulatedTimes];
}

+ (void)toggleReferenceZeroForEventAtOffsetFromPresent:(unsigned int)offsetFromPresent withinDay:(unsigned int)withinDay {
    TSTimeHistory *thatEvent = [self pastTimeAtOffsetFromPresent:offsetFromPresent withinDay:withinDay];
    [self toggleReferenceZeroForEvent:thatEvent];
}

+ (bool)allowMultipleReferenceZeroes {
    return allowMultipleReferenceZeroes;
}

+ (void)setAllowMultipleReferenceZeroes:(bool)newAllowMultipleAllowReferenceZeroes {
    if (newAllowMultipleAllowReferenceZeroes != allowMultipleReferenceZeroes) {
        if (!newAllowMultipleAllowReferenceZeroes) {
            // Keep the newest reference zero (on the theory it's the most interesting)
            bool foundOne = false;
            for (TSTimeHistory *timeDescriptor in pastTimes) {
                if (timeDescriptor->isReferenceZero) {
                    if (foundOne) {
                        timeDescriptor->isReferenceZero = false;
                    } else {
                        foundOne = true;
                    }
                }
            }
        } // else recalculateAccumulatedTimes will turn the oldest one on
        allowMultipleReferenceZeroes = newAllowMultipleAllowReferenceZeroes;
        [self saveDefaults];
        [self recalculateAccumulatedTimes];
    }
}

+ (void)toggleDeleteFlagForRow:(unsigned int)row withinDay:(unsigned int)withinDay {
    TSTimeHistory *event = [self pastTimeAtOffsetFromPresent:row withinDay:withinDay];
    event->deleteFlag = !event->deleteFlag;
}

+ (void)clearAllDeleteFlags {
    for (TSTimeHistory *timeDescriptor in pastTimes) {
        timeDescriptor->deleteFlag = false;
    }
}

// Returns empty sections to be deleted in UI
+ (NSIndexSet *)deleteFlaggedTimes {
    NSMutableIndexSet *setOfAllTimeIndices = [NSMutableIndexSet indexSet];
    int allTimeIndex = 0;
    int dayIndex = 0;
    NSMutableIndexSet *daysThatAreNowEmpty = [NSMutableIndexSet indexSet];
    for (NSArray *timesWithinDay in pastDays) {
        bool foundTimeNotDeleted = false;
        for (TSTimeHistory *timeDesc in timesWithinDay) {
            if ([timeDesc deleteFlag]) {
                [setOfAllTimeIndices addIndex:allTimeIndex];
            } else {
                foundTimeNotDeleted = true;
            }
            allTimeIndex++;
        }
        if (!foundTimeNotDeleted) {
            [daysThatAreNowEmpty addIndex:dayIndex];
        }
        dayIndex++;
    }
    [pastTimes removeObjectsAtIndexes:setOfAllTimeIndices];                                              
    reconstructPastDates();
    [self recalculateAccumulatedTimes];
    [self saveDefaults];
    return daysThatAreNowEmpty;
}

-(void)printTimeAtIndex:(int)indx {
    printf("...%3d %3d %20s %20s %3.1f %5.3f %5.3f %s\n",
           indx, syncIndex, [descriptionForTimeOnly(time, liveLeapSecondCorrection, 0, 0) UTF8String], [descriptionForTimeOnly(mediaTime, 0, 0, 0) UTF8String], liveLeapSecondCorrection,
           timeError, accumulatedTimeError, [description UTF8String]);
}

+(void)printAllTimes {
    int indx = 0;
    for (TSTimeHistory *event in pastTimes) {
        [event printTimeAtIndex:indx++];
    }    
}

#undef LOAD_DEMO
#undef LOAD_DEMO_VARIANT5  // Make sure iPhone screencaps are done in landscape for VARIANT5, and load up Custom1-Custom5 buttons
#undef LOAD_DEMO_VARIANT4
#undef LOAD_DEMO_VARIANT3  // Repeated J2000 events, ???, not currently using this
#undef LOAD_DEMO_VARIANT2  // Leap second, confusing, not currently using this
#undef LOAD_DEMO_VARIANT
#ifdef LOAD_DEMO
+ (void)addDemoTimeAtYear:(int)year month:(int)month day:(int)day hour:(int)hour minute:(int)minute second:(int)second fraction:(double)fraction error:(float)error
                 liveLeapSecondCorrection:(double)liveLeapSecondCorrection description:(NSString *)description {
    NSCalendar *calendar = [dateFormatter calendar];
    NSDateComponents *cs = [[NSDateComponents alloc] init];
    cs.year = year;
    cs.month = month;
    cs.day = day;
    cs.hour = hour;
    cs.minute = minute;
    cs.second = second;
    NSTimeInterval dateTime = [[calendar dateFromComponents:cs] timeIntervalSinceReferenceDate];
    dateTime += fraction;
    [self addTime:dateTime withTimeError:error withLiveLeapSecondCorrection:liveLeapSecondCorrection withDescription:description mediaTime:0 skipReconstruction:false];
}

#ifdef LOAD_DEMO_VARIANT3
+ (void)addEventEverySecondBeginningAtYear:(int)year
                                     month:(int)month
                                       day:(int)day
                                      hour:(int)hour
                                    minute:(int)minute
                                    second:(int)second
                                  fraction:(double)fraction
                            numberOfEvents:(int)numberOfEvents
                                     error:(float)error
                               description:(NSString *)description {
    NSCalendar *calendar = [dateFormatter calendar];
    NSDateComponents *cs = [[NSDateComponents alloc] init];
    cs.year = year;
    cs.month = month;
    cs.day = day;
    cs.hour = hour;
    cs.minute = minute;
    cs.second = second;
    NSTimeInterval dateTime = [[calendar dateFromComponents:cs] timeIntervalSinceReferenceDate];
    dateTime += fraction;

    for (int i = 0; i < numberOfEvents; i++) {
        if ((i % 100) == 0) {
            printf("Adding event %d\n", i);
        }
        NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
        [self addTime:(dateTime + i) withTimeError:error withLiveLeapSecondCorrection:0 withDescription:description mediaTime:0 skipReconstruction:true];
        [pool release];
    }
    reconstructPastDates();
    [self saveDefaults];
}
#endif

+ (void)loadDemo {
    [pastTimes removeAllObjects];
    [pastTimesSinceMediaTimeReset removeAllObjects];
#ifdef LOAD_DEMO_VARIANT5
    if (isIpad()) {
        [self addDemoTimeAtYear:2013 month:12 day:31 hour:15 minute:59 second:54 fraction:0.7 error:0.1 liveLeapSecondCorrection:0 description:@"Preload custom descriptions"];
        [self addDemoTimeAtYear:2013 month:12 day:31 hour:15 minute:59 second:55 fraction:0.7 error:0.1 liveLeapSecondCorrection:0 description:@"Custom 3"];
        [self addDemoTimeAtYear:2013 month:12 day:31 hour:15 minute:59 second:56 fraction:0.7 error:0.1 liveLeapSecondCorrection:0 description:@"Custom 5"];
        [self addDemoTimeAtYear:2013 month:12 day:31 hour:15 minute:59 second:57 fraction:0.7 error:0.1 liveLeapSecondCorrection:0 description:@"Custom 2"];
        [self addDemoTimeAtYear:2013 month:12 day:31 hour:15 minute:59 second:58 fraction:0.7 error:0.1 liveLeapSecondCorrection:0 description:@"Custom 4"];
        [self addDemoTimeAtYear:2013 month:12 day:31 hour:15 minute:59 second:59 fraction:0.7 error:0.1 liveLeapSecondCorrection:0 description:@"Custom 1"];
    } else {
        [self addDemoTimeAtYear:2013 month:12 day:31 hour:15 minute:59 second:55 fraction:0.7 error:0.1 liveLeapSecondCorrection:0 description:@"Custom 3 - Preload custom descriptions"];
    }
#else
#ifdef LOAD_DEMO_VARIANT4
    if (isIpad()) {
        [self addDemoTimeAtYear:2013 month:12 day:31 hour:15 minute:59 second:56 fraction:0.7 error:0.1 liveLeapSecondCorrection:0 description:@" "];
        [self addDemoTimeAtYear:2013 month:12 day:31 hour:15 minute:59 second:57 fraction:0.7 error:0.1 liveLeapSecondCorrection:0 description:@" "];
        [self addDemoTimeAtYear:2013 month:12 day:31 hour:15 minute:59 second:59 fraction:0.7 error:0.1 liveLeapSecondCorrection:0 description:@"Times can be shown in UTC or Julian Date for astronomical purposes"];
    } else {
        [self addDemoTimeAtYear:2013 month:12 day:31 hour:15 minute:59 second:59 fraction:0.7 error:0.1 liveLeapSecondCorrection:0 description:@"JD & UTC for astro events"];
    }
    [self addDemoTimeAtYear:2013 month:12 day:31 hour:18 minute:59 second:55 fraction:0.7 error:0.1 liveLeapSecondCorrection:0 description:@" "];
#else
#ifdef LOAD_DEMO_VARIANT3
    //January 1, 2000, 11:58:55.816 UTC  Test that it comes out to the J2000 epoch, 2451545.0 TT
    //That's 03:58:55.816 PST
    [self addEventEverySecondBeginningAtYear:2000 month:1 day:1 hour:11 minute:58  second:55 fraction:0.816 numberOfEvents:3000 error:0.1 description:@"J2000 reference"];
#else
#ifdef LOAD_DEMO_VARIANT2
    [self addDemoTimeAtYear:2008 month:12 day:31 hour:15 minute:59 second:58 fraction:0.7 error:0.1 liveLeapSecondCorrection:0 description:@"0.3s before the leap second"];
    [self addDemoTimeAtYear:2008 month:12 day:31 hour:16 minute:0  second:1  fraction:0.3 error:0.1 liveLeapSecondCorrection:0 description:@"3.3s after the leap second"];
    [self addDemoTimeAtYear:2012 month:6  day:30 hour:16 minute:59 second:59 fraction:0.7 error:0.1 liveLeapSecondCorrection:0 description:@"0.3s before the leap second (2)"];
    [self addDemoTimeAtYear:2012 month:6  day:30 hour:17 minute:0  second:1  fraction:0.3 error:0.1 liveLeapSecondCorrection:0 description:@"2.3s after the leap second (2)"];
#else
#ifdef LOAD_DEMO_VARIANT
    [self addDemoTimeAtYear:2010 month:7 day:1 hour:12 minute:1  second:23 fraction:0.7 error:0.1 liveLeapSecondCorrection:0 description:@" "];
    //if (isIpad()) {
	[self addDemoTimeAtYear:2010 month:7 day:1 hour:13 minute:1  second:19 fraction:0.5 error:0.1 liveLeapSecondCorrection:0 description:@" "];
	[self addDemoTimeAtYear:2010 month:7 day:1 hour:13 minute:3  second:16 fraction:0.0 error:0.1 liveLeapSecondCorrection:0 description:@"Any event can be zero"];
    //}
    [self addDemoTimeAtYear:2010 month:7 day:2 hour:6  minute:15 second:0 fraction:0.8  error:0.1 liveLeapSecondCorrection:0 description:isIpad() ? @" " : @" "];
    [self addDemoTimeAtYear:2010 month:7 day:3 hour:6  minute:15 second:44 fraction:0.2 error:0.1 liveLeapSecondCorrection:0 description:isIpad() ? @" " : @" "];
#else
    if (isIpad()) {
	[self addDemoTimeAtYear:2010 month:5 day:9 hour:23 minute:30 second:15 fraction:0.2 error:0.1 liveLeapSecondCorrection:0 description:@"Submitted Emerald Timestamp to app store"];
    }
    [self addDemoTimeAtYear:2010 month:7 day:1 hour:12 minute:1  second:23 fraction:0.7 error:0.1 liveLeapSecondCorrection:0 description:@"Race starts"];
    //if (isIpad()) {
	[self addDemoTimeAtYear:2010 month:7 day:1 hour:13 minute:1  second:19 fraction:0.5 error:0.1 liveLeapSecondCorrection:0 description:@"Boat 1 finishes"];
	[self addDemoTimeAtYear:2010 month:7 day:1 hour:13 minute:3  second:16 fraction:0.0 error:0.1 liveLeapSecondCorrection:0 description:@"Boat 2 finishes"];
    //}
    [self addDemoTimeAtYear:2010 month:7 day:2 hour:6  minute:15 second:0 fraction:0.8  error:0.1 liveLeapSecondCorrection:0 description:isIpad() ? @"Mechanical clock reads 6:15:00" : @"Mech clock 6:15:00"];
    [self addDemoTimeAtYear:2010 month:7 day:3 hour:6  minute:15 second:44 fraction:0.2 error:0.1 liveLeapSecondCorrection:0 description:isIpad() ? @"Mechanical clock reads 6:15:00" : @"Mech clock 6:15:00"];
#endif
#endif
#endif
#endif
#endif
}
#endif

static TSTimeSyncObserver *theSyncObserver;

+ (void)startOfMain {
    //stateLock = [[NSLock alloc] init];
    [self registerDefaults];
    [self loadDefaults];
    currentSyncIndex++;  // Do this after loadDefaults to ensure sync index is different than the last time we ran
#ifdef LOAD_DEMO
    [self loadDemo];
#endif
    ESTime::startOfMain("TS");
    theSyncObserver = new TSTimeSyncObserver;
#ifdef ES_FAKE_TIME
    ESDateComponents dc;
    dc.era = 1;
    dc.year = 2012;
    dc.month = 6;
    dc.day = 30;
    dc.hour = 23;
    dc.minute = 59;
    dc.seconds = 45;
    ESTimeInterval fakeTime = ESCalendar_timeIntervalFromUTCDateComponents(&dc);
    ESTimeInterval fakeError = 1.0;  // Maybe the yellow will help keep us from releasing this code as real...
    ESTime::init(ESFakeMakerFlag, fakeTime, fakeError);
#else
    ESTime::init(ESNTPMakerFlag);
#endif
    ESTime::registerTimeSyncObserver(theSyncObserver);

    new ESLocationTimeHelper;  // Tell the NTP driver what country we think we're in (physically; it determines device locale without this).  Note that this requires Location Services so observe user settings here

    startOfMainComplete = true;
}

   
@end
