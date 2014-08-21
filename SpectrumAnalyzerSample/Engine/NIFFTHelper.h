//
//  NIFFTHelper.h
//
//  Created by Nikita Ivaniushchenko on 6/4/14.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>

typedef void(^NIFFTHelperCompletionBlock)(NSArray *fftData);

@interface NIFFTHelper : NSObject

- (instancetype)initWithNumberOfSamples:(UInt32)numberOfSamples;
- (void)performComputation:(AudioBufferList *)bufferListInOut completionHandler:(NIFFTHelperCompletionBlock)completion;

@end

UInt32 Log2Ceil(UInt32 x);
