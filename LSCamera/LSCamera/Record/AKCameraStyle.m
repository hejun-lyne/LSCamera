//
//  AKCameraStyle.m
//  TaoVideo
//
//  Created by lihejun on 14-3-18.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraStyle.h"

@interface AKCameraStyle()

@end

@implementation AKCameraStyle

+ (AKCameraStyle *)shareInstance {
    static AKCameraStyle *s_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_instance = [[AKCameraStyle alloc] init];
    });
    return s_instance;
}

#pragma mark - NavigationBar
+ (UIColor *)colorForNavigationBar {
    return [self shareInstance].navigationBarColor;
}

+ (UIColor *)colorForNavigationLine {
    return [self shareInstance].navigationLineColor;
}

+ (UIColor *)colorForNavigationTint {
    return [self shareInstance].navigationTintColor;
}

+ (BOOL)navigationTitleHidden {
    return [self shareInstance].navigationTitleHidden;
}

#pragma mark - ViewController
+ (UIColor *)colorForViewBackground {
    return [self shareInstance].viewBackgroundColor;
}

#pragma mark - RecordView
+ (BOOL)cameraProgressBarOnBottom {
    return [self shareInstance].cameraProgressBarOnBottom;
}

+ (UIColor *)cameraLineColor {
    return [self shareInstance].cameraLineColor;
}

+ (UIColor *)cameraCursorColor {
    return [self shareInstance].cameraCursorColor;
}

+ (UIColor *)cameraProgressColor {
    return [self shareInstance].cameraProgressColor;
}

+ (BOOL)useTaoVideoActionBar {
    return [self shareInstance].useTaoVideoActionBar;
}

+ (BOOL)useDefaultCover {
    return [self shareInstance].useDefaultCover;
}

+ (BOOL)stopAtEditController {
    return [self shareInstance].stopAtEditController;
}

+ (BOOL)useTaoVideoBgmPicker {
    return [self shareInstance].useTaoVideoBgmPicker;
}

#pragma mark - Save
+ (BOOL)hidePublishWaySelection {
    return [self shareInstance].hidePublishWaySelection;
}

+ (BOOL)hideChannelSelection {
    return [self shareInstance].hideChannelSelection;
}

+ (BOOL)hideLocationSelection {
    return [self shareInstance].hideLocationSelection;
}

+ (BOOL)hideVisibleSelection {
    return [self shareInstance].hideVisibleSelection;
}

+ (UIColor *)colorForHightlight{
    return [self colorForHightlightAlpha:1];
}

+ (UIColor *)colorForHightlightAlpha:(float)alpha {
    return [UIColor colorWithRed:24/255.0f green:186/255.0f blue:250/255.0f alpha:alpha];
}

+ (UIColor *)colorForSeperator {
    return [UIColor colorWithRed:204/255.0f green:204/255.0f blue:204/255.0f alpha:1];
}

+ (UIColor *)colorForBarButtonBackground {
    return [UIColor colorWithRed:228/255.0f green:228/255.0f blue:228/255.0f alpha:1];;
}

#pragma mark - Lines
+ (UIView *)lineForMiddleCell:(UIView *)view{
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(14, view.bounds.size.height - 0.5, view.bounds.size.width - 14, .5)];
    line.backgroundColor = [UIColor colorWithRed:204/255.0f green:204/255.0f blue:204/255.0f alpha:1];
    return line;
}

+ (UIView *)lineForTopCell:(UIView *)view{
    UIView *line = [self lineForMiddleCell:view];
    line.frame = CGRectMake(0, 0, view.bounds.size.width, .5);
    return line;
}

+ (UIView *)lineForEndCell:(UIView *)view{
    UIView *line = [self lineForMiddleCell:view];
    line.frame = CGRectMake(0, view.bounds.size.height - 0.5, view.bounds.size.width, .5);
    return line;
}

#pragma mark - Getters
- (UIColor *)navigationBarColor {
    if (!_navigationBarColor) {
        return [UIColor colorWithRed:248/255.0f green:248/255.0f blue:248/255.0f alpha:1];
    }
    return _navigationBarColor;
}

- (UIColor *)navigationLineColor {
    if (!_navigationLineColor) {
        return [UIColor lightGrayColor];
    }
    return _navigationLineColor;
}

- (UIColor *)navigationTintColor {
    if (!_navigationTintColor) {
        return [UIColor colorWithRed:24/255.0f green:186/255.0f blue:250/255.0f alpha:1];
    }
    return _navigationTintColor;
}

- (UIColor *)cameraLineColor {
    if (!_cameraLineColor) {
        return [UIColor whiteColor];
    }
    return _cameraLineColor;
}

- (UIColor *)cameraCursorColor {
    if (!_cameraCursorColor) {
        return [UIColor whiteColor];
    }
    return _cameraCursorColor;
}

- (UIColor *)cameraProgressColor {
    if (!_cameraProgressColor) {
        return [UIColor colorWithRed:24/255.0f green:186/255.0f blue:250/255.0f alpha:1];
    }
    return _cameraProgressColor;
}

- (UIColor *)viewBackgroundColor {
    if (!_viewBackgroundColor) {
        return [UIColor colorWithRed:235/255.0f green:235/255.0f blue:235/255.0f alpha:1];
    }
    return _viewBackgroundColor;
}

@end
