//
//  AKCameraEditViewController.m
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraEditViewController.h"
#import "AKCameraThumbnailPicker.h"
#import "AKCameraVideoPreview.h"
#import "AKCameraSoundTrackView.h"
#import "AKCameraProgressHUD.h"
#import "AKCameraUtils.h"
#import "AKCameraMessageHUD.h"
#import "AKCameraExporter.h"
#import "AKCameraBGM.h"
#import "AKCameraBGMCell.h"
#import "AKCameraTool.h"
#import "AKCameraSaveViewController.h"

@interface AKCameraEditViewController ()<ThumbnailPickerViewDataSource,ThumbnailPickerViewDelegate, AKCameraVideoPreviewDelegate, UITableViewDataSource, UITableViewDelegate, AKCameraBGMCellDelegate, UIAlertViewDelegate, AKCameraProgressHUDDelegate, AKCameraSoundTrackViewDelegate>
{
    NSURL *_exportVideoFileUrl;
    AVAudioPlayer *_audioPlayer; // Player for BGM
    AVAssetExportSession *exporter;
    BOOL exportFinished;
    AKCameraBGMCell *bgmSelected;
}
@property (retain, nonatomic)AKCameraThumbnailPicker *thumbnailPickerView;
@property (strong,nonatomic)AKCameraVideoPreview *previewVideoView;
@property (strong, nonatomic)UIView *clipFrameView;
@property (strong, nonatomic)UIButton *converButton;
@property (strong, nonatomic)UIButton *soundTrackButton;
@property (strong, nonatomic)UIView *bottomView;
@property (nonatomic,strong)UIScrollView *bgmScrollView;
@property (nonatomic,strong)AKCameraSoundTrackView *soundTrackView;
@property (nonatomic,strong)AKCameraProgressHUD *progressHUD;
@property (nonatomic, strong)UITableView *contentView;
@property (nonatomic, strong)UILabel *coverHint_1;
@property (nonatomic, strong)UILabel *coverHint_2;
@property (nonatomic, strong)UIView *coverHintWrapper;

// TaoVideo
@property (nonatomic, strong)UIView *taoVideoBgmPickerWrapper;
@property (nonatomic, strong)UIScrollView *taoVideoBgmPicker;
@end

@implementation AKCameraEditViewController

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
}

- (void)layoutViews {
    [self setNaviBarTitle:@"编辑"];
    [self setNaviBarLeftBtnTitle:@"拍摄"];
    //[self hideBottomLine];
    //UIButton *cancelButton = [AKCameraNavigationBar createNormalNaviBarBtnByTitle:@"取消" target:self action:@selector(cancel:)];
    //[self setNaviBarLeftBtn:cancelButton];
    
    // 创建一个自定义的按钮，并添加到导航条右侧。
    UIButton *rightButton = nil;
    if ([AKCameraStyle stopAtEditController]) {
        rightButton = [AKCameraNavigationBar createNormalNaviBarBtnByTitle:@"上传" target:self action:@selector(next:)];
    } else {
        rightButton = [AKCameraNavigationBar createNormalNaviBarBtnByTitle:@"下一步" target:self action:@selector(next:)];
    }
    [self setNaviBarRightBtn:rightButton];
    
    // Add contentview
    [self.view addSubview:self.contentView];
    
    if (![AKCameraStyle useDefaultCover]) {
        CGRect r = self.bottomView.frame;
        r.origin.y = self.contentView.frame.size.height;
        self.bottomView.frame = r;
        [self.view addSubview:self.bottomView];
        // Do any additional setup after loading the view from its nib.
        if (_images && [_images count] > 0) {
            [self configThumbnailPicker];
        } else {
            [AKCameraMessageHUD show:@"请稍等..."];
            _images = [[NSMutableArray alloc] init];
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                [self getFramesFromVideo];
            });
        }
    } else {
        UIImage *cover = nil;
        if (_fromLocal) {
            cover = [UIImage imageWithContentsOfFile:[[_video getCoverPath] path]];
        } else {
            cover = [_images objectAtIndex:0];
        }
        [self.previewVideoView setClipImage:cover]; // default cover
    }
    
    [self configPlayer];
    [self layoutBGMs];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationDidEnterBackground:) name:@"UIApplicationDidEnterBackgroundNotification" object:[UIApplication sharedApplication]];
}

