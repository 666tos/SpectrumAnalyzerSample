//
//  NIDeviceUtils.h
//
//  Created by Nikita Ivaniushchenko on 4/16/14.
//

#import <Foundation/Foundation.h>

@interface NIDeviceUtils : NSObject

+ (NIDeviceUtils *)instance;

@property (nonatomic, readonly) BOOL isRunningOnIPad;
@property (nonatomic, readonly) BOOL isRunningOnIPod;
@property (nonatomic, readonly) BOOL isRunningOnIOS7;
@property (nonatomic, readonly) BOOL isRunningOn3_5Inch;
@property (nonatomic, readonly) CGFloat screenScale;

@end
