//
//  AKRecordView.m
//  aikan
//
//  Created by lihejun on 14-1-13.
//  Copyright (c) 2014年 taobao. All rights reserved.
//

#import "AKCameraRecordView.h"
#import "AKRecordProgressView.h"
#import "AKCameraCaputure.h"
#import "AKCameraExporter.h"
#import "AKCameraUtils.h"
#import "AKCameraTool.h"
#import "AKCameraFocusView.h"
#import "UIImage+AKExtension.h"
#import "AKCameraStyle.h"
#import "AKCameraMessageHUD.h"

#define defaultFrameRate 30
#define filtersEnabled NO
#define extraProgress 0.05f

NSString * const AKCameraVideoInfoKey = @"AKCameraVideoInfoKey";

@interface AKCameraRecordView()<AKCameraCaputureDelegate, AKCameraExporterDelegate>
{
    CGFloat _needSeconds; //必须拍摄的时间
    NSDate *recordStartTime; //开始录制时间
    BOOL stoppingCapture; //正在停止录制
    NSTimer *timer;
    BOOL _isLongPressed;
    
    /// for fragments
    NSMutableArray *progressFragments;
    NSMutableArray *lineFragments;
    
    // new movie writer
    AKCameraCaputure *capturer;
    AKCameraExporter *exporter;
    
    BOOL movieProcessed;
    BOOL movieWillFinished;
    BOOL isFrontFacingCameraPresent;
    BOOL pausingRecording;
    BOOL finishWhenPaused;
    
    CMTime videoDuration;
    CMTime prevDuration;
    CMTime pauseTime;
    
    // akcameratool
    AKCameraTool *akTool;
    
    BOOL fromEdit;
    
    // For focus
    AKCameraFocusView *_focusView;
    
}
@property (strong, nonatomic) UIView *cameraView;
@property (strong, nonatomic) UIView *progressBkFirst;
@property (strong, nonatomic) UIView *progressBkSecond;
@property (strong, nonatomic) UIView *progressWrapper;
@property (strong, nonatomic) UIView *noteBk;
@property (strong, nonatomic) UIView *noteView1;
@property (strong, nonatomic) UIView *noteView2;
@property (strong, nonatomic) UIView *actionsWrapper;
@property (strong, nonatomic) UIView *blurView;
@property (strong, nonatomic) UIView *actionsBk;
@property (strong, nonatomic) UIButton *flashButton;
@property (strong, nonatomic) UIButton *flipCameraButton;
@property (nonatomic, strong) AKRecordProgressView *thProgressBar;
@property (nonatomic, assign) NSInteger maxSecond;
@property (nonatomic, strong) UIImageView *cursor;
@property (strong, nonatomic) UIButton *deleteBackButton;
@property (nonatomic, strong) UIView *deleteHintBar;

// Tao video action bar
@property (nonatomic, strong) UIView *taoVideoActionBar;
@property (nonatomic, strong) UIButton *taoVideoCameraButton;
@property (nonatomic, strong) UIButton *taoVideoRecordButton;
@property (nonatomic, strong) UIButton *taoVideoDeleteBackButton;

@end

@implementation AKCameraRecordView

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self config];
    }
    return self;
}

- (void)awakeFromNib{
    [self config];
}

#define _x 301
- (void)config{
    self.layer.masksToBounds = YES;
    if ([AKCameraStyle useTaoVideoActionBar]) {
        [self addSubview:self.taoVideoActionBar];
    } else {
        [self addSubview:self.actionsWrapper];
    }
    [self addSubview:self.cameraView];
    [self addSubview:self.progressWrapper];
    
    if ([AKCameraStyle cameraProgressBarOnBottom]) {
        CGRect r = self.cameraView.frame;
        r.origin.y = 0;
        self.cameraView.frame = r;
        r = self.progressWrapper.frame;
        r.origin.y = self.cameraView.bounds.size.height;
        self.progressWrapper.frame = r;
    }
    
    // focus view
    _focusView = [[AKCameraFocusView alloc] initWithFrame:CGRectZero];
    
    progressFragments = [NSMutableArray array];
    lineFragments = [NSMutableArray array];
    
    [self initCapturer];
    [self initExporter];
    
    // Set tool
    akTool = [AKCameraTool shareInstance];
    if (!akTool.video) {
        akTool.video = [[AKVideo alloc] init]; //setup video
    }
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
}

#pragma mark - Methods
- (void)_resetCapture
{
    if ([capturer isCameraDeviceAvailable:AKCameraDeviceBack]) {
        [capturer setCameraDevice:AKCameraDeviceBack];
    } else {
        [capturer setCameraDevice:AKCameraDeviceFront];
    }
    
    [capturer setCameraMode:AKCameraModeVideo];
    [capturer setCameraOrientation:AKCameraOrientationPortrait];
    [capturer setFocusMode:AKFocusModeContinuousAutoFocus];
}

- (void)initCapturer{
    capturer = [AKCameraCaputure sharedInstance];
    capturer.delegate = self;
    [self _resetCapture];
}
- (void)initExporter{
    [AKCameraExporter deallocInstance];
    //new movie capture
    exporter = [AKCameraExporter shareInstance];
    [exporter setOutputFormat:AKOutputFormatSquare];
    [capturer setVideoRenderingEnabled:YES];
    [exporter setMaxSeconds:self.maxSecond];
    [exporter setMaxFrames:defaultFrameRate * self.maxSecond];
    exporter.delegate = self;
    
    [[AKCameraCaputure sharedInstance] setExporter:exporter];
}

