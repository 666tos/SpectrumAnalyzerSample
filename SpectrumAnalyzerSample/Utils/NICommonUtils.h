//
//  NICommonUtils.h
//
//  Created by Nikita Ivaniushchenko on 6/4/14.
//

#import <CoreMedia/CoreMedia.h>

@interface NICommonUtils : NSObject

+ (BOOL)isCMTimeNumberic:(CMTime)time;
+ (BOOL)isCMTimeValid:(CMTime)time;

+ (NSTimeInterval)secondsFromCMTime:(CMTime)time;

@end