- (void)configThumbnailPicker {
    //忽略静音开关
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    if ([_images count] > 0) {
        [self.previewVideoView setClipImage:[_images objectAtIndex:0]];
        [self.thumbnailPickerView reloadData]; //reload data
        [self.thumbnailPickerView setSelectedIndex:[_video.coverSelectedIndex intValue]];
    }
    
    [self showCoverSelection:YES];
}

- (void)configPlayer {
    //忽略静音开关
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [self.previewVideoView config:_fromLocal ? [_video getVideoPath] : nil];
}

- (void)layoutBGMs {
    // Config ScrollView
    float x = 6, y = 6, width = 50, height = 68;
    UIScrollView *scrollView = nil;
    if ([AKCameraStyle useTaoVideoBgmPicker]) {
        x = 10;
        width = 47;
        scrollView = self.taoVideoBgmPicker;
    } else {
        scrollView = self.bgmScrollView;
    }
    
    AKCameraBGM *bgms = [AKCameraBGM shareInstance];
    bgms.items = [NSMutableArray array];
    // 添加原音选择
    BGMItem *originalItem = [BGMItem itemWithName:@"原始" path:nil cover:@"bgm_cover_0.png" url:nil];
    [bgms.items addObject:originalItem];
    
    NSArray *originals = [[AKCameraTool shareInstance].delegate akCameraNeedBgms];
    for (NSArray *arr in originals) {
        NSString *pathString = [arr objectAtIndex:2];
        if ([pathString hasPrefix:@"http://"]) {
            // 需要下载
            [bgms.items addObject:[BGMItem itemWithName:[arr objectAtIndex:0] path:nil cover:[arr objectAtIndex:1] url:[arr objectAtIndex:2]]];
        } else {
            [bgms.items addObject:[BGMItem itemWithName:[arr objectAtIndex:0] path:[arr objectAtIndex:2] cover:[arr objectAtIndex:1] url:nil]];
        }
    }
    
    CGRect r = scrollView.bounds;
    r.size.width = x + [bgms.items count] * (width + x);
    scrollView.contentSize = r.size;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.showsHorizontalScrollIndicator = NO;
    
    BOOL firstSelected = NO;
    for (BGMItem *item in bgms.items) {
        AKCameraBGMCell *cell = [[AKCameraBGMCell alloc] initWithFrame:CGRectMake(x, y, width, height)];
        cell.item = item;
        if (!firstSelected) {
            firstSelected = YES;
            cell.selected = YES;
            bgmSelected = cell;
        }
        [scrollView addSubview:cell];
        cell.delegate = self;
        x += width + 6;
    }
}

- (void)showCoverSelection:(BOOL)show {
    if (show) {
        _converButton.selected = YES;
        _soundTrackButton.selected = NO;
        _soundTrackView.hidden = YES;
        _bgmScrollView.hidden = YES;
        _thumbnailPickerView.hidden = NO;
        _coverHintWrapper.hidden = NO;
        if ([_previewVideoView isPlaying]) {
            [_previewVideoView stop];
        }
        if (_audioPlayer.isPlaying) {
            [_audioPlayer pause];
            [_audioPlayer setCurrentTime:0.0f];
        }
    }else{
        _converButton.selected = NO;
        _soundTrackButton.selected = YES;
        _soundTrackView.hidden = NO;
        _bgmScrollView.hidden = NO;
        //DLog(@"%@", NSStringFromCGRect(_bgmScrollView.frame));
        //DLog(@"%@", _bgmScrollView.superview);
        _thumbnailPickerView.hidden = YES;
        _coverHintWrapper.hidden = YES;
    }
}


- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    //self.navigationController.navigationBarHidden = NO;
    if (_exportVideoFileUrl) {
        // delete
        [AKCameraUtils deleteFile:_exportVideoFileUrl];
        _exportVideoFileUrl = Nil;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    if (exporter) {
        [exporter cancelExport];
        exporter = Nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - HandleBackActions
- (BOOL)willGoBack {
    [self cancel:nil];
    return NO;
}

#pragma mark - Actions
- (void)coverClick:(id)sender{
    [self showCoverSelection:YES];
}

- (void)soundClick:(id)sender{
    [self showCoverSelection:NO];
}

- (void)cancel:(id)sender {
    if ([self.navigationController.viewControllers count] == 1) {
        [self dismissViewControllerAnimated:YES completion:nil]; // Just dismiss
    } else {
        if ([AKCameraTool shareInstance].maxSeconds >= 60) {
            // 60s, No segements
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"温馨提示" message:@"要放弃这段视频吗？" delegate:self cancelButtonTitle:@"点错了" otherButtonTitles:@"是",nil];
            alert.tag = 101;
            [alert show];
        } else {
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
}

- (void)next:(id)sender {
    // Stop play
    [self.previewVideoView stop];
    [_audioPlayer stop];
    
    // Check url first
    if (!_video.videoFileName) {
        NSURL *url = [[AKCameraExporter shareInstance] checkExportOutputURL];
        // Check file exist
        if (![[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
            [AKCameraMessageHUD showError:@"视频文件生成失败...请重新拍摄"];
            return;
        }
        NSArray *parts = [[url absoluteString] componentsSeparatedByString:@"/"];
        _video.videoFileName = [parts lastObject];
        if (!_video.videoFileName) {
            if (!exportFinished) {
                [AKCameraMessageHUD show:@"视频文件正在生成..."];
            } else{
                [AKCameraMessageHUD showError:@"视频文件生成失败...请重新拍摄"];
            }
            return;
        }
    }
    if (!_video.coverFileName) {
        NSString *clipfileName = [AKCameraUtils saveCoverFile:_video.defaultCover ? _video.defaultCover :[_images objectAtIndex:[_video.coverSelectedIndex intValue]] with:[AKCameraUtils uniqueCoverFilenameWithPrefix:@"clip"]];
        if ( clipfileName == nil) {
            [AKCameraMessageHUD showError:@"亲，保存封面失败，请重新选择选择封面！"];
            return;
        }
        _video.coverFileName = clipfileName;
    }
    
    BOOL hasBGM = bgmSelected && ![bgmSelected.item.name isEqualToString:@"原始"] && (!_soundTrackView || _soundTrackView.value > 0);
    if (hasBGM) {
        // Need merge audio
        CGFloat v = 0;
        CGFloat a = 1;
        if (_soundTrackView) {
            v = 1 - _soundTrackView.value;
            a =  _soundTrackView.value;
        }
        NSDictionary *dict = @{@"video":@(v),@"audio":@(a)};
        [self performSelectorInBackground:@selector(exportVideo:) withObject:dict];
    } else {
        [self saveDataAndGoNextView];
    }
}

- (void)saveDataAndGoNextView{
    [_progressHUD hide:YES];
    
    AKCameraSaveViewController *mvc = nil;
    if (![AKCameraStyle stopAtEditController]) {
        mvc = [[AKCameraSaveViewController alloc]init];
    }
    if (_exportVideoFileUrl) {
        NSError *error = Nil;
        NSDictionary * fileAttributes = [_exportVideoFileUrl resourceValuesForKeys:[NSArray arrayWithObject:NSURLFileSizeKey] error:NULL];
        if (fileAttributes == nil || error != nil) {
            //DLog(@"文件大小计算出错！err=%@",error.localizedDescription);
        }else{
            _video.videoFileSize = [fileAttributes objectForKey:NSURLFileSizeKey];
            //DLog(@"文件大小：%ld", [_video.videoFileSize longValue]);
        }
        
        // update path
        mvc.videoFileUrlBeforeExport = [_video getVideoPath];
        if (_exportVideoFileUrl && ![[_exportVideoFileUrl absoluteString] isEqualToString:@""]) {
            NSArray *parts = [[_exportVideoFileUrl absoluteString] componentsSeparatedByString:@"/"];
            _video.videoFileName = [parts lastObject];
        }
    }
    
    if (mvc) {
        mvc.video = _video;
        [self.navigationController pushViewController:mvc animated:YES];
    } else {
        // finished
        [self finish];
    }
}

- (void)finish {
    // 进行数据保存
    if (!_fromLocal) {
        [(id<AKCameraInternalDelegate>)[AKCameraTool shareInstance] akCameraSaveWillFinish];
        [self dismissViewControllerAnimated:YES completion:nil];
    } else if (_delegate) {
        [_delegate akCameraEditWillFinish];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark UIAlertView delegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (alertView.tag == 102 || buttonIndex == 1) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - App NSNotifications
- (void)_applicationDidEnterBackground:(NSNotification *)notification
{
    [self.previewVideoView pause];
    if (_audioPlayer.isPlaying) {
        [_audioPlayer stop];
    }
}

#pragma mark - Table view data source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    if (indexPath.row == 0) {
        //first row
        cell = [tableView dequeueReusableCellWithIdentifier:@"firstRow"];
        if (!cell) {
            //create new cell
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"firstRow"];
            [cell setBackgroundColor:[UIColor clearColor]];
            [cell addSubview:self.previewVideoView];
        }
        
    }else if(indexPath.row == 1){
        //second row
        cell = [tableView dequeueReusableCellWithIdentifier:@"secondRow"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"secondRow"];
            [cell setBackgroundColor:[UIColor clearColor]];
            if ([AKCameraStyle useTaoVideoBgmPicker]) {
                [cell addSubview:self.taoVideoBgmPickerWrapper];
            } else {
                [cell addSubview:self.clipFrameView];
            }
        }
    }
    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    return cell;
}

#pragma mark - TableViewDelegate Methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    CGFloat height = 0;
    if (indexPath.row == 0) {
        height = self.previewVideoView.bounds.size.height;
    }else if(indexPath.row == 1){
        if ([AKCameraStyle useTaoVideoBgmPicker]) {
            height = self.taoVideoBgmPickerWrapper.bounds.size.height;
        } else {
            height = self.clipFrameView.bounds.size.height;
        }
        
    }
    return height;
}

#pragma mark - AKCameraVideoPreviewDelegate
- (void)previewVideoViewPause:(AKCameraVideoPreview *)sender{
    if (_audioPlayer) {
        [_audioPlayer pause];
    }
}
- (void)previewVideoViewPlay:(AKCameraVideoPreview *)sender{
    if (_audioPlayer) {
        [_audioPlayer play];
    }
}
- (void)previewVideoViewStop:(AKCameraVideoPreview *)sender{
    if (_audioPlayer) {
        [_audioPlayer pause];
        [_audioPlayer setCurrentTime:0.0f];
    }
}

#pragma mark - AKCameraExporterDelegate
- (void)akExporterDidPauseVideoCaptureFailed:(AKCameraExporter *)akExporter {
    // 暂停或结束失败
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"非常抱歉！视频文件生成失败，请重新拍摄." delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
    alert.tag = 102;
    [alert show];
    return;
}
- (void)akExporterDidExportMovie:(AKCameraExporter *)akExporter movieUrl:(NSURL *)url{
    exportFinished = YES;
    // Set path
    if (!url) {
        //文件生成失败
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"非常抱歉！视频文件生成失败，请重新拍摄." delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
        alert.tag = 102;
        [alert show];
        return;
    }
    
    NSError *error = nil;
    NSDictionary * fileAttributes = [url resourceValuesForKeys:[NSArray arrayWithObject:NSURLFileSizeKey] error:NULL];
    if (fileAttributes == nil || error != nil) {
        //DLog(@"文件大小计算出错！err=%@",error.localizedDescription);
        _video.videoFileSize = @(0);
    }else{
        _video.videoFileSize = [fileAttributes objectForKey:NSURLFileSizeKey];
        //DLog(@"文件大小：%ld", [_video.videoFileSize longValue]);
    }
    if (_exportVideoFileUrl && ![[_exportVideoFileUrl absoluteString] isEqualToString:@""]) {
        NSArray *parts = [[_exportVideoFileUrl absoluteString] componentsSeparatedByString:@"/"];
        _video.videoFileName = [parts lastObject];
    }
    
    [AKCameraMessageHUD dismiss]; //可能正在显示文件生成.
}

#pragma mark - AKCameraThumbnailPicker data source

- (NSUInteger)numberOfImagesForThumbnailPickerView:(AKCameraThumbnailPicker *)thumbnailPickerView
{
    return [_images count];
}

- (UIImage *)thumbnailPickerView:(AKCameraThumbnailPicker *)thumbnailPickerView imageAtIndex:(NSUInteger)index
{
    UIImage *image = [self.images objectAtIndex:index];
    usleep(10*1000);
    return image;
}

#pragma mark - ThumbnailPickerView delegate
- (void)thumbnailPickerView:(AKCameraThumbnailPicker *)thumbnailPickerView didSelectImageWithIndex:(NSUInteger)index
{
    [self.previewVideoView setClipImage:[_images objectAtIndex:index]];
    _video.coverSelectedIndex = @(index);
}

#pragma mark soundtrackdelegate
- (void)soundTrackViewValueChange:(CGFloat)value{
    if (_audioPlayer) {
        [_audioPlayer setVolume:(value)];
    }
    [self.previewVideoView setVolume:1 - value];
}

#pragma mark - AKCameraBGMCell delegate
- (void)akCameraBGMCellTapped:(AKCameraBGMCell *)cell {
    if (cell.selected) {
        return; // Has been selected
    }
    // Unselect others
    if ([AKCameraStyle useTaoVideoBgmPicker]) {
        for (UIView *view in self.taoVideoBgmPicker.subviews) {
            if (![view isEqual:cell] && [view isKindOfClass:[AKCameraBGMCell class]]) {
                [(AKCameraBGMCell *)view setSelected:NO];
            }
        }
    } else {
        for (UIView *view in self.bgmScrollView.subviews) {
            if (![view isEqual:cell] && [view isKindOfClass:[AKCameraBGMCell class]]) {
                [(AKCameraBGMCell *)view setSelected:NO];
            }
        }
    }
    
    [cell setSelected:YES];
    bgmSelected = cell;
    
    [self.previewVideoView playerReset];
    if (_audioPlayer) {
        [_audioPlayer pause];
    }
    if ([cell.item.name isEqualToString:@"原始"]) {
        if (_audioPlayer) {
            [_audioPlayer pause];
            _audioPlayer = nil;
        }
        [self.previewVideoView setVolume:1.0f];
        [_soundTrackView setSliderValue:0];
        [self.previewVideoView play];
    }else{
        
        [_soundTrackView setSliderValue:1.0f];
        [self.previewVideoView setVolume:0];
        [self.previewVideoView play];
        
        // Play audio
        NSString *audioPath =[[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:cell.item.path];
        _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:audioPath] error:nil];
        [_audioPlayer prepareToPlay];
        [_audioPlayer play];
    }
}

#pragma mark - Progress
- (void)showWithLabelDeterminate{
    _progressHUD = [[AKCameraProgressHUD alloc] initWithView:self.navigationController.view];
	[self.navigationController.view addSubview:_progressHUD];
	
    // Set determinate mode
    _progressHUD.mode = AKCameraProgressHUDModeDeterminate;
    
	_progressHUD.delegate = self;
    _progressHUD.labelText = @"视频压缩中";
	
	// myProgressTask uses the _progressHUD instance to update progress
    [_progressHUD showWhileExecuting:@selector(myProgressTask) onTarget:self withObject:nil animated:YES];
    
}

#pragma mark AKCameraProgressHUDDelegate methods
- (void)hudWasHidden:(AKCameraProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [_progressHUD removeFromSuperview];
	_progressHUD = nil;
}

- (void)myProgressTask {
    // This just increases the progress indicator in a loop
    float progress = 0.0f;
    while (progress < 1.0f) {
        progress = exporter.progress;
        _progressHUD.progress = progress;
        usleep(50000);
    }
    
}

#pragma mark - Utils
- (void)getFramesFromVideo{
    dispatch_queue_t queue = dispatch_queue_create("frame", NULL);
    dispatch_semaphore_t s_task = dispatch_semaphore_create(0);
    
    dispatch_block_t blcock1 = ^(void){
        _images = [AKCameraUtils extractImagesFromMovie:[_video getVideoPath]];
        dispatch_semaphore_signal(s_task);
    };
    dispatch_async(queue, blcock1);
    
    dispatch_semaphore_wait(s_task, DISPATCH_TIME_FOREVER);
    //dispatch_release(s_task);
    //dispatch_release(queue);
    __unsafe_unretained AKCameraEditViewController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong AKCameraEditViewController *strongSelf = weakSelf;
        [strongSelf.previewVideoView setClipImage:[_images objectAtIndex:0]];
        [strongSelf.thumbnailPickerView reloadData]; //reload data
        [strongSelf.thumbnailPickerView setSelectedIndex:[_video.coverSelectedIndex intValue]];
        [AKCameraMessageHUD dismiss]; // Dismiss loading
    });
    
}

