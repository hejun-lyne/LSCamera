//
//  LSCameraViewController.m
//  LSCameraDemo
//
//  Created by lihejun on 14-4-4.
//  Copyright (c) 2014年 hejun.lyne. All rights reserved.
//

#import "LSCameraViewController.h"
#import "AKCameraTool.h"
#import <MediaPlayer/MediaPlayer.h>

@interface LSCameraViewController ()<AKCameraToolDelegate, AKCameraEditDelegate>

@end

@implementation LSCameraViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)startRecordWithDefault:(id)sender {
    [self resetDefault]; // 因为有可能切换为淘视频样式，所以在这里重置一下
    [self startRecrod];
}
- (IBAction)startRecordWithTaoVideo:(id)sender {
    [self taoVideoStyle];
    [self startRecrod];
}
- (IBAction)preview:(id)sender {
    // 预览已拍摄视频
    MPMoviePlayerViewController *playerView = [[MPMoviePlayerViewController alloc] initWithContentURL:[[AKCameraTool shareInstance].video getVideoPath]];
    playerView.view.frame = self.view.frame;//全屏播放（全屏播放不可缺）
    playerView.moviePlayer.scalingMode = MPMovieScalingModeAspectFit;//全屏播放（全屏播放不可缺）
    playerView.moviePlayer.shouldAutoplay= NO;
    [playerView.moviePlayer play];
    [self presentMoviePlayerViewControllerAnimated:playerView];
}

- (void)startRecrod {
    AKCameraTool *tool = [AKCameraTool shareInstance];
    tool.delegate = self;
    [tool startRecordFromController:self];
}

- (void)resetDefault {
    // 重置为默认样式
    AKCameraStyle *style = [AKCameraStyle shareInstance];
    style.navigationBarColor = nil;
    style.navigationTintColor = nil;
    style.navigationTitleHidden = NO;
    style.cameraProgressBarOnBottom = NO;
    style.cameraLineColor = nil;
    style.cameraProgressColor = nil;
    style.useTaoVideoActionBar = NO;
    style.useDefaultCover = NO;
    style.stopAtEditController = NO;
    style.useTaoVideoBgmPicker = NO;
}

- (void)taoVideoStyle {
    AKCameraStyle *style = [AKCameraStyle shareInstance];
    style.navigationBarColor = [UIColor blackColor];
    style.navigationTintColor = [UIColor whiteColor];
    style.navigationTitleHidden = YES;
    style.cameraProgressBarOnBottom = YES;
    style.cameraLineColor = [UIColor colorWithRed:237/255.0f green:75/255.0f blue:28/255.0f alpha:1];
    style.cameraProgressColor = [UIColor colorWithRed:117/255.0f green:185/255.0f blue:48/255.0f alpha:1];
    style.useTaoVideoActionBar = YES;
    style.useDefaultCover = YES;
    style.stopAtEditController = YES;
    style.useTaoVideoBgmPicker = YES;
}

#pragma mark - AKCameraToolDelegate
- (void)akCameraNeedLocation {
    // 提供地理位置
    NSDictionary *location = @{@"province" : @"浙江省", @"city" : @"杭州市", @"district" : @"余杭区", @"poiName" : @"小拇指洗车", @"poiAddress" : @"文一西路969号", @"lat" : @"30.281332", @"lng" : @"120.02857"};
    [[AKCameraTool shareInstance] delegateRequestLocationFinish:location];
}

- (NSArray *)akCameraNeedNearbyLocations:(NSDictionary *)currentLocation {
    if (currentLocation) {
        float lat = [[currentLocation objectForKey:@"lat"] floatValue];
        float lng = [[currentLocation objectForKey:@"lng"] floatValue];
    }
    // 提供附近的地理位置，让用户可以纠偏
    NSDictionary *location1 = @{@"province" : @"浙江省", @"city" : @"杭州市", @"district" : @"余杭区", @"poiName" : @"小拇指洗车", @"poiAddress" : @"文一西路969号", @"lat" : @"30.281332", @"lng" : @"120.02857"};
    NSDictionary *location2 = @{@"province" : @"浙江省", @"city" : @"杭州市", @"district" : @"余杭区", @"poiName" : @"淘宝城汽车美容店(西溪园区)", @"poiAddress" : @"文一西路 附近", @"lat" : @"30.280964", @"lng" : @"120.02845"};
    NSDictionary *location3 = @{@"province" : @"浙江省", @"city" : @"杭州市", @"district" : @"余杭区", @"poiName" : @"大华西溪风情(西南门)", @"poiAddress" : @"文一西路与常二路交叉口", @"lat" : @"30.277943", @"lng" : @"120.031746"};
    return @[location1, location2, location3];
}

- (NSArray *)akCameraNeedChannels {
    // 频道列表
    NSArray *channel1 = @[@(1), @"频道一"];
    NSArray *channel2 = @[@(2), @"频道二"];
    NSArray *channel3 = @[@(3), @"频道三"];
    return @[channel1, channel2, channel3];
}

- (NSArray *)akCameraNeedBgms {
    // 背景音乐，可以不提供，会使用来自AKCamera.bundle默认的背景音乐，可以提供url下载(最后一个参数为url即可)，格式要求为caf
    NSArray *bgm1 = @[@"夏天", @"bgm_cover_1.png", @"Summer.caf"];
    NSArray *bgm2 = @[@"IBelieve", @"bgm_cover_2.png", @"IBelieve.caf"];
    NSArray *bgm3 = @[@"弥撒", @"bgm_cover_3.png", @"TheMass.caf"];
    NSArray *bgm4 = @[@"战歌", @"bgm_cover_4.png", @"ZG.caf"];
    NSArray *bgm5 = @[@"卡农", @"bgm_cover_5.png", @"KN.caf"];
    NSArray *bgm6 = @[@"小星星", @"bgm_cover_6.png", @"XXX.caf"];
    NSArray *bgm7 = @[@"钢琴曲", @"bgm_cover_7.png", @"GQQ.caf"];
    NSArray *bgm8 = @[@"旅行", @"bgm_cover_8.png", @"LX.caf"];
    NSArray *bgm9 = @[@"日记", @"bgm_cover_9.png", @"Diary.caf"];
    NSArray *bgm10 = @[@"蒂塔", @"bgm_cover_10.png", @"DT.caf"];
    return @[bgm1, bgm2, bgm3, bgm4, bgm5, bgm6, bgm7, bgm8, bgm9, bgm10];
}

- (void)akCameraWillFinished:(AKVideo *)video asDraft:(BOOL)asDraft {
    // 添加到本地视频
    // asDraft 表示是否取消拍摄的时候选择了保存到草稿箱
    [[AKCameraTool shareInstance] syncDataToCache]; // 保存到缓存
}

#pragma mark - AKCameraEditDelegate
- (void)akCameraEditWillFinish {
    // 这个Delegate是用于重新编辑视频使用的，编辑完成之后进行更新回调
}

@end
