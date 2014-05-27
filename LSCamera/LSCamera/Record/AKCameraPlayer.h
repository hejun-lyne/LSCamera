//
//  AKCameraPlayer.h
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <UIKit/UIKit.h>
@class AVPlayer;
@interface AKCameraPlayer : UIView
@property (nonatomic, retain) AVPlayer* player;

- (void)setPlayer:(AVPlayer*)player;
- (void)setVideoFillMode:(NSString *)fillMode;
@end