- (void)exportVideo:(NSDictionary *)dict{
    if (exporter) {
        exporter = nil;
    }
    
    if (!_video.videoFileName) {
        [_video setVideoFilePath:[[AKCameraExporter shareInstance] checkExportOutputURL]];
        if (!_video.videoFileName) {
            [AKCameraMessageHUD showError:@"视频文件生成失败."];
            return;
        }
    }
    
    AVMutableComposition *composition = [AVMutableComposition composition];
    NSString *audioPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:bgmSelected.item.path];
    NSURL*    audio_inputFileUrl = [NSURL fileURLWithPath:audioPath];
    NSURL*    video_inputFileUrl = [_video getVideoPath];
    
    AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:video_inputFileUrl options:nil];
    AVMutableCompositionTrack *compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVAssetTrack *vt = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    if (![compositionVideoTrack insertTimeRange:vt.timeRange ofTrack:vt atTime:kCMTimeZero error:nil]) {
        //DLog(@"insert video failed");
    }
    
    float audioVolume = [[dict objectForKey:@"audio"] floatValue];
    float videoVolume = [[dict objectForKey:@"video"] floatValue];
    NSMutableArray *audioMixParams = [NSMutableArray array];
    [self setUpAndAddAudioAtPath:audio_inputFileUrl toComposition:composition start:kCMTimeZero dura:vt.timeRange.duration offset:kCMTimeZero startVolume:audioVolume endVolume:audioVolume addTo:audioMixParams];
    [self setUpAndAddAudioAtPath:video_inputFileUrl toComposition:composition start:kCMTimeZero dura:vt.timeRange.duration offset:kCMTimeZero startVolume:videoVolume endVolume:videoVolume addTo:audioMixParams];
    
    exporter = [[AVAssetExportSession alloc]initWithAsset:composition presetName:AVAssetExportPreset640x480];
    exporter.outputFileType = ([[[UIDevice currentDevice] systemVersion] floatValue] < 6.0 ? AVFileTypeQuickTimeMovie : kRecordFileType);
    exporter.outputURL = [NSURL fileURLWithPath:[[AKCameraUtils getVideoPath] stringByAppendingPathComponent:[AKCameraUtils uniqueMovieFileNameWithPrefix:@"export" notIn:nil]]];
    AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
    audioMix.inputParameters = [NSArray arrayWithArray:audioMixParams];
    exporter.audioMix = audioMix;
    
    // do the export
    __block __unsafe_unretained AKCameraEditViewController *weakSelf = self;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        AVAssetExportSessionStatus exportStatus = exporter.status;
        switch (exportStatus) {
            case AVAssetExportSessionStatusFailed:{
                NSError *exportError = exporter.error;
                NSLog (@"AVAssetExportSessionStatusFailed: %@", exportError);
                [AKCameraMessageHUD showError:@"生成视频失败"];
                break;
            }
            case AVAssetExportSessionStatusCompleted:{
                //DLog (@"AVAssetExportSessionStatusCompleted");
                dispatch_async(dispatch_get_main_queue(), ^{
                    _exportVideoFileUrl = exporter.outputURL;
                    __strong AKCameraEditViewController *strongSelf = weakSelf;
                    [strongSelf saveDataAndGoNextView];
                });
                break;
            }
            default:
                [AKCameraMessageHUD showError:@"生成视频失败"];
                //DLog (@"didn't get export status");
                break;
                
        }
    }];
    [self showWithLabelDeterminate];
}

