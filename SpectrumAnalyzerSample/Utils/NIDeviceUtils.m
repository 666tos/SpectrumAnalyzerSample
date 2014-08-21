//
//  NIDeviceUtils.m
//
//  Created by Nikita Ivaniushchenko on 4/16/14.
//

#import "NIDeviceUtils.h"

static NIDeviceUtils *sInstance = nil;

@interface NIDeviceUtils()

@property (nonatomic, readwrite) BOOL isRunningOnIPad;
@property (nonatomic, readwrite) BOOL isRunningOnIPod;
@property (nonatomic, readwrite) BOOL isRunningOnIOS7;
@property (nonatomic, readwrite) BOOL isRunningOn3_5Inch;
@property (nonatomic, readwrite) CGFloat screenScale;

@end

@implementation NIDeviceUtils

+ (NIDeviceUtils *)instance
{
    if (sInstance != nil)
    {
        return sInstance;
    }
    
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate, ^
    {
        sInstance = [[self alloc] init];
    });
    
    return sInstance;
}

- (id)init
{
    if (self = [super init])
    {
        _isRunningOnIPad = ([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPhone);
        _isRunningOnIPod = ([[UIDevice currentDevice].model rangeOfString:@"iPod"].location != NSNotFound);
        _isRunningOnIOS7 = ([UIDevice currentDevice].systemVersion.floatValue >= 7.f);
        _isRunningOn3_5Inch = ([UIScreen mainScreen].bounds.size.height == 480.f);
        _screenScale = ([UIScreen mainScreen].scale);
    }
    
    return self;
}

@end