- (void)showCapture:(BOOL)granted{
    if (fromEdit) {
        // resetup exporter
        [exporter resetupAssetWriter];
    }
    
    [self setUserInteractionEnabled:granted];
    movieProcessed = NO;
    movieWillFinished = NO;
    stoppingCapture = NO;
    
    // reset
    [self showCursor]; //may reset
    [exporter restore];
    exporter.delegate = self;
    [self _resetCapture];
    _flipCameraButton.selected = NO;
    _flashButton.selected = NO;
    
    if (granted) {
        AVCaptureVideoPreviewLayer* preview = [capturer previewLayer];
        [preview removeFromSuperlayer];
        CGRect previewBounds = self.cameraView.layer.bounds;
        preview.bounds = previewBounds;
        preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
        preview.position = CGPointMake(CGRectGetMidX(previewBounds), CGRectGetMidY(previewBounds));
        //    preview.frame = CGRectMake(0, 0, self.cameraView.bounds.size.width, self.cameraView.bounds.size.height);
        [self.cameraView.layer addSublayer:preview];
        [capturer startPreview];
    }
}

- (void)loadFromCache {
    // restore maxseconds
    _maxSecond = [akTool.video.maxSeconds intValue];
    CGFloat p = ((_needSeconds / self.maxSecond) / (1 + (_maxSecond == 60 ? 0 : extraProgress))) * 320;
    CGRect r = _progressWrapper.frame;
    r.size.width = p;
    _progressBkFirst.frame = r;
    r = _progressWrapper.frame;
    r.origin.x = p + 2;
    r.size.width -= r.origin.x;
    _progressBkSecond.frame = r;
    
    // setup progress
    NSArray *movies = akTool.video.movieFilePaths;
    NSMutableArray *files = [NSMutableArray array];
    NSMutableArray *progresses = [NSMutableArray array];
    AVURLAsset *sourceAsset = Nil;
    CMTime duration = kCMTimeZero;
    AVAssetTrack *vt;
    for (NSURL *url in movies) {
        sourceAsset = [AVURLAsset URLAssetWithURL:url options:nil];
        if ([[sourceAsset tracksWithMediaType:AVMediaTypeVideo] count] > 0) {
            vt = [[sourceAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
            duration = vt.timeRange.duration;
            if (CMTIME_IS_VALID(duration) && CMTimeCompare(kCMTimeZero, duration) == -1) {
                [files addObject:url];
                [progresses addObject:[NSValue valueWithCMTime:duration]];
            }
        }
        
    }
    
    [exporter restoreFromMoviesWithProgress:progresses];
    
    // local
    float total = 0, current = 0;
    for (NSValue *progress in progresses) {
        current = CMTimeGetSeconds(progress.CMTimeValue) / _maxSecond;
        [progressFragments addObject:@(current)];
        total += current;
        // add line
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(self.thProgressBar.bounds.size.width * total, 0, 1, self.thProgressBar.bounds.size.height)];
        line.backgroundColor = [UIColor blackColor];
        [_progressWrapper addSubview:line];
        [lineFragments addObject:line];
    }
    
}

-(void)toggleFlash:(UIButton *)button{
    [button setSelected:!button.selected];
    [capturer setFlashMode:(button.selected ? AKFlashModeOn : AKFlashModeOff)];
}

-(void) switchCamera:(UIButton *)button {
    isFrontFacingCameraPresent = !isFrontFacingCameraPresent;
    [button setSelected:!button.selected];
    [button setEnabled:NO];

    /* 不使用 GPUImage */
    if (capturer.cameraDevice == AKCameraDeviceBack) {
        [capturer setCameraDevice:AKCameraDeviceFront];
        [capturer setFlashMode:AKFlashModeOff]; // no flash
        [_flashButton setEnabled:NO];
    } else {
        [capturer setCameraDevice:AKCameraDeviceBack]; // will not chang instancly
        [_flashButton setEnabled:YES];
    }
    [button setEnabled:YES];
    
}

- (void)deleteBack:(UIButton *)button {
    if (![exporter canDeleteLastFragment]) {
        return;
    }
    int count = [progressFragments count];
    float progress = count > 1 ? [[progressFragments objectAtIndex:count - 2] floatValue] : 0;
    if (!button.selected) {
        button.selected = YES;
        // add hint
        CGRect r = self.deleteHintBar.frame;
        r.origin.x = self.thProgressBar.bounds.size.width * progress;
        r.size.width = self.thProgressBar.progress * self.thProgressBar.bounds.size.width - r.origin.x;
        self.deleteHintBar.frame = r;
        self.deleteHintBar.hidden = NO;
    } else {
        [exporter deleteLastFragment:[lineFragments count]];
        button.selected = NO;
    }
}

#pragma mark - Capture

- (void)doRecord{
    if (!exporter.isRecording){
        [self startRecord];
        [self moveRight:0.2f andWait:YES andLength:_x];
     } else if(exporter.isPaused){
         [self resumeRecord]; //continue
         [self moveRight:0.2f andWait:YES andLength:_x];
     }
}

- (void)startRecord{
    recordStartTime = [NSDate date];
    
    pauseTime = kCMTimeInvalid;
    prevDuration = kCMTimeZero;
    videoDuration = kCMTimeZero; //reset
    
    [capturer startVideoCapture];
}

- (void)pauseRecord
{
    [self setUserInteractionEnabled:NO];
    [capturer pauseVideoCapture];
}

- (void)resumeRecord
{
    [capturer resumeVideoCapture];
}

- (void)stopRecord
{
    // stop timer
    [timer invalidate];
    timer = Nil;
    
    if (stoppingCapture || movieWillFinished) {
        return;
    }
    stoppingCapture = YES;
    [self setUserInteractionEnabled:NO];
    [_delegate akRecordViewStartStopping:self];
    [self performSelectorInBackground:@selector(realStop) withObject:Nil];
}

- (void)realStop{
    if ( exporter.isPaused) {
        [capturer stopPreview];
        [capturer endVideoCapture];
    } else {
        finishWhenPaused = YES;
        [capturer pauseVideoCapture];
    }
}

- (void)processMovie{
    if (movieProcessed) {
        return; //防止重复处理
    }
    movieProcessed = YES;
    
    //保存视频信息
    //DLog(@"process movie");
    akTool.video.createTime = [NSDate date];
    [akTool syncDataToCache];
    
    stoppingCapture = NO;
    [self moveLeft:0.2f andWait:YES andLength:_x];
    
    // check delete enabled.
    if (NO) {
        [_thProgressBar setProgress:0.0f];
        [self showCursor]; //reposition
        
        exporter = Nil; //reset
        [lineFragments enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
            UIView *line = (UIView *)obj;
            [line removeFromSuperview];
        }];
        [lineFragments removeAllObjects];
        [progressFragments removeAllObjects];
    }
}