- (void) setUpAndAddAudioAtPath:(NSURL*)assetURL toComposition:(AVMutableComposition *)composition start:(CMTime)start dura:(CMTime)dura offset:(CMTime)offset startVolume:(CGFloat )startVolume endVolume:(CGFloat)endVolume addTo:(NSMutableArray *)audioMixParams{
    AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL:assetURL options:nil];
    AVMutableCompositionTrack *track = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    AVAssetTrack *sourceAudioTrack = [[songAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    
    NSError *error = nil;
    
    CMTime startTime = start;
    CMTime trackDuration = dura;
    CMTimeRange tRange = CMTimeRangeMake(startTime, trackDuration);
    
    //Set Volume
    AVMutableAudioMixInputParameters *trackMix = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:track];
    [trackMix setVolumeRampFromStartVolume:startVolume toEndVolume:endVolume timeRange:CMTimeRangeMake(kCMTimeZero, composition.duration)];
    //        [trackMix setVolume:0.8f atTime:startTime];
    [audioMixParams addObject:trackMix];
    
    //Insert audio into track  //offset CMTimeMake(0, 44100)
    if(![track insertTimeRange:tRange ofTrack:sourceAudioTrack atTime:offset error:&error]){
        //DLog(@"insertTimeRange failed");
    }
}

