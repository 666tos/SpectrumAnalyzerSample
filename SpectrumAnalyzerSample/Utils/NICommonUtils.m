//
//  NICommonUtils.m
//
//  Created by Nikita Ivaniushchenko on 6/4/14.
//

#import "NICommonUtils.h"

@implementation NICommonUtils

+ (BOOL)isCMTimeNumberic:(CMTime)time
{
    return CMTIME_IS_NUMERIC(time);
}

+ (BOOL)isCMTimeValid:(CMTime)time
{
    return CMTIME_IS_VALID(time);
}

+ (NSTimeInterval)secondsFromCMTime:(CMTime)time
{
    if ([self isCMTimeValid:time])
    {
        return CMTimeGetSeconds(time);
    }
    
    return 0.0;
}

@end