- (void)finishCapture{
    [self stopRecord];
}

- (void)cancelCapture{
    [timer invalidate];
    timer = Nil;
    
    [capturer stopPreview];
    [capturer cancelVideoCapture];
}

- (void)updateProgress{
    Float64 duration = [exporter getDuration];
    /*
    if (CMTIME_IS_INVALID(segementStart)) {
        return;
    }
    pauseTime = CMClockGetTime(CMClockGetHostTimeClock());
    videoDuration = CMTimeAdd(prevDuration, CMTimeSubtract(pauseTime, segementStart));
    */
    float progress = duration / _maxSecond;
    ////DLog(@"progress: %f, segementstart: %f, duration: %f", progress, CMTimeGetSeconds(segementStart), CMTimeGetSeconds(videoDuration));
    if (progress >= 1 + (_maxSecond == 60 ? 0 : extraProgress)) {
        [self stopRecord];
        progress = 1 + (_maxSecond == 60 ? 0 : extraProgress);
    }
    
    if (progress >= _needSeconds /  self.maxSecond) {
        [_delegate akRecordViewRequiredDone:self];
    }
    [_thProgressBar setProgress:progress / (1 + (_maxSecond == 60 ? 0 : extraProgress))];
    
    //[_timeHint setText:[NSString stringWithFormat:@"还可以拍摄%i秒", (int)(self.maxSecond * (1- progress))]];
}

- (void)cancelDeleteBack{
    _deleteHintBar.hidden = YES;
    _deleteBackButton.selected = NO;
}

- (void)focusAtPoint:(UITouch *)touch {
    if (touch) {
        CGPoint tapPoint = [touch locationInView:_cameraView];
        
        // auto focus is occuring, display focus view
        CGPoint point = tapPoint;
        
        CGRect focusFrame = _focusView.frame;
#if defined(__LP64__) && __LP64__
        focusFrame.origin.x = rint(point.x - (focusFrame.size.width * 0.5));
        focusFrame.origin.y = rint(point.y - (focusFrame.size.height * 0.5));
#else
        focusFrame.origin.x = rintf(point.x - (focusFrame.size.width * 0.5f));
        focusFrame.origin.y = rintf(point.y - (focusFrame.size.height * 0.5f));
#endif
        [_focusView setFrame:focusFrame];
        
        [_cameraView addSubview:_focusView];
        [_focusView startAnimation];
        
        CGPoint adjustPoint = [AKCameraUtils convertToPointOfInterestFromViewCoordinates:tapPoint inFrame:_cameraView.frame];
        [[AKCameraCaputure sharedInstance] focusAtAdjustedPoint:adjustPoint];
        
        // 如果5秒之后还没有对焦完成，直接隐藏
        [self performSelector:@selector(hideFocusAfter) withObject:nil afterDelay:6];
    }
}

- (void)hideFocusAfter {
    [_focusView stopAnimation];
}