#pragma mark - Getter
- (UITableView *)contentView{
    if (!_contentView) {
        //table view
        CGRect r = self.view.bounds;
        r.origin.y += 44; //default is 0
        //r.size.height -= 20 + 44;
        /*
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
            //r.origin.y += 20; //default is 0
            //r.size.height -= 20;
        } else {
            r.origin.y = 0; //default is 20
        }
        */
        if (![AKCameraStyle useTaoVideoBgmPicker]) {
            r.size.height -= self.bottomView.bounds.size.height;
        }
        
        _contentView = [[UITableView alloc] initWithFrame:r];
        [_contentView setBackgroundColor:[UIColor clearColor]];
        _contentView.dataSource = self;
        _contentView.delegate = self;
        _contentView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    return _contentView;
}

- (AKCameraVideoPreview *)previewVideoView{
    if (!_previewVideoView) {
        _previewVideoView = [[AKCameraVideoPreview alloc]initWithFrame:CGRectMake(0, 0, 320, 320)];
        _previewVideoView.delegate = self;
    }
    return _previewVideoView;
}

- (UIButton *)converButton{
    if (!_converButton) {
        _converButton = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 160, 45)];
        [_converButton setBackgroundImage:[UIImage imageNamed:@"AKCamera.bundle/cover_btn_n"] forState:UIControlStateNormal];
        [_converButton setBackgroundImage:[UIImage imageNamed:@"AKCamera.bundle/cover_btn_h"] forState:UIControlStateHighlighted];
        [_converButton setBackgroundImage:[UIImage imageNamed:@"AKCamera.bundle/cover_btn_h"] forState:UIControlStateSelected];
        [_converButton addTarget:self action:@selector(coverClick:) forControlEvents:UIControlEventTouchUpInside];
        _converButton.selected = YES;
    }
    return _converButton;
}

