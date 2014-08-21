//
//  NIAudioManager.h
//
//  Created by Nikita Ivaniushchenko on 6/4/14.
//

#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>

extern NSString *const NIAudioManagerDidStartPlayNotification;
extern NSString *const NIAudioManagerDidChangeProgressNotification;
extern NSString *const NIAudioManagerDidStopNotification;
extern NSString *const NIAudioManagerDidChangeMixNotification;

extern NSString *const NIAudioManagerDidChangeSpectrumData;
extern NSString *const NIAudioManagerSpectrumDataKey;

extern NSString *const NIAudioManagerStopReasonKey;

typedef NS_ENUM(NSInteger, NIAudioManagerStopReason) {
    
    NIAudioManagerDidPlayToEnd,
    NIAudioManagerFailedToPlayToEnd,
    NIAudioManagerWillChangeMix,
    NIAudioManagerPaused
};

@protocol NIAudioManagerDelegate;

@interface NIAudioManager : NSObject

@property (nonatomic, strong) AVPlayerItem *playerItem;

@property (nonatomic, weak) id<NIAudioManagerDelegate> delegate;
@property (nonatomic, strong) NSURL *fileToPlay;
@property (nonatomic, assign) float progress;
@property (nonatomic, assign) BOOL paused;

- (void)updateSpectrumDataWithData:(NSArray *)data;

+ (NIAudioManager *)defaultManager;

- (void)setFileToPlay:(NSURL *)fileToPlay paused:(BOOL)aPaused;

- (void)togglePlayPause;
- (void)playNext;
- (void)playPrev;

- (NSTimeInterval)duration;
- (NSTimeInterval)currentTime;
- (NSTimeInterval)currentTimeLeft;

- (CMTime)timeForProgress:(float)progress;

@end

@protocol NIAudioManagerDelegate

- (NSURL *)nextFileToPlay;
- (NSURL *)prevFileToPlay;

@end