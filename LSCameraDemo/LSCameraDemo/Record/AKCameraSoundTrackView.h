//
//  AKCameraSoundTrackView.h
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol AKCameraSoundTrackViewDelegate;

@interface AKCameraSoundTrackView : UIView
@property (weak, nonatomic) id<AKCameraSoundTrackViewDelegate> delegate;

- (CGFloat)value;
- (void)setSliderValue:(CGFloat )value;

@end

@protocol AKCameraSoundTrackViewDelegate <NSObject>

- (void)soundTrackViewValueChange:(CGFloat)value;

@end