- (UIButton *)soundTrackButton{
    if (!_soundTrackButton) {
        _soundTrackButton = [[UIButton alloc]initWithFrame:CGRectMake(160, 0, 160, 45)];
        [_soundTrackButton setBackgroundImage:[UIImage imageNamed:@"AKCamera.bundle/music_btn_n"] forState:UIControlStateNormal];
        [_soundTrackButton setBackgroundImage:[UIImage imageNamed:@"AKCamera.bundle/music_btn_h"] forState:UIControlStateHighlighted];
        [_soundTrackButton setBackgroundImage:[UIImage imageNamed:@"AKCamera.bundle/music_btn_h"] forState:UIControlStateSelected];
        [_soundTrackButton addTarget:self action:@selector(soundClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _soundTrackButton;
}

- (UIView *)bottomView{
    if (!_bottomView) {
        _bottomView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 320, 50)];
        _bottomView.backgroundColor = [AKCameraStyle colorForNavigationBar];
        [_bottomView addSubview:[AKCameraStyle lineForTopCell:_bottomView]];
        UIView *middleLine = [AKCameraStyle lineForMiddleCell:_bottomView];
        CGRect r = middleLine.frame;
        r.origin.x = 160;
        r.origin.y = 0;
        r.size.width = 0.5;
        r.size.height = 50;
        middleLine.frame = r;
        [_bottomView addSubview:middleLine];
        [_bottomView addSubview:self.converButton];
        [_bottomView addSubview:self.soundTrackButton];
    }
    return _bottomView;
}

- (UILabel *)coverHint_1{
    if (!_coverHint_1) {
        _coverHint_1 = [[UILabel alloc] init];
        _coverHint_1.textColor = [AKCameraStyle colorForHightlight];
        _coverHint_1.backgroundColor = [UIColor clearColor];
        _coverHint_1.font = [UIFont systemFontOfSize:22];
        _coverHint_1.text = @"滑动";
        [_coverHint_1 sizeToFit];
    }
    return _coverHint_1;
}

- (UILabel *)coverHint_2{
    if (!_coverHint_2) {
        _coverHint_2 = [[UILabel alloc] init];
        _coverHint_2.textColor = [AKCameraStyle colorForHightlight];
        _coverHint_2.backgroundColor = [UIColor clearColor];
        _coverHint_2.font = [UIFont systemFontOfSize:16];
        _coverHint_2.text = @"选择封面";
        [_coverHint_2 sizeToFit];
    }
    return _coverHint_2;
}

- (UIView *)coverHintWrapper{
    if (!_coverHintWrapper) {
        CGFloat height = self.coverHint_1.frame.size.height;
        CGFloat width = self.coverHint_1.frame.size.width + self.coverHint_2.frame.size.width;
        _coverHintWrapper = [[UIView alloc] initWithFrame:CGRectMake((320 - width) / 2, 60 + (self.clipFrameView.frame.size.height - 60 - height) / 2, width, height)];
        [_coverHintWrapper addSubview:_coverHint_1];
        CGRect r = self.coverHint_2.frame;
        r.origin.x = self.coverHint_1.frame.size.width;
        r.origin.y = (height - r.size.height) / 2;
        self.coverHint_2.frame = r;
        [_coverHintWrapper addSubview:self.coverHint_2];
    }
    return _coverHintWrapper;
}

- (AKCameraThumbnailPicker *)thumbnailPickerView{
    if (!_thumbnailPickerView) {
        _thumbnailPickerView = [[AKCameraThumbnailPicker alloc]initWithFrame:CGRectMake(0, 0, 300, 50)];
        _thumbnailPickerView.dataSource = self;
        _thumbnailPickerView.delegate = self;
        _thumbnailPickerView.thumbnailSize = CGSizeMake(42, 42);
        _thumbnailPickerView.bigThumbnailSize = CGSizeMake(50, 50);
    }
    return _thumbnailPickerView;
}

- (UIScrollView *)bgmScrollView{
    if (!_bgmScrollView) {
        _bgmScrollView	= [[UIScrollView alloc] initWithFrame:CGRectMake(0.0f, 60, 320, (140 - 60))];
        _bgmScrollView.backgroundColor = [UIColor clearColor];
        _bgmScrollView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    }
    return _bgmScrollView;
}

- (UIView *)clipFrameView{
    if (!_clipFrameView) {
        _clipFrameView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 320, 140)];
        [_clipFrameView addSubview:self.bgmScrollView];
        self.bgmScrollView.hidden = YES;
        UIView *leaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 60)];
        leaderView.backgroundColor = [AKCameraStyle colorForNavigationBar];
        leaderView.layer.shadowColor = [UIColor lightGrayColor].CGColor;
        leaderView.layer.shadowOffset = CGSizeMake(0, 2);
        leaderView.layer.shadowOpacity = 0.2;
        [_clipFrameView addSubview:leaderView];
        CGRect r = self.thumbnailPickerView.frame;
        r.origin.x = (320 - r.size.width) / 2;
        r.origin.y = (60 - r.size.height) / 2;
        self.thumbnailPickerView.frame = r;
        [_clipFrameView addSubview:self.thumbnailPickerView];
        [_clipFrameView addSubview:self.coverHintWrapper];
        [_clipFrameView addSubview:self.soundTrackView];
        self.soundTrackView.hidden = YES;
    }
    return _clipFrameView;
}

