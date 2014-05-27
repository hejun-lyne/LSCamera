//
//  AKCameraViewController.h
//  TaoVideo
//
//  Created by lihejun on 14-3-19.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AKCameraNavigationBar.h"

@interface AKCameraViewController : UIViewController

- (void)bringNaviBarToTopmost;

- (void)hideNaviBar:(BOOL)bIsHide;
- (void)setNaviBarTitle:(NSString *)strTitle;
- (void)setNaviBarLeftBtn:(UIButton *)btn;
- (void)setNaviBarLeftBtnTitle:(NSString *)title;
- (void)setNaviBarRightBtn:(UIButton *)btn;
- (void)hideBottomLine;

- (void)naviBarAddCoverView:(UIView *)view;
- (void)naviBarAddCoverViewOnTitleView:(UIView *)view;
- (void)naviBarRemoveCoverView:(UIView *)view;

// 控制点击返回按钮行为
- (BOOL)willGoBack;

@end
