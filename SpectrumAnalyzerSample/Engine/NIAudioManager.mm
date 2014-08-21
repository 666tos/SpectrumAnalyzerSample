//
//  NIAudioManager.mm
//
//  Created by Nikita Ivaniushchenko on 6/4/14.
//


#import "NIAudioManager.h"

#import "NICommonUtils.h"

#import <MediaToolbox/MediaToolbox.h>
#import <Accelerate/Accelerate.h>

#import "NIFFTHelper.h"

#include <vector>

#define DEFINE_CONST_NSSTRING(name) NSString * const name = @#name

DEFINE_CONST_NSSTRING(NIAudioManagerDidStartPlayNotification);
DEFINE_CONST_NSSTRING(NIAudioManagerDidChangeProgressNotification);
DEFINE_CONST_NSSTRING(NIAudioManagerDidStopNotification);
DEFINE_CONST_NSSTRING(NIAudioManagerDidChangeMixNotification);

DEFINE_CONST_NSSTRING(NIAudioManagerDidChangeSpectrumData);
DEFINE_CONST_NSSTRING(NIAudioManagerSpectrumDataKey);

DEFINE_CONST_NSSTRING(NIAudioManagerStopReasonKey);


static NSString *const AVPlayerStatusKeyPath = @"status";
static NSString *const AVPlayerTracksKeyPath = @"tracks";

@interface NIAudioManager ()

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) NSObject *playerTimeObserver;
@property (nonatomic, assign) BOOL playerIsReady;

@end

@implementation NIAudioManager

@synthesize paused = _paused;
@dynamic progress;

+ (NIAudioManager *)defaultManager
{
    static NIAudioManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        sharedInstance = [self new];
    });
    
    return sharedInstance;
}

- (id)init
{
    if (self = [super init])
    {
        // Setup audio session to support background audio playback.
        [self startObserveNotifications];
    }
    
    return self;
}

- (void)dealloc
{
    self.player = nil;
}

- (void)setupAudioSession
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    NSError *error = nil;
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
    
    if (error)
    {
        NSLog(@"error setting audioSession category: %@-%@", [error localizedDescription], [error localizedFailureReason]);
    }
    
    [audioSession setActive:YES error:&error];
    
    if (error)
    {
        NSLog(@"error setting audioSession active: %@-%@", [error localizedDescription], [error localizedFailureReason]);
    }
}

#pragma mark - Playback

- (void)setFileToPlay:(NSURL *)fileToPlay paused:(BOOL)aPaused
{
    self.fileToPlay = fileToPlay;
    
    self.paused = aPaused;
}

- (void)setFileToPlay:(NSURL *)fileToPlay
{
    if ([_fileToPlay isEqual:fileToPlay])
    {
        return;
    }

    if (fileToPlay.absoluteString.length)
    {
        [self postDidStopNotificationWithReason:NIAudioManagerWillChangeMix];
    }
    
    _fileToPlay = fileToPlay;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NIAudioManagerDidChangeMixNotification object:nil];
    
    [self preloadMix];
}

- (void)preloadMix
{
    self.player = nil;
    
    if (_fileToPlay.absoluteString.length == 0)
    {
        NSLog(@"URL == nil");
        
        [self postDidStopNotificationWithReason:NIAudioManagerFailedToPlayToEnd];

        return;
    }
    
    self.playerItem = [AVPlayerItem playerItemWithURL:_fileToPlay];
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    
    [self setupAudioSession];
}