- (AKCameraSoundTrackView *)soundTrackView{
    if (!_soundTrackView) {
        _soundTrackView = [[AKCameraSoundTrackView alloc] initWithFrame:CGRectMake(0, 0, 320, 60)];
        _soundTrackView.delegate = self;
    }
    return _soundTrackView;
}

#pragma mark - TaoVideoBgmPicker
- (UIView *)taoVideoBgmPickerWrapper {
    if (!_taoVideoBgmPickerWrapper) {
         _taoVideoBgmPickerWrapper = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 320, 100)];
        _taoVideoBgmPickerWrapper.backgroundColor = [UIColor clearColor];
        UILabel *l = [[UILabel alloc] init];
        l.text = @"选择背景音乐";
        l.textColor = [UIColor whiteColor];
        l.backgroundColor = [UIColor clearColor];
        l.font = [UIFont systemFontOfSize:13.0f];
        [l sizeToFit];
        l.frame = CGRectMake(6, 6, l.bounds.size.width, l.bounds.size.height);
        [_taoVideoBgmPickerWrapper addSubview:l];
        [_taoVideoBgmPickerWrapper addSubview:self.taoVideoBgmPicker];
    }
    return _taoVideoBgmPickerWrapper;
}

- (UIScrollView *)taoVideoBgmPicker {
    if (!_taoVideoBgmPicker) {
        _taoVideoBgmPicker	= [[UIScrollView alloc] initWithFrame:CGRectMake(0.0f, 20, 320, 80)];
        _taoVideoBgmPicker.backgroundColor = [UIColor clearColor];
        _taoVideoBgmPicker.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    }
    return _taoVideoBgmPicker;
}

@end
