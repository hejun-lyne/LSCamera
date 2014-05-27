//
//  AKRecordProgressView.h
//  TaoVideo
//
//  Created by lihejun on 14-3-14.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AKRecordProgressView : UIView
@property (nonatomic, strong) UIColor* progressTintColor;
@property (nonatomic, strong) UIColor* borderTintColor;
@property (nonatomic) CGFloat progress;
@property (nonatomic) CGFloat radius;
@property (nonatomic) CGFloat border;

- (void)setProgress:(CGFloat)progress animated:(BOOL)animated;
@end
