//
//  AKCameraRecordViewController.m
//  TaoVideo
//
//  Created by lihejun on 14-3-18.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraRecordViewController.h"
#import "AKCameraRecordView.h"
#import <AVFoundation/AVFoundation.h>
#import "AKCameraUtils.h"
#import "AKCameraEditViewController.h"
#import "AKCameraExporter.h"
#import "AKCameraMessageHUD.h"
#import "AKCameraNavigationBar.h"
#import "AKCameraDefines.h"

@interface AKCameraRecordViewController ()<AKCameraRecordViewDelegate, UIActionSheetDelegate>
{
    UIButton *nextButton;
    
    BOOL firstShow; // 是否第一次显示
    NSDictionary *location; // 地理位置
    
    BOOL saveAsDraft;
    
}
@property (nonatomic, strong)AKCameraNavigationBar *akNavigationBar;
@property (nonatomic, strong)AKCameraRecordView *recordView;

@end

@implementation AKCameraRecordViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    // Layout views
    [self layoutViews];
    
    [AKCameraTool shareInstance].video = nil; // 清空历史记录
    
    // Request location
    [self performSelectorInBackground:@selector(requestLocation) withObject:nil];
}

- (void)requestLocation {
    [[AKCameraTool shareInstance].delegate akCameraNeedLocation];
}

- (void)layoutViews {
    [self setNaviBarTitle:@"拍摄"];
    UIButton *cancelButton = [AKCameraNavigationBar createNormalNaviBarBtnByTitle:@"取消" target:self action:@selector(cancel:)];
    [self setNaviBarLeftBtn:cancelButton];
    
    // 创建一个自定义的按钮，并添加到导航条右侧。
    nextButton = [AKCameraNavigationBar createNormalNaviBarBtnByTitle:@"下一步" target:self action:@selector(next:)];
    [self setNaviBarRightBtn:nextButton];
    nextButton.enabled = NO;
    
    // 隐藏底边线
    [self hideBottomLine];
    
    firstShow = YES;
    [self.view addSubview:self.recordView];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    BOOL granted = YES;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0 && [[NSUserDefaults standardUserDefaults] boolForKey:@"akRecordFirstCapture"]) {
        AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        if (status == AVAuthorizationStatusDenied) {
            granted = NO;
        }
        status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
        if (status == AVAuthorizationStatusDenied) {
            granted = NO;
        }
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"akRecordFirstCapture"];
    }
    
    if (!granted) {
        [AKCameraUtils showCaptureAlert];
    }
    
    [self.recordView showCapture:granted];
    
    if (firstShow) {
        firstShow = NO;
        // 功能未完全验证，先放弃
        // Check cache
        /*
         AKVideo *video = [AKCameraTool shareInstance].video;
         if (video && [video.movieFilePaths count] > 0) {
         // Has cache
         UIAlertView *alert = [[UIAlertView alloc] initWithTitle:Nil message:@"尚有未完成的拍摄，是否继续" delegate:self cancelButtonTitle:@"重新开始" otherButtonTitles:@"继续拍摄", nil];
         alert.tag = 101;
         [alert show];
         }
         */
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [AKCameraMessageHUD dismiss];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions
- (void)next:(id)sender {
    [self.recordView finishCapture];
}

- (void)cancelCapture{
    [self.recordView cancelCapture];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)cancel:(id)sender {
    if (self.recordView.progress > 0 && nextButton.enabled) {
        /*
         UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"要放弃这段视频吗？" delegate:self cancelButtonTitle:@"保存草稿" otherButtonTitles:@"放弃视频",nil];
         alert.tag = 102;
         [alert show];
         */
        [self showActionPicker];
    }else{
        [self cancelCapture];
    }
}

- (void)showActionPicker {
    UIActionSheet *sheet = [[UIActionSheet alloc]
                            initWithTitle:nil
                            delegate:self
                            cancelButtonTitle:@"继续拍摄"
                            destructiveButtonTitle:nil
                            otherButtonTitles:@"保存草稿", @"放弃视频",nil];
    sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [sheet showInView:self.view];
}

#pragma mark - ActionSheetDelegate
-(void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        saveAsDraft = YES;
        [self.recordView finishCapture];
    }else if(buttonIndex == 1) {
        [(id<AKCameraInternalDelegate>)[AKCameraTool shareInstance] akCameraSaveWillCancel:NO];
        [self cancelCapture];
    }
}

#pragma mark - UIAlertView delegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if(alertView.tag == 102 && buttonIndex == 1){
        [self cancelCapture];
    } else if (alertView.tag == 101) {
        if (buttonIndex == 0) {
            // cancel
            AKCameraTool *akTool = [AKCameraTool shareInstance];
            [akTool.video.movieFilePaths removeAllObjects];
            [akTool.video.keyFrames removeAllObjects];
        } else {
            [self.recordView loadFromCache];
        }
    }
}

#pragma mark - AKRecordViewDelegate
- (void)akRecordViewRequiredDone:(AKCameraRecordView *)view{
    nextButton.enabled = YES;
}

- (void)akRecordView:(AKCameraRecordView *)view didFinishWith:(AKVideo *)video keyFrames:(NSArray *)frames{
    if (location) {
        video.location = location; // Set location
    }
    if (saveAsDraft) {
        // Check url first
        NSURL *url = [[AKCameraExporter shareInstance] checkExportOutputURL];
        if (url && ![[url absoluteString] isEqualToString:@""]) {
            NSArray *parts = [[url absoluteString] componentsSeparatedByString:@"/"];
            video.videoFileName = [parts lastObject];
        }
        
        NSString *clipfileName = [AKCameraUtils saveCoverFile:video.defaultCover ? video.defaultCover :[frames objectAtIndex:0] with:[AKCameraUtils uniqueCoverFilenameWithPrefix:@"clip"]];
        video.coverFileName = clipfileName;
        
        [(id<AKCameraInternalDelegate>)[AKCameraTool shareInstance] akCameraSaveWillCancel:YES];
        [self performSelector:@selector(cancelCapture) withObject:nil afterDelay:0.8f];
    } else {
        AKCameraEditViewController *vc = [[AKCameraEditViewController alloc] init];
        [AKCameraExporter shareInstance].delegate = vc;
        vc.video = video;
        vc.images = [frames mutableCopy];
        // 已经是在main_queue里面了
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (void)akRecordViewProgressTooSmall{
    nextButton.enabled = NO;
}

- (void)akRecordViewStartStopping:(AKCameraRecordView *)view {
    [AKCameraMessageHUD show:@"正在处理..."];
}

- (void)akRecordViewStartFailed:(AKCameraRecordView *)view error:(NSError *)error {
    //DLog(@"%@", error);
    [AKCameraMessageHUD showError:@"开始拍摄失败，请重新开始"];
}

- (void)akRecordViewEndFailed:(AKCameraRecordView *)view error:(NSError *)error {
    //DLog(@"%@", error);
    [AKCameraMessageHUD showError:@"结束拍摄失败，请重新开始"];
}

#pragma mark - Getters
- (AKCameraRecordView *)recordView {
    if (!_recordView) {
        CGRect r = self.view.bounds;
        if (IsiOS7Later) {
            r.origin.y += 20; //default is 0
            r.size.height -= 20;
        }
        r.origin.y += 44;
        r.size.height -= 44;
        
        _recordView = [[AKCameraRecordView alloc] initWithFrame:r];
        _recordView.delegate = self;
    }
    return _recordView;
}
@end