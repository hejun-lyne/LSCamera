//
//  AKCameraStyle.h
//  TaoVideo
//
//  Created by lihejun on 14-3-18.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AKCameraStyle : NSObject
@property (nonatomic, strong)UIColor *navigationBarColor; // 导航条背景颜色
@property (nonatomic, strong)UIColor *navigationLineColor; // 导航条底边线颜色
@property (nonatomic, strong)UIColor *navigationTintColor; // 导航色调
@property (nonatomic, assign)BOOL navigationTitleHidden; // 是否显示页面标题
@property (nonatomic, assign)BOOL cameraProgressBarOnBottom; // 拍摄进度条是否在画面底部
@property (nonatomic, strong)UIColor *cameraLineColor; // 最少拍摄提示线颜色
@property (nonatomic, strong)UIColor *cameraCursorColor; // 拍摄进度光标颜色
@property (nonatomic, strong)UIColor *cameraProgressColor; // 拍摄进度条颜色
@property (nonatomic, assign)BOOL useTaoVideoActionBar; // 是否使用淘视频拍摄工具条
@property (nonatomic, assign)BOOL useDefaultCover; // 使用默认第一张图片作为封面，不提供选择封面
@property (nonatomic, assign)BOOL stopAtEditController; // 只需要进行到编辑界面，不显示保存界面
@property (nonatomic, assign)BOOL useTaoVideoBgmPicker; // 使用淘视频背景音乐选择
@property (nonatomic, strong)UIColor *viewBackgroundColor; // 页面背景颜色
@property (nonatomic, assign)BOOL hideChannelSelection; // 是否显示频道选择
@property (nonatomic, assign)BOOL hideLocationSelection; // 是否显示地理位置选择
@property (nonatomic, assign)BOOL hidePublishWaySelection; // 是否显示发布方式
@property (nonatomic, assign)BOOL hideVisibleSelection; // 是否显示可见范围选择
+ (AKCameraStyle *)shareInstance;

// Custom navigationbar
+ (UIColor *)colorForNavigationBar;
+ (UIColor *)colorForNavigationLine;
+ (UIColor *)colorForNavigationTint;
+ (BOOL)navigationTitleHidden;

// Custom ViewController
+ (UIColor *)colorForViewBackground;

// Custom recordView
+ (BOOL)cameraProgressBarOnBottom;
+ (UIColor *)cameraLineColor;
+ (UIColor *)cameraCursorColor;
+ (UIColor *)cameraProgressColor;
+ (BOOL)useTaoVideoActionBar;
+ (BOOL)useDefaultCover;
+ (BOOL)stopAtEditController;
+ (BOOL)useTaoVideoBgmPicker;

// Save View
+ (BOOL)hideChannelSelection;
+ (BOOL)hideLocationSelection;
+ (BOOL)hidePublishWaySelection;
+ (BOOL)hideVisibleSelection;


+ (UIColor *)colorForHightlight;

+ (UIColor *)colorForHightlightAlpha:(float)alpha;

+ (UIColor *)colorForSeperator;

+ (UIColor *)colorForBarButtonBackground;

+ (UIView *)lineForMiddleCell:(UIView *)view;

+ (UIView *)lineForTopCell:(UIView *)view;

+ (UIView *)lineForEndCell:(UIView *)view;

@end
