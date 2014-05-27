//
//  AKCameraSwitch.h
//  TaoVideo
//
//  Created by lihejun on 14-3-18.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AKCameraSwitch : UIControl
@property(nonatomic, retain) UIColor *tintColor;
@property(nonatomic, retain) UIColor *onTintColor;
@property(nonatomic, assign) UIColor *offTintColor;
@property(nonatomic, assign) UIColor *thumbTintColor;

@property(nonatomic,getter=isOn) BOOL on;

- (id)initWithFrame:(CGRect)frame;

- (void)setOn:(BOOL)on animated:(BOOL)animated;

- (void)setOnWithoutEvent:(BOOL)on animated:(BOOL)animated;
@end