#pragma mark - touch events
-(void)singleTap:(UITouch *)touch{
    if (_deleteBackButton.selected) {
        [self cancelDeleteBack];
        return;
    }
    if (stoppingCapture || pausingRecording) {
        return;
    }
    
    if (exporter.isRecording && !exporter.isPaused) {
        [self pauseRecord];
        [self moveLeft:0.2f andWait:YES andLength:_x];
    } else {
        // focus
        [self focusAtPoint:touch];
    }
}
-(void)doubleTap{
    if (_deleteBackButton.selected) {
        [self cancelDeleteBack];
    }
    if (stoppingCapture) {
        return;
    }
    if (pausingRecording) {
        [self performSelector:@selector(doubleTap) withObject:nil afterDelay:0.1];
        return;
    }
    if ([exporter isRecording] && ![exporter isPaused]) {
        return; //已经在拍摄
    }
    [self doRecord];
    
}
-(void) longTap
{
    if (_deleteBackButton.selected) {
        [self cancelDeleteBack];
    }
    
    if (stoppingCapture) {
        return;
    }
    
    if (pausingRecording) {
        [self performSelector:@selector(longTap) withObject:nil afterDelay:0.1];
        return;
    }
    
    [self doRecord];
    _isLongPressed = YES;
    ////DLog(@"handle long tap..");
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if ([AKCameraStyle useTaoVideoActionBar]) {
        return;
    }
    
    UITouch *touch = [touches anyObject];
    if ([[touch view] isEqual:_blurView] || [[touch view] isEqual:_cameraView]) {
        [self performSelector:@selector(longTap) withObject:nil afterDelay:0.4];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    
    if ([[touch view] isEqual:_blurView] || [[touch view] isEqual:_cameraView]) {
        ////DLog(@"touch ended");
        if ([AKCameraStyle useTaoVideoActionBar]) {
            [self focusAtPoint:touch]; // Always focus action
            return;
        }
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(longTap) object:nil];
        if (_isLongPressed) {
            [self singleTap:Nil];
            _isLongPressed = NO;
        }
        
        //DLog(@"touch end");
        
        NSTimeInterval delaytime = 0.3;//自己根据需要调整
        switch (touch.tapCount) {
            case 1:
                if ([[touch view] isEqual:_cameraView]) {
                    [self performSelector:@selector(singleTap:) withObject:touch afterDelay:delaytime];
                } else {
                    [self performSelector:@selector(singleTap:) withObject:Nil afterDelay:delaytime];
                }
                break;
            case 2:{
                [NSObject cancelPreviousPerformRequestsWithTarget:self];
                //[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(singleTap:) object:nil];
                [self performSelector:@selector(doubleTap) withObject:nil afterDelay:delaytime];
                
            }
                break;
            default:
                break;
        }
    }
}

#pragma mark - TaoVideo Record
- (void)taoRecordDown:(id)sender {
    if ([exporter isRecording] && ![exporter isPaused]) {
        return; //已经在拍摄
    }
    [self doRecord];
}

- (void)taoRecordCancel:(id)sender {
    if (exporter.isRecording && !exporter.isPaused) {
        [self pauseRecord];
    }
}

- (void)taoRecordUp:(id)sender {
    if (exporter.isRecording && !exporter.isPaused) {
        [self pauseRecord];
    }
}

#pragma mark - Cursor
- (void)showCursor{
    self.cursor.hidden = NO;
    CGFloat x = 320 * self.thProgressBar.progress;
    CGRect r = CGRectMake(x, 0, 3, 10);
    self.cursor.frame = r;
    [self.cursor startAnimating];
}

- (void)hideCursor{
    self.cursor.hidden = YES;
    [self.cursor stopAnimating];
    //[self.cursor removeFromSuperview];
}

#pragma mark - animation

