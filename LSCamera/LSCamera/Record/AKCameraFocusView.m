//
//  AKCameraFocusView.m
//  TaoVideo
//
//  Created by lihejun on 14-3-19.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraFocusView.h"
#import "UIImage+AKExtension.h"
#import "AKCameraStyle.h"

@interface AKCameraFocusView()
{
    UIImageView *_focusRingView;
}

@end

@implementation AKCameraFocusView

#pragma mark - init

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeScaleToFill;
        UIImage *img = [[UIImage imageNamed:@"AKCamera.bundle/capture_focus"] imageByFilledWithColor:[AKCameraStyle cameraLineColor]];
        _focusRingView = [[UIImageView alloc] initWithImage:img];
        [self addSubview:_focusRingView];
        
        self.frame = _focusRingView.frame;
    }
    return self;
}

- (void)dealloc
{
    [self.layer removeAllAnimations];
}

#pragma mark -

- (void)startAnimation
{
    [self.layer removeAllAnimations];
    
    self.transform = CGAffineTransformMakeScale(1.4f, 1.4f);
    self.alpha = 0;
    
    [UIView animateWithDuration:0.4f delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1;
        
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.4f delay:0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat animations:^{
            
            self.transform = CGAffineTransformMakeScale(1.1f, 1.1f);
            self.alpha = 1;
            
        } completion:^(BOOL finished1) {
        }];
    }];
}

- (void)stopAnimation
{
    [self.layer removeAllAnimations];
    
    [UIView animateWithDuration:0.2f delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        
        self.transform = CGAffineTransformMakeScale(0.001f, 0.001f);
        self.alpha = 0;
        
    } completion:^(BOOL finished) {
        
        [self removeFromSuperview];
        
    }];
}

@end