- (void)beginRecordingAudioFromTrack:(AVAssetTrack *)audioTrack
{
    // Configure an MTAudioProcessingTap to handle things.
    MTAudioProcessingTapRef tap;
    MTAudioProcessingTapCallbacks callbacks;
    callbacks.version = kMTAudioProcessingTapCallbacksVersion_0;
    callbacks.clientInfo = (__bridge void *)(self);
    callbacks.init = init;
    callbacks.prepare = prepare;
    callbacks.process = process;
    callbacks.unprepare = unprepare;
    callbacks.finalize = finalize;
    
    OSStatus err = MTAudioProcessingTapCreate(kCFAllocatorDefault,
                                              &callbacks,
                                              kMTAudioProcessingTapCreationFlag_PostEffects,
                                              &tap);
    
    if(err)
    {
        NSLog(@"Unable to create the Audio Processing Tap %d", (int)err);
        return;
    }
    
    // Create an AudioMix and assign it to our currently playing "item", which
    // is just the stream itself.
    AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
    AVMutableAudioMixInputParameters *inputParams = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:audioTrack];
    inputParams.audioTapProcessor = tap;
    audioMix.inputParameters = @[inputParams];
    self.player.currentItem.audioMix = audioMix;
}

- (void)setPlayer:(AVPlayer *)player
{
    if (_player == player)
    {
        return;
    }
    
    if (_player)
    {
        [_player pause];
        [_player.currentItem removeObserver:self forKeyPath:AVPlayerTracksKeyPath];
        [_player removeObserver:self forKeyPath:AVPlayerStatusKeyPath];
        [_player removeTimeObserver:self.playerTimeObserver];
    }
    
    _player = player;
    
    self.playerIsReady = NO;
    
    if (_player == nil)
    {
        return;
    }
    
    self.playerTimeObserver =
    [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) // 0.5 seconds
                                              queue:NULL
                                         usingBlock:^(CMTime time)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:NIAudioManagerDidChangeProgressNotification object:nil];
    }];
    
    [self.player addObserver:self forKeyPath:AVPlayerStatusKeyPath options:kNilOptions context:NULL];
    [self.player.currentItem addObserver:self forKeyPath:AVPlayerTracksKeyPath options:kNilOptions context:NULL];
    
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
}

- (void)togglePlayPause
{
    self.paused = (self.paused == NO);
}

- (void)playNext
{
    [self setFileToPlay:[self.delegate nextFileToPlay] paused:NO];
}

- (void)playPrev
{
    [self setFileToPlay:[self.delegate prevFileToPlay] paused:NO];
}

- (BOOL)paused
{
    return (self.player.rate == 0.f);
}

- (void)setPaused:(BOOL)paused
{
    _paused = paused;
    
    if (self.playerIsReady == NO)
    {
        return;
    }
    
    if (_paused)
    {
        [self.player pause];
        
        [self postDidStopNotificationWithReason:NIAudioManagerPaused];
    }
    else
    {
        [self.player play];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NIAudioManagerDidStartPlayNotification object:nil];
    }
}

- (void)setProgress:(float)progress
{
    if (self.playerIsReady)
    {
        CMTime timeToSeek = [self timeForProgress:progress];
        
        if (!CMTIME_IS_INDEFINITE(timeToSeek))
        {
            [self.player seekToTime:timeToSeek];
        }
    }
}

- (void)updateSpectrumDataWithData:(NSArray *)data
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        NSDictionary *userInfo = nil;
        if (data)
        {
            userInfo = @{NIAudioManagerSpectrumDataKey : data};
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NIAudioManagerDidChangeSpectrumData object:nil userInfo:userInfo];
    });
}

- (float)progress
{
    if (self.playerIsReady == NO)
    {
        return 0.f;
    }
    
    NSTimeInterval duration = self.duration;
    
    if (duration > 0.0)
    {
        NSTimeInterval currentTime = self.currentTime;
        
        if (currentTime > 0.0)
        {
            return [self.class adjustedProgress:currentTime/duration];
        }
    }
    
    return 0.f;
}

#pragma mark - Time

- (NSTimeInterval)duration
{
    return [NICommonUtils secondsFromCMTime:self.player.currentItem.duration];
}

- (NSTimeInterval)currentTime
{
    return [NICommonUtils secondsFromCMTime:self.player.currentItem.currentTime];
}

- (NSTimeInterval)currentTimeLeft
{
    return MAX(0.0, self.duration - self.currentTime);
}

#pragma mark - Notifications

- (void)startObserveNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEndTimeNotification:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemFailedToPlayToEndTimeNotification:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:nil];
}