- (void) moveLeft: (float) duration andWait:(BOOL) wait andLength:(float) length{
    __block BOOL done = wait; //wait =  YES wait to finish animation
    [UIView animateWithDuration:duration animations:^{
        _noteView2.center = CGPointMake(_noteView2.center.x - length, _noteView2.center.y);
        //
        _noteView1.center = CGPointMake(_noteView1.center.x - length, _noteView1.center.y);
        
    } completion:^(BOOL finished) {
        done = NO;
    }];
    // wait for animation to finish
    //    while (done == YES)
    //        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

- (void) moveRight: (float) duration andWait:(BOOL) wait andLength:(float) length{
    __block BOOL done = wait; //wait =  YES wait to finish animation
    [UIView animateWithDuration:duration animations:^{
        //left
        _noteView2.center = CGPointMake(_noteView2.center.x + length, _noteView2.center.y);
        //right
        _noteView1.center = CGPointMake(_noteView1.center.x + length, _noteView1.center.y);
    } completion:^(BOOL finished) {
        done = NO;
    }];
    // wait for animation to finish
    while (done == YES)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

#pragma mark - AKCameraCaptureDelegate

- (void)akCameraModeDidChange:(AKCameraCaputure *)akCamera{
    // check flash
    if (akCamera.cameraDevice == AKCameraDeviceBack) {
        [akCamera setFlashMode:(_flashButton.selected ? AKFlashModeOn : AKFlashModeOff)];
    }
}

- (void)akCameraDidStopFocus:(AKCameraCaputure *)akCamera {
    if (_focusView && [_focusView superview]) {
        [_focusView stopAnimation];
    }
}

#pragma mark - AKCameraExporterDelegate
- (void)akExporterDidCaptureAudioSample:(AKCameraExporter *)akExporter{
    // update progress
    Float64 passed = [akExporter capturedAudioSeconds];
    if (isnan(passed)) {
        return;
    }
    float progress = _maxSecond >= 60 ? passed : [akExporter getDuration] / _maxSecond;
    if (progress > _thProgressBar.progress) {
        [self updateProgress];
    }
}

- (void)akExporterDidCaptureVideoSample:(AKCameraExporter *)akExporter{
    Float64 passed = [akExporter capturedAudioSeconds];
    if (isnan(passed)) {
        return;
    }
    float progress = _maxSecond >= 60 ? passed : [akExporter getDuration] / _maxSecond;
    if (progress > _thProgressBar.progress) {
        [self updateProgress];
    }
}

- (void)akExporterDidStartVideoCapture:(AKCameraExporter *)akExporter error:(NSError *)error{
    if (error) {
        [_delegate akRecordViewStartFailed:self error:error];
        [self setUserInteractionEnabled:NO];
        return;
    }
    [self hideCursor];
    
    // 保存数据
    akTool.video.maxSeconds = @(_maxSecond);
    [akTool syncDataToCache];
    // start timer
    //timer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(updateProgress) userInfo:Nil repeats:YES];
    //[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)akExporterDidPauseVideoCapture:(AKCameraExporter *)akExporter duration:(Float64)duration{
    //DLog(@"pause did add progress: %f", duration);
    
    // stop timer
    //[timer invalidate];
    //timer = Nil;
    
    /*
    float progress = duration / _maxSecond;
    _thProgressBar.progress = progress;
    */
    [self showCursor];
    // add pause line
    float progress = _thProgressBar.progress;
    [progressFragments addObject:@(progress)];
    prevDuration = videoDuration; // update prev
    // add line
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(self.thProgressBar.bounds.size.width * progress, 0, 1, self.thProgressBar.bounds.size.height)];
    line.backgroundColor = [UIColor blackColor];
    [self.progressWrapper addSubview:line];
    [lineFragments addObject:line];
    
    if (finishWhenPaused) {
        finishWhenPaused = NO;
        [capturer stopPreview];
        [capturer endVideoCapture];
    }
    
    [self setUserInteractionEnabled:YES];
}

- (void)akExporterDidPauseVideoCaptureFailed:(AKCameraExporter *)akExporter {
    // 暂停失败，重置进度
    [AKCameraMessageHUD dismiss];
    self.thProgressBar.progress = [[progressFragments lastObject] floatValue];
}

- (CMTime)akExporterGetPauseTime{
    return pauseTime;
}

- (void)akExporterDidResumeVideoCapture:(AKCameraExporter *)akExporter{
    [self hideCursor];
    
    // start timer
    //timer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(updateProgress) userInfo:Nil repeats:YES];
    //[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)akExporterDidEndVideoCapture:(AKCameraExporter *)akExporter error:(NSError *)error{
    // 结束
    if (error) {
        //DLog(@"%@", error);
        [_delegate akRecordViewEndFailed:self error:error];
        return;
    }
    
    [self processMovie];
    
    // Setup path
    akTool.video.videoFilePath = [exporter mergeMovieFiles];
    [akTool syncDataToCache];
    
    if (_maxSecond >= 60) {
        _thProgressBar.progress = 0;
        [progressFragments removeAllObjects];
        for (UIView *line in lineFragments) {
            [line removeFromSuperview];
        }
        [lineFragments removeAllObjects];
        prevDuration = kCMTimeZero;
        videoDuration = kCMTimeZero;
    }
    fromEdit = YES;
    
    [_delegate akRecordView:self didFinishWith:akTool.video keyFrames:[exporter keyFrames]];
}

- (void)akExporterDidDeleteLastSegement:(AKCameraExporter *)akExporter{
    NSUInteger count = [progressFragments count];
    _thProgressBar.progress = count > 1 ? [[progressFragments objectAtIndex:count - 2] floatValue] : 0;
    
    if (_delegate && _thProgressBar.progress < _needSeconds /  self.maxSecond) {
        [_delegate akRecordViewProgressTooSmall];
    }
    [progressFragments removeLastObject];
    [[lineFragments lastObject] removeFromSuperview];
    [lineFragments removeLastObject];
    [self showCursor]; //fixed
    _deleteBackButton.selected = NO;
    _deleteHintBar.hidden = YES;
}

#pragma mark - Getters
- (UIView *)cameraView {
    if (!_cameraView) {
        _cameraView = [[UIView alloc] initWithFrame:CGRectMake(0, 10, 320, 320)];
        _cameraView.backgroundColor = [UIColor blackColor];
    }
    return _cameraView;
}

- (UIView *)noteView1 {
    if (!_noteView1) {
        _noteView1 = [[UIView alloc] initWithFrame:CGRectMake(50, 20, 220, 30)];
        _noteView1.backgroundColor = [UIColor clearColor];
        UILabel *l1 = [[UILabel alloc] initWithFrame:CGRectMake(3, 2, 44, 27)];
        l1.backgroundColor = [UIColor clearColor];
        l1.textColor = [UIColor whiteColor];
        l1.font = [UIFont systemFontOfSize:22];
        l1.shadowOffset = CGSizeMake(0, 1);
        l1.shadowColor = [UIColor darkGrayColor];
        l1.text = @"按住";
        [_noteView1 addSubview:l1];
        UILabel *l2 = [[UILabel alloc] initWithFrame:CGRectMake(48, 8, 16, 21)];
        l2.backgroundColor = [UIColor clearColor];
        l2.textColor = [UIColor whiteColor];
        l2.font = [UIFont systemFontOfSize:16];
        l2.shadowOffset = CGSizeMake(0, 1);
        l2.shadowColor = [UIColor darkGrayColor];
        l2.text = @"或";
        [_noteView1 addSubview:l2];
        UILabel *l3 = [[UILabel alloc] initWithFrame:CGRectMake(65, 2, 44, 27)];
        l3.backgroundColor = [UIColor clearColor];
        l3.textColor = [UIColor whiteColor];
        l3.font = [UIFont systemFontOfSize:22];
        l3.shadowOffset = CGSizeMake(0, 1);
        l3.shadowColor = [UIColor darkGrayColor];
        l3.text = @"双击";
        [_noteView1 addSubview:l3];
        UILabel *l4 = [[UILabel alloc] initWithFrame:CGRectMake(110, 7, 96, 27)];
        l4.backgroundColor = [UIColor clearColor];
        l4.textColor = [UIColor whiteColor];
        l4.font = [UIFont systemFontOfSize:16];
        l4.shadowOffset = CGSizeMake(0, 1);
        l4.shadowColor = [UIColor darkGrayColor];
        l4.text = @"任何地方拍摄";
        [_noteView1 addSubview:l4];
        _noteView1.center = CGPointMake(160.0f, _noteView1.center.y);
    }
    return _noteView1;
}

- (UIView *)noteView2 {
    if (!_noteView2) {
        _noteView2 = [[UIView alloc] initWithFrame:CGRectMake(77, 20, 185, 30)];
        _noteView2.backgroundColor = [UIColor clearColor];
        UILabel *l1 = [[UILabel alloc] initWithFrame:CGRectMake(3, 2, 44, 27)];
        l1.backgroundColor = [UIColor clearColor];
        l1.textColor = [UIColor whiteColor];
        l1.font = [UIFont systemFontOfSize:22];
        l1.shadowOffset = CGSizeMake(0, 1);
        l1.shadowColor = [UIColor darkGrayColor];
        l1.text = @"松开";
        [_noteView2 addSubview:l1];
        UILabel *l2 = [[UILabel alloc] initWithFrame:CGRectMake(48, 8, 18, 22)];
        l2.backgroundColor = [UIColor clearColor];
        l2.textColor = [UIColor whiteColor];
        l2.font = [UIFont systemFontOfSize:16];
        l2.shadowOffset = CGSizeMake(0, 1);
        l2.shadowColor = [UIColor darkGrayColor];
        l2.text = @"或";
        [_noteView2 addSubview:l2];
        UILabel *l3 = [[UILabel alloc] initWithFrame:CGRectMake(65, 2, 44, 27)];
        l3.backgroundColor = [UIColor clearColor];
        l3.textColor = [UIColor whiteColor];
        l3.font = [UIFont systemFontOfSize:22];
        l3.shadowOffset = CGSizeMake(0, 1);
        l3.shadowColor = [UIColor darkGrayColor];
        l3.text = @"单击";
        [_noteView2 addSubview:l3];
        UILabel *l4 = [[UILabel alloc] initWithFrame:CGRectMake(110, 7, 72, 23)];
        l4.backgroundColor = [UIColor clearColor];
        l4.textColor = [UIColor whiteColor];
        l4.font = [UIFont systemFontOfSize:16];
        l4.shadowOffset = CGSizeMake(0, 1);
        l4.shadowColor = [UIColor darkGrayColor];
        l4.text = @"暂停拍摄";
        [_noteView2 addSubview:l4];
        _noteView2.center = CGPointMake(160.0f - _x, _noteView2.center.y);
    }
    return _noteView2;
}

- (UIView *)progressWrapper {
    if (!_progressWrapper) {
        _progressWrapper = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 10)];
        _progressWrapper.backgroundColor = [UIColor clearColor];
        // add white line
        _needSeconds = 2.0;
        CGFloat p = ((_needSeconds / self.maxSecond) / (1 + (_maxSecond == 60 ? 0 : extraProgress))) * 320;
        CGRect r = _progressWrapper.frame;
        r.size.width = p;
        _progressBkFirst = [[UIView alloc] initWithFrame:r];
        _progressBkFirst.backgroundColor = [UIColor colorWithRed:51/255.0f green:51/255.0f blue:51/255.0f alpha:1];
        [_progressWrapper addSubview:_progressBkFirst];
        
        r = _progressWrapper.frame;
        r.origin.x = p + 2;
        r.size.width -= r.origin.x;
        _progressBkSecond = [[UIView alloc] initWithFrame:r];
        _progressBkSecond.backgroundColor = _progressBkFirst.backgroundColor;
        [_progressWrapper addSubview:_progressBkSecond];
        
        UIView *middleLine = [[UIView alloc] initWithFrame:CGRectMake(p, 0, 2, 10)];
        middleLine.backgroundColor = [AKCameraStyle cameraLineColor];
        middleLine.alpha = .5f;
        [self.progressWrapper addSubview:middleLine];
        
        [_progressWrapper addSubview:self.thProgressBar];
        [_progressWrapper addSubview:self.cursor];
    }
    return _progressWrapper;
}

