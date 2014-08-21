//
//  NISpectrumAnalyzerView.h
//
//  Created by Nikita Ivaniushchenko on 6/28/14.
//

#import <UIKit/UIKit.h>

@interface NISpectrumAnalyzerView : UIView

@property (nonatomic, strong) UIColor *barBackgroundColor;
@property (nonatomic, strong) UIColor *barFillColor;

@property (nonatomic, assign) CGFloat columnMargin;
@property (nonatomic, assign) CGFloat columnWidth;
@property (nonatomic, assign) BOOL showsBlocks;

@end