- (void)playerItemDidPlayToEndTimeNotification:(NSNotification *)notification
{
    [self postDidStopNotificationWithReason:NIAudioManagerDidPlayToEnd];
    
    [self playNext];
}

- (void)playerItemFailedToPlayToEndTimeNotification:(NSNotification *)notification
{
    NSLog(@"%@", notification.userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey]);
    
    [self postDidStopNotificationWithReason:NIAudioManagerFailedToPlayToEnd];
}

- (void)postDidStopNotificationWithReason:(NIAudioManagerStopReason)reason
{
    _paused = YES;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NIAudioManagerDidStopNotification object:nil userInfo:@{NIAudioManagerStopReasonKey: @(reason)}];
}

#pragma mark - Utils

- (CMTime)timeForProgress:(float)progress
{
    if (self.player.currentItem)
    {
        CMTime time = self.player.currentItem.duration;
        
        if (CMTIME_IS_NUMERIC(time))
        {
            return CMTimeMultiplyByFloat64(time, [self.class adjustedProgress:progress]);
        }
    }
    
    return kCMTimeIndefinite;
}


+ (float)adjustedProgress:(float)progress
{
    return MIN(MAX(0.f, progress), 1.f);
}

+ (NSDate *)dateFromTime:(CMTime)time
{
    if (CMTIME_IS_NUMERIC(time))
    {
        return [NSDate dateWithTimeIntervalSince1970:CMTimeGetSeconds(time)];
    }
    
    return nil;
}

#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:AVPlayerStatusKeyPath])
    {
        switch (self.player.status)
        {
            case AVPlayerStatusUnknown:
            case AVPlayerStatusFailed:
            {
                NSLog(@"%@", self.player.error);
                
                [self postDidStopNotificationWithReason:NIAudioManagerFailedToPlayToEnd];
                break;
            }
                
            case AVPlayerStatusReadyToPlay:
            {
                
            }
                
            default:
                break;
        }
    }
    else if ([keyPath isEqualToString:AVPlayerTracksKeyPath])
    {
        if (self.player.currentItem.tracks.count > 0)
        {
            self.playerIsReady = YES;

            AVURLAsset *asset = (AVURLAsset *)self.playerItem.asset;
            
            NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeAudio];
            if (tracks.count > 0)
            {
                AVAssetTrack *audioTrack = tracks[0];
                
                [self beginRecordingAudioFromTrack:audioTrack];
            }
            
            if (_paused == NO)
            {
                [self.player play];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:NIAudioManagerDidStartPlayNotification object:nil];
            }
        }
    }
}

void init(MTAudioProcessingTapRef tap, void *clientInfo, void **tapStorageOut)
{
    NSLog(@"Initialising the Audio Tap Processor");
    *tapStorageOut = clientInfo;
}

void finalize(MTAudioProcessingTapRef tap)
{
    NSLog(@"Finalizing the Audio Tap Processor");
}

void prepare(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *processingFormat)
{
    NSLog(@"Preparing the Audio Tap Processor");
}

void unprepare(MTAudioProcessingTapRef tap)
{
    NSLog(@"Unpreparing the Audio Tap Processor");
}

static NIFFTHelper *fftHelper = nil;

void process(MTAudioProcessingTapRef tap, CMItemCount numberFrames,
             MTAudioProcessingTapFlags flags, AudioBufferList *bufferListInOut,
             CMItemCount *numberFramesOut, MTAudioProcessingTapFlags *flagsOut)
{
    OSStatus err = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut,
                                                      flagsOut, NULL, numberFramesOut);
    if (err)
    {
        NSLog(@"Error from GetSourceAudio: %i", (int)err);
    }
    
    if (!fftHelper)
    {
        fftHelper = [NIFFTHelper new];
    }
    
    [fftHelper performComputation:bufferListInOut completionHandler:^(NSArray *fftData)
    {
        [[NIAudioManager defaultManager] updateSpectrumDataWithData:fftData];
    }];
}

@end
