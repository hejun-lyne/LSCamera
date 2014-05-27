//
//  AKCameraNavigationBar.m
//  TaoVideo
//
//  Created by lihejun on 14-3-19.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraNavigationBar.h"
#import "AKCameraDefines.h"
#import "UIImage+AKExtension.h"
#import "AKCameraStyle.h"
#import "AKCameraUtils.h"
#import "AKCameraViewController.h"

#define FLOAT_TitleSizeNormal               19.0f
#define FLOAT_TitleSizeMini                 14.0f
#define RGB_TitleNormal                     RGB(80.0f, 80.0f, 80.0f)
#define RGB_TitleMini                       [UIColor blackColor]

@implementation AKCameraNavigationBar

@synthesize m_btnBack = _btnBack;
@synthesize m_labelTitle = _labelTitle;
@synthesize m_imgViewBg = _imgViewBg;
@synthesize m_btnLeft = _btnLeft;
@synthesize m_btnRight = _btnRight;
@synthesize m_bIsBlur = _bIsBlur;
@synthesize m_bottomLine = _bottomLine;


+ (CGRect)rightBtnFrame
{
    return Rect(258.0f, IOSVersion >= 7.0 ? 22.0f : 2.0f, [[self class] barBtnSize].width, [[self class] barBtnSize].height);
}

+ (CGSize)barBtnSize
{
    return Size(60.0f, 40.0f);
}

+ (CGSize)barSize
{
    if (IOSVersion >= 7.0) {
        return Size(320.0f, 64.0f);
    }
    return Size(320.0f, 44.0f);
}

+ (CGRect)titleViewFrame
{
    return Rect(65.0f, IOSVersion >= 7.0 ? 22.0f : 2.0f, 190.0f, 40.0f);
}

// 创建一个导航条按钮：使用默认的按钮图片。
+ (UIButton *)createNormalNaviBarBtnByTitle:(NSString *)strTitle target:(id)target action:(SEL)action
{
    UIImage *normalImage = [UIImage roundedImageWithSize:[[self class] barBtnSize] color:[UIColor clearColor] radius:6];
    UIButton *btn = [[self class] createImgNaviBarBtnByImgNormal:normalImage imgHighlight:Nil target:target action:action];
    [btn setTitle:strTitle forState:UIControlStateNormal];
    [btn setTitleColor:[AKCameraStyle colorForNavigationTint] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:17.0f];
    [AKCameraUtils label:btn.titleLabel setMiniFontSize:8.0f forNumberOfLines:1];
    
    return btn;
}

+ (UIButton *)createImgNaviBarBtnByImgNormal:(UIImage *)imgNormal imgHighlight:(UIImage *)imgHighlight target:(id)target action:(SEL)action {
    return [[self class] createImgNaviBarBtnByImgNormal:imgNormal imgHighlight:imgHighlight imgSelected:imgHighlight target:target action:action];
}

+ (UIButton *)createImgNaviBarBtnByImgNormal:(UIImage *)imgNormal imgHighlight:(UIImage *)imgHighlight imgSelected:(UIImage *)imgSelected target:(id)target action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    [btn setImage:imgNormal forState:UIControlStateNormal];
    if (imgHighlight) {
        [btn setImage:imgHighlight forState:UIControlStateHighlighted];
    }
    if (imgSelected) {
        [btn setImage:imgSelected forState:UIControlStateSelected];
    }
    CGFloat fDeltaWidth = ([[self class] barBtnSize].width - imgNormal.size.width)/2.0f;
    CGFloat fDeltaHeight = ([[self class] barBtnSize].height - imgNormal.size.height)/2.0f;
    fDeltaWidth = (fDeltaWidth >= 2.0f) ? fDeltaWidth/2.0f : 0.0f;
    fDeltaHeight = (fDeltaHeight >= 2.0f) ? fDeltaHeight/2.0f : 0.0f;
    [btn setImageEdgeInsets:UIEdgeInsetsMake(fDeltaHeight, fDeltaWidth, fDeltaHeight, fDeltaWidth)];
    [btn setTitleEdgeInsets:UIEdgeInsetsMake(fDeltaHeight, -imgNormal.size.width, fDeltaHeight, fDeltaWidth)];
    return btn;
}

+ (UIButton *)backButtonTarget:(id)target action:(SEL)action {
    UIImage *backImage = [UIImage imageNamed:@"AKCamera.bundle/back-button"];
    UIImage *normalImage = [backImage imageByFilledWithColor:[AKCameraStyle colorForNavigationTint]];
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    [btn setImage:normalImage forState:UIControlStateNormal];
    [btn setTitleColor:[AKCameraStyle colorForNavigationTint] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:17.0f];
    CGFloat fDeltaWidth = ([[self class] barBtnSize].width - normalImage.size.width)/2.0f;
    CGFloat fDeltaHeight = ([[self class] barBtnSize].height - normalImage.size.height)/2.0f;
    fDeltaWidth = (fDeltaWidth >= 2.0f) ? fDeltaWidth/2.0f : 0.0f;
    fDeltaHeight = (fDeltaHeight >= 2.0f) ? fDeltaHeight/2.0f : 0.0f;
    [btn setImageEdgeInsets:UIEdgeInsetsMake(fDeltaHeight, fDeltaWidth, fDeltaHeight, fDeltaWidth)];
    [btn setTitleEdgeInsets:UIEdgeInsetsMake(fDeltaHeight, -(normalImage.size.width - 20), fDeltaHeight, fDeltaWidth)];
    return btn;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        
        // _bIsBlur = (IsiOS7Later && Is4Inch); //不需要
        
        [self initUI];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [self initUI];
}

