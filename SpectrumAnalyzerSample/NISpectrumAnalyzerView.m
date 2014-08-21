//
//  NISpectrumAnalyzerView.m
//
//  Created by Nikita Ivaniushchenko on 6/28/14.
//

#import "NISpectrumAnalyzerView.h"
#import "NIAudioManager.h"

const CGFloat kDefaultMinDbLevel = -40.f;
const CGFloat kDefaultMinDbFS = -110.f;
const CGFloat kDBLogFactor = 4.0f;
const NSUInteger kMaxQueuedDataBlocks = 2;
const NSInteger kFrameInterval = 2; //FPS = 60/kFrameInterval, for example kFrameInterval = 2 corresponds to 60/2 = 30FPS

@interface NISpectrumAnalyzerView()

@property (nonatomic, strong) CADisplayLink *displayLink;

@property (nonatomic, strong) NSMutableArray *spectrumData;
@property (nonatomic, strong) NSMutableArray *spectrumViewsArray;

@end

@implementation NISpectrumAnalyzerView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        [self commonInit];
    }
    
    return self;
}

- (void)dealloc
{
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)commonInit
{
    self.columnMargin = 1.f;
    self.columnWidth = 4.f;
    self.showsBlocks = YES;
    
    self.clearsContextBeforeDrawing = YES;
    self.opaque = NO;
    
    self.spectrumData = [NSMutableArray arrayWithCapacity:kMaxQueuedDataBlocks];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioManagerDidChangeSpectrumData:)
                                                 name:NIAudioManagerDidChangeSpectrumData
                                               object:nil];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(setNeedsDisplay)];
    self.displayLink.frameInterval = kFrameInterval;
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)audioManagerDidChangeSpectrumData:(NSNotification *)notification
{
    @synchronized(self)
    {
//        NSLog(@"%i", self.spectrumData.count);
        
        if (self.spectrumData.count > kMaxQueuedDataBlocks)
        {
            [self.spectrumData removeObjectAtIndex:0];
        }
        
        NSArray *spectrumData = [notification.userInfo objectForKey:NIAudioManagerSpectrumDataKey];
        if (spectrumData)
        {
            [self.spectrumData addObject:spectrumData];
        }
    }
}

- (void)drawRect:(CGRect)rect
{
//    static NSTimeInterval timeInterval0 = 0;
//    NSTimeInterval timeInterval1 = [[NSDate date] timeIntervalSince1970];
//    NSLog(@"FPS: %f", 1.f/(timeInterval1 - timeInterval0));
//    timeInterval0 = timeInterval1;

    NSArray *currentSpectrumData = nil;
    
    @synchronized(self)
    {
        if (self.spectrumData.count > 0)
        {
            currentSpectrumData = [[self.spectrumData objectAtIndex:0] copy];
        }
        
        if (self.spectrumData.count > 1)
        {
            [self.spectrumData removeObjectAtIndex:0];
        }
    }
    
    NSUInteger count = currentSpectrumData.count;
    CGFloat maxWidth = self.bounds.size.width;
    CGFloat maxHeight = self.bounds.size.height;
    
    CGFloat offset = self.columnMargin;
    CGFloat width = self.columnWidth;
    
    if (width <= 0.f)
    {
        if (count > 0)
        {
            width = (maxWidth - (count - 1) * offset) / count;
            width = floorf(width);
        }
    }
    
    CGFloat restSpace = maxWidth - (count * width + (count - 1) * offset);
    CGFloat x = restSpace/2.f;
    
    if (self.showsBlocks)
    {
        int blocksCount = maxHeight/width;
        
        if (blocksCount > 0)
        {
            CGFloat lineWidth = 1.f/UI_SCREEN_SCALE;
            CGFloat y = self.bounds.size.height + lineWidth;
            
            
            UIBezierPath *clipBezierPath = [UIBezierPath bezierPath];

            for (int i = 0; i < blocksCount; i++)
            {
                [clipBezierPath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(0.f, y, maxWidth, width)]];
                
                y -= width + lineWidth;
            }
         
            [clipBezierPath closePath];
            [clipBezierPath addClip];
        }
    }
    
    UIBezierPath *barBackgroundPath = [UIBezierPath bezierPath];
    UIBezierPath *barFillPath = [UIBezierPath bezierPath];

    for (int i = 0; i < count; i++)
    {
        CGRect frame = CGRectMake(x, 0.f, width, maxHeight);
        
        [barBackgroundPath appendPath:[UIBezierPath bezierPathWithRect:frame]];

        NSNumber *value = currentSpectrumData[i];
        CGFloat floatValue = value.floatValue;

        if (!isnan(floatValue))
        {
            CGFloat height = 0.f;

            if (floatValue <= kDefaultMinDbLevel)
            {
                height = 1.f/UI_SCREEN_SCALE;
            }
            else if (floatValue >= 0)
            {
                height = maxHeight - 1.f/UI_SCREEN_SCALE;
            }
            else
            {
                float normalizedValue = (kDefaultMinDbLevel - floatValue)/kDefaultMinDbLevel;
//                normalizedValue = pow(normalizedValue, 1.0/kDBLogFactor);
                height = floor(normalizedValue * maxHeight) + 0.5f;
                
//                NSLog(@"db: %8.4f, h: %8.4f", floatValue, normalizedValue);
            }
            
            frame.origin.y = maxHeight - height;
            frame.size.height = height;
            
            [barFillPath appendPath:[UIBezierPath bezierPathWithRect:frame]];
        }
        
        x += width + offset;
    }
    
    [self.barBackgroundColor setFill];
    [barBackgroundPath fill];
    
    [self.barFillColor setFill];
    [barFillPath fill];
}

@end