- (UIView *)actionsWrapper {
    if (!_actionsWrapper) {
        _actionsWrapper = [[UIView alloc] initWithFrame:CGRectMake(0, 330, 330, self.bounds.size.height - 330)];
        _blurView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, _actionsWrapper.bounds.size.height - 75)];
        _blurView.backgroundColor = [UIColor blackColor];
        [_actionsWrapper addSubview:_blurView];
        _actionsBk = [[UIView alloc] initWithFrame:CGRectMake(0, _actionsWrapper.bounds.size.height - 75, 320, 75)];
        _actionsBk.backgroundColor = [UIColor whiteColor];
        [_actionsBk addSubview:self.flashButton];
        UILabel *l1 = [[UILabel alloc] initWithFrame:CGRectMake(33, 44, 42, 21)];
        l1.backgroundColor = [UIColor clearColor];
        l1.font = [UIFont systemFontOfSize:12];
        l1.textColor = [UIColor darkGrayColor];
        l1.text = @"闪光灯";
        l1.textAlignment = NSTextAlignmentCenter;
        [_actionsBk addSubview:l1];
        [_actionsBk addSubview:self.flipCameraButton];
        UILabel *l2 = [[UILabel alloc] initWithFrame:CGRectMake(139, 44, 42, 21)];
        l2.backgroundColor = [UIColor clearColor];
        l2.font = [UIFont systemFontOfSize:12];
        l2.textColor = [UIColor darkGrayColor];
        l2.text = @"镜头";
        l2.textAlignment = NSTextAlignmentCenter;
        [_actionsBk addSubview:l2];
        [_actionsBk addSubview:self.deleteBackButton];
        UILabel *l3 = [[UILabel alloc] initWithFrame:CGRectMake(252, 44, 42, 21)];
        l3.backgroundColor = [UIColor clearColor];
        l3.font = [UIFont systemFontOfSize:12];
        l3.textColor = [UIColor darkGrayColor];
        l3.text = @"镜头";
        l3.textAlignment = NSTextAlignmentCenter;
        [_actionsBk addSubview:l3];
        [_actionsWrapper addSubview:_actionsBk];
    }
    return _actionsWrapper;
}

