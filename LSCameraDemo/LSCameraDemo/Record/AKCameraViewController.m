//
//  AKCameraViewController.m
//  TaoVideo
//
//  Created by lihejun on 14-3-19.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraViewController.h"
#import "AKCameraNavigationBar.h"
#import "AKCameraDefines.h"
#import "AKCameraStyle.h"
#import "AKCameraUtils.h"
@interface AKCameraViewController ()

@property (nonatomic, readonly) AKCameraNavigationBar *naviBar;

@end

@implementation AKCameraViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    _naviBar = [[AKCameraNavigationBar alloc] initWithFrame:Rect(0, 0, [AKCameraNavigationBar barSize].width, [AKCameraNavigationBar barSize].height)];
    _naviBar.m_viewCtrlParent = self;
    NSLog(@"%@", NSStringFromCGRect(self.view.frame));
    [self.view addSubview:_naviBar];
    
    if ([AKCameraStyle useTaoVideoActionBar]) {
        self.view.backgroundColor = [UIColor blackColor];
        [self.navigationController.navigationBar setBarStyle:UIBarStyleBlack];
    } else {
        self.view.backgroundColor = [AKCameraStyle colorForViewBackground];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_naviBar && !_naviBar.hidden) {
        [self.view bringSubviewToFront:_naviBar];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [AKCameraUtils cancelPerformRequestAndNotification:self];
}

#pragma mark - Methods

#warning 如果需要控制是否返回需要实现该方法
- (BOOL)willGoBack {
    return YES;
}

- (void)bringNaviBarToTopmost
{
    if (_naviBar)
    {
        [self.view bringSubviewToFront:_naviBar];
    }
}

- (void)hideNaviBar:(BOOL)bIsHide
{
    _naviBar.hidden = bIsHide;
}

- (void)setNaviBarTitle:(NSString *)strTitle
{
    if (_naviBar)
    {
        [_naviBar setTitle:strTitle];
    }else{APP_ASSERT_STOP}
}

- (void)setNaviBarLeftBtn:(UIButton *)btn
{
    if (_naviBar)
    {
        [_naviBar setLeftBtn:btn];
    }else{APP_ASSERT_STOP}
}

- (void)setNaviBarLeftBtnTitle:(NSString *)title {
    if (_naviBar)
    {
        [_naviBar setLeftBtnTitle:title];
    }else{APP_ASSERT_STOP}
}

- (void)setNaviBarRightBtn:(UIButton *)btn
{
    if (_naviBar)
    {
        [_naviBar setRightBtn:btn];
    }else{APP_ASSERT_STOP}
}

- (void)hideBottomLine {
    if (_naviBar)
    {
        [_naviBar hideBottomLine];
    }else{APP_ASSERT_STOP}
}

- (void)naviBarAddCoverView:(UIView *)view
{
    if (_naviBar && view)
    {
        [_naviBar showCoverView:view animation:YES];
    }else{}
}

- (void)naviBarAddCoverViewOnTitleView:(UIView *)view
{
    if (_naviBar && view)
    {
        [_naviBar showCoverViewOnTitleView:view];
    }else{}
}

- (void)naviBarRemoveCoverView:(UIView *)view
{
    if (_naviBar)
    {
        [_naviBar hideCoverView:view];
    }else{}
}

@end