- (void)initUI
{
    self.backgroundColor = [UIColor clearColor];
    
    // 默认左侧显示返回按钮
   
    _btnBack = [[self class] backButtonTarget:self action:@selector(btnBack:)];
    
    _labelTitle = [[UILabel alloc] initWithFrame:CGRectZero];
    _labelTitle.backgroundColor = [UIColor clearColor];
    _labelTitle.textColor = [AKCameraStyle colorForNavigationTint];
    _labelTitle.font = [UIFont boldSystemFontOfSize:FLOAT_TitleSizeNormal];
    _labelTitle.textAlignment = NSTextAlignmentCenter;
    
    _labelTitle.hidden = [AKCameraStyle navigationTitleHidden];
    
    _imgViewBg = [[UIImageView alloc] initWithFrame:self.bounds];
    UIImage *naviImage = [UIImage imageWithColor:[AKCameraStyle colorForNavigationBar] size:self.bounds.size];
    _imgViewBg.image = [naviImage resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
    _imgViewBg.alpha = 0.98f;
    
    if (_bIsBlur)
    {
        // iOS7可设置是否需要现实磨砂玻璃效果
        _imgViewBg.alpha = 0.0f;
        UINavigationBar *naviBar = [[UINavigationBar alloc] initWithFrame:self.bounds];
        naviBar.backgroundColor = [AKCameraStyle colorForNavigationBar];
        [self addSubview:naviBar];
    }else{}
    
    _bottomLine = [[UIImageView alloc] initWithImage:[UIImage imageWithColor:[AKCameraStyle colorForNavigationLine] size:Size(self.bounds.size.width, 0.5f)]];
    _bottomLine.frame = Rect(0, self.bounds.size.height - _bottomLine.bounds.size.height, 320.0f, 0.5f);
    
    _labelTitle.frame = [[self class] titleViewFrame];
    _imgViewBg.frame = self.bounds;
    
    [self addSubview:_imgViewBg];
    [self addSubview:_labelTitle];
    [self addSubview:_bottomLine];
    
    [self setLeftBtn:_btnBack];
}

- (void)setTitle:(NSString *)strTitle
{
    [_labelTitle setText:strTitle];
}

- (void)setLeftBtn:(UIButton *)btn
{
    if (_btnLeft)
    {
        [_btnLeft removeFromSuperview];
        _btnLeft = nil;
    }else{}
    
    _btnLeft = btn;
    if (_btnLeft)
    {
        _btnLeft.frame = Rect(2.0f, IOSVersion >= 7.0 ? 22.0f : 2.0f, [[self class] barBtnSize].width, [[self class] barBtnSize].height);
        [self addSubview:_btnLeft];
    }else{}
}

- (void)setLeftBtnTitle:(NSString *)title {
    [_btnLeft setTitle:title forState:UIControlStateNormal];
}

- (void)setRightBtn:(UIButton *)btn
{
    if (_btnRight)
    {
        [_btnRight removeFromSuperview];
        _btnRight = nil;
    }else{}
    
    _btnRight = btn;
    if (_btnRight)
    {
        _btnRight.frame = [[self class] rightBtnFrame];
        [self addSubview:_btnRight];
    }else{}
}

- (void)btnBack:(id)sender
{
    if (self.m_viewCtrlParent)
    {
        if ([(AKCameraViewController *)self.m_viewCtrlParent willGoBack]) {
            [self.m_viewCtrlParent.navigationController popViewControllerAnimated:YES];
        }
    }else{APP_ASSERT_STOP}
}

- (void)goBack {
    [self btnBack:nil];
}

- (void)hideBottomLine {
    _bottomLine.hidden = YES;
}

- (void)showCoverView:(UIView *)view
{
    [self showCoverView:view animation:NO];
}
- (void)showCoverView:(UIView *)view animation:(BOOL)bIsAnimation
{
    if (view)
    {
        [self hideOriginalBarItem:YES];
        
        [view removeFromSuperview];
        
        view.alpha = 0.4f;
        [self addSubview:view];
        if (bIsAnimation)
        {
            [UIView animateWithDuration:0.2f animations:^()
             {
                 view.alpha = 1.0f;
             }completion:^(BOOL f){}];
        }
        else
        {
            view.alpha = 1.0f;
        }
    }else{APP_ASSERT_STOP}
}

- (void)showCoverViewOnTitleView:(UIView *)view
{
    if (view)
    {
        if (_labelTitle)
        {
            _labelTitle.hidden = YES;
        }else{}
        
        [view removeFromSuperview];
        view.frame = _labelTitle.frame;
        
        [self addSubview:view];
    }else{APP_ASSERT_STOP}
}

- (void)hideCoverView:(UIView *)view
{
    [self hideOriginalBarItem:NO];
    if (view && (view.superview == self))
    {
        [view removeFromSuperview];
    }else{}
}

#pragma mark -
- (void)hideOriginalBarItem:(BOOL)bIsHide
{
    if (_btnLeft)
    {
        _btnLeft.hidden = bIsHide;
    }else{}
    if (_btnBack)
    {
        _btnBack.hidden = bIsHide;
    }else{}
    if (_btnRight)
    {
        _btnRight.hidden = bIsHide;
    }else{}
    if (_labelTitle)
    {
        _labelTitle.hidden = bIsHide;
    }else{}
}

@end
