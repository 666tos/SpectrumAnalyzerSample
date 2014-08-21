//
//  NIViewController.m
//  SpectrumAnalyzerSample
//
//  Created by Nikita Ivaniushchenko on 8/21/14.
//
//

#import "NIViewController.h"
#import "NISpectrumAnalyzerView.h"
#import "NIAudioManager.h"

@interface NIViewController ()

@property (nonatomic, weak) IBOutlet NISpectrumAnalyzerView *spectrumAnalyzerView;

@end

@implementation NIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.spectrumAnalyzerView.backgroundColor = [UIColor clearColor];
    self.spectrumAnalyzerView.barBackgroundColor = [UIColor colorWithRed:1.f green:1.f blue:1.f alpha:0.2f];
    self.spectrumAnalyzerView.barFillColor = [UIColor colorWithRed:0.98f green:0.36f blue:0.36f alpha:1.f];
    self.spectrumAnalyzerView.columnWidth = 20.f;
    
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"Rayman_2_music_sample" withExtension:@"mp3"];
    [NIAudioManager defaultManager].fileToPlay = url;
    [NIAudioManager defaultManager].paused = NO;
}

- (IBAction)playPauseButtonPressed:(id)sender
{
    [[NIAudioManager defaultManager] togglePlayPause];
}

@end