- (UIButton *)flashButton {
    if (!_flashButton) {
        _flashButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _flashButton.frame = CGRectMake(27, 4, 55, 84);
        [_flashButton setImage:[UIImage imageNamed:@"AKCamera.bundle/flashlight.png"] forState:UIControlStateNormal];
        [_flashButton setImage:[UIImage imageNamed:@"AKCamera.bundle/flashlight_on_h.png"] forState:UIControlStateHighlighted];
        [_flashButton setImage:[UIImage imageNamed:@"AKCamera.bundle/flashlight_on_h.png"] forState:UIControlStateSelected];
        [_flashButton addTarget:self action:@selector(toggleFlash:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _flashButton;
}

- (UIButton *)flipCameraButton {
    if (!_flipCameraButton) {
        _flipCameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _flipCameraButton.frame = CGRectMake(133, 4, 55, 84);
        [_flipCameraButton setImage:[UIImage imageNamed:@"AKCamera.bundle/camera.png"] forState:UIControlStateNormal];
        [_flipCameraButton setImage:[UIImage imageNamed:@"AKCamera.bundle/camera_on_h.png"] forState:UIControlStateHighlighted];
        [_flipCameraButton setImage:[UIImage imageNamed:@"AKCamera.bundle/camera_on_h.png"] forState:UIControlStateSelected];
        [_flipCameraButton addTarget:self action:@selector(switchCamera:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _flipCameraButton;
}

- (UIButton *)deleteBackButton {
    if (!_deleteBackButton) {
        _deleteBackButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _deleteBackButton.frame = CGRectMake(240, 4, 55, 84);
        [_deleteBackButton setImage:[UIImage imageNamed:@"AKCamera.bundle/delete_back.png"] forState:UIControlStateNormal];
        [_deleteBackButton setImage:[UIImage imageNamed:@"AKCamera.bundle/delete_back_h.png"] forState:UIControlStateHighlighted];
        [_deleteBackButton setImage:[UIImage imageNamed:@"AKCamera.bundle/delete_back_h.png"] forState:UIControlStateSelected];
        [_deleteBackButton addTarget:self action:@selector(deleteBack:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _deleteBackButton;
}

- (AKRecordProgressView *)thProgressBar{
    if (!_thProgressBar) {
        CGRect rect = CGRectMake(0, 0, 320, 10);
        _thProgressBar = [[AKRecordProgressView alloc] initWithFrame:rect];
        _thProgressBar.radius = 0;
        _thProgressBar.border = 0;
        _thProgressBar.borderTintColor = [UIColor clearColor];
        _thProgressBar.progressTintColor = [AKCameraStyle cameraProgressColor];
    }
    return _thProgressBar;
}

- (NSInteger)maxSecond{
    if (_maxSecond == 0) {
        //最长拍摄时长
        NSString *spanString = [[NSUserDefaults standardUserDefaults] stringForKey:@"recordSpan"];
        if ([spanString intValue] == 0) {
            //6s
            _maxSecond = 6;
        } else if ([spanString intValue] == 1) {
            _maxSecond = 9;
        } else if ([spanString intValue] == 2) {
            _maxSecond = 15;
        } else {
            _maxSecond = 60;
        }
    }
    if (_maxSecond >= 60) {
        self.deleteBackButton.enabled = NO;
    }
    return _maxSecond;
}

- (UIImageView *)cursor{
    if (!_cursor) {
        _cursor = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 3, 10)];
        _cursor.animationImages = @[[UIImage imageWithColor:[UIColor clearColor] size:_cursor.bounds.size], [UIImage imageWithColor:[AKCameraStyle cameraCursorColor] size:_cursor.bounds.size]];
        _cursor.animationDuration = 1.0f;
        _cursor.animationRepeatCount = 0;
        [_cursor startAnimating];
    }
    return _cursor;
}

- (UIView *)deleteHintBar{
    if (!_deleteHintBar) {
        _deleteHintBar = [[UIView alloc] initWithFrame:self.thProgressBar.frame];
        _deleteHintBar.backgroundColor = [AKCameraStyle cameraLineColor];
        [self.progressWrapper addSubview:_deleteHintBar];
        _deleteHintBar.hidden = YES;
    }
    return _deleteHintBar;
}

- (CGFloat)progress{
    return _thProgressBar.progress;
}

#pragma mark - TaoVideo Action Bar
- (UIView *)taoVideoActionBar {
    if (!_taoVideoActionBar) {
        _taoVideoActionBar = [[UIView alloc] initWithFrame:CGRectMake(0, 330, 320, self.bounds.size.height - 330)];
        _taoVideoActionBar.backgroundColor = [UIColor blackColor];
        [_taoVideoActionBar addSubview:self.taoVideoCameraButton];
        UILabel *l1 = [[UILabel alloc] initWithFrame:CGRectMake(0, 60, 90, 20)];
        l1.backgroundColor = [UIColor clearColor];
        l1.font = [UIFont systemFontOfSize:14];
        l1.textColor = [UIColor whiteColor];
        l1.text = @"镜头";
        l1.textAlignment = NSTextAlignmentCenter;
        [_taoVideoActionBar addSubview:l1];
        [_taoVideoActionBar addSubview:self.taoVideoRecordButton];
        [_taoVideoActionBar addSubview:self.taoVideoDeleteBackButton];
        UILabel *l3 = [[UILabel alloc] initWithFrame:CGRectMake(320 - 90, 60, 90, 20)];
        l3.backgroundColor = [UIColor clearColor];
        l3.font = [UIFont systemFontOfSize:14];
        l3.textColor = [UIColor whiteColor];
        l3.text = @"回删";
        l3.textAlignment = NSTextAlignmentCenter;
        [_taoVideoActionBar addSubview:l3];
    }
    return _taoVideoActionBar;
}

- (UIButton *)taoVideoCameraButton {
    if (!_taoVideoCameraButton) {
        _taoVideoCameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _taoVideoCameraButton.frame = CGRectMake(0, 0, 90, 90);
        UIImage *normalImage = [UIImage imageNamed:@"AKCamera.bundle/tao_switch_camera.png"];
        [_taoVideoCameraButton setImage:normalImage forState:UIControlStateNormal];
        [_taoVideoCameraButton addTarget:self action:@selector(switchCamera:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _taoVideoCameraButton;
}

- (UIButton *)taoVideoRecordButton {
    if (!_taoVideoRecordButton) {
        _taoVideoRecordButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _taoVideoRecordButton.frame = CGRectMake((320 - 90) / 2, 0, 90, 90);
        [_taoVideoRecordButton setImage:[UIImage imageNamed:@"AKCamera.bundle/tao_record_n.png"] forState:UIControlStateNormal];
        [_taoVideoRecordButton setImage:[UIImage imageNamed:@"AKCamera.bundle/tao_record_h.png"] forState:UIControlStateHighlighted];
        UILabel *tl = [[UILabel alloc] init];
        tl.font = [UIFont boldSystemFontOfSize:20.0f];
        tl.text = @"按住拍摄";
        tl.textColor = [UIColor whiteColor];
        tl.backgroundColor = [UIColor clearColor];
        [tl sizeToFit];
        tl.numberOfLines = 2;
        tl.frame = CGRectMake(0, 0, tl.bounds.size.width / 2, tl.bounds.size.height * 2);
        [_taoVideoRecordButton addSubview:tl];
        tl.center = CGPointMake(45, 45);
        [_taoVideoRecordButton addTarget:self action:@selector(taoRecordDown:) forControlEvents:UIControlEventTouchDown];
        [_taoVideoRecordButton addTarget:self action:@selector(taoRecordCancel:) forControlEvents:UIControlEventTouchCancel];
        [_taoVideoRecordButton addTarget:self action:@selector(taoRecordUp:) forControlEvents:UIControlEventTouchUpInside];
        [_taoVideoRecordButton addTarget:self action:@selector(taoRecordUp:) forControlEvents:UIControlEventTouchUpOutside];
    }
    return _taoVideoRecordButton;
}

- (UIButton *)taoVideoDeleteBackButton {
    if (!_taoVideoDeleteBackButton) {
        _taoVideoDeleteBackButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _taoVideoDeleteBackButton.frame = CGRectMake(320 - 90, 0, 90, 90);
        UIImage *normalImage = [UIImage imageNamed:@"AKCamera.bundle/tao_delete_back.png"];
        UIImage *hightLight = [normalImage imageByFilledWithColor:[UIColor colorWithRed:240/255.0f green:75/255.0f blue:29/255.0f alpha:1]];
        [_taoVideoDeleteBackButton setImage:normalImage forState:UIControlStateNormal];
        [_taoVideoDeleteBackButton setImage:hightLight forState:UIControlStateHighlighted];
        [_taoVideoDeleteBackButton setImage:hightLight forState:UIControlStateSelected];
        [_taoVideoDeleteBackButton addTarget:self action:@selector(deleteBack:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _taoVideoDeleteBackButton;
}
@end
