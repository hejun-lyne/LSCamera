//
//  AKCameraVideoPreview.m
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraVideoPreview.h"
#import "AKCameraPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import "AKCameraExporter.h"
#import "AVPlayer+TrackVolume.h"

/* Asset keys */
NSString * const kTracksKey = @"tracks";
NSString * const kPlayableKey = @"playable";
/* PlayerItem keys */
NSString * const kStatusKey         = @"status";
NSString * const kCurrentItemKey	= @"currentItem";
static void *AVPlayerDemoPlaybackViewControllerStatusObservationContext = &AVPlayerDemoPlaybackViewControllerStatusObservationContext;

@interface AKCameraVideoPreview()<UIGestureRecognizerDelegate>
{
    NSTimer *_timer;
    AVPlayer *mPlayer;
    BOOL isPlaying;
    AKCameraPlayer *videoPlayer;
    
    BOOL playEnded;
}
@property (nonatomic, strong)UIImageView *clipImageView;
@property (nonatomic, strong)UIButton *playButton;
@end
@implementation AKCameraVideoPreview
@synthesize clipImageView = _clipImageView;
@synthesize delegate = _delegate;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.backgroundColor = [UIColor blackColor];
        videoPlayer = [[AKCameraPlayer alloc]initWithFrame:self.frame];
        [self addSubview:videoPlayer];
        UITapGestureRecognizer *playerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(playButtonTapped:)];
        playerTap.delegate = self;
        [videoPlayer addGestureRecognizer:playerTap];
        
        
        _clipImageView = [[UIImageView alloc]initWithFrame:self.bounds];
        _clipImageView.clipsToBounds = YES;
        _clipImageView.contentMode = UIViewContentModeScaleToFill;
        [self addSubview:_clipImageView];
        _playButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *playIcon = [UIImage imageNamed:@"AKCamera.bundle/tao_play_btn"];
        _playButton.frame = CGRectMake(0, 0, playIcon.size.width, playIcon.size.height);
        [_playButton setImage:playIcon forState:UIControlStateNormal];
        [self addSubview:_playButton];
        _playButton.center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
        [_playButton addTarget:self action:@selector(playButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)dealloc{
    [mPlayer pause];
    [mPlayer.currentItem removeObserver:self forKeyPath:@"status" context:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _clipImageView = nil;
    _timer = nil;
    mPlayer = nil;
    videoPlayer = nil;
}
#pragma mark avplayer
- (void)setVolume:(CGFloat)volume{
    [mPlayer setVolume:volume];
}
- (void)playerReset{
    [self toggleVideoInfo:NO];
    [self start:NO];
    isPlaying = NO;
    playEnded = YES;
    //[mPlayer seekToTime:kCMTimeZero];
    //    _progressView.alpha = 0;
    //    [_progressView setProgress:0.f];
    
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItem *playerItem = (AVPlayerItem*)object;
        if (playerItem.status==AVPlayerStatusReadyToPlay) {
            //视频加载完成
            [videoPlayer setPlayer:mPlayer];
        }
    }
}

-(void)moviePlayDidEnd:(NSNotification*)notification{
    //视频播放完成，回退到视频列表页面
    //DLog(@"播放完成");
    [self playerReset];
    if (_delegate) {
        [_delegate previewVideoViewStop:self];
    }
}

#pragma mark private methods

- (void)playButtonTapped:(UITapGestureRecognizer *)sender{
    //[self config];
    if (isPlaying) {
        [mPlayer pause];
        [self toggleVideoInfo:NO];
        [self start:NO];
        isPlaying = NO;
        if (_delegate) {
            [_delegate previewVideoViewPause:self];
        }
    }else{
        if (playEnded) {
            playEnded = NO;
            [mPlayer seekToTime:kCMTimeZero];
        }
        [mPlayer play];
        //        _progressView.alpha = 1;
        [self toggleVideoInfo:YES];
        [self start:YES];
        isPlaying = YES;
        if (_delegate) {
            [_delegate previewVideoViewPlay:self];
        }
    }
}
- (void)config:(NSURL *)url{
    if (!mPlayer) {
        __block NSURL *playUrl = url;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(){
            if (playUrl) {
                mPlayer = [AVPlayer playerWithURL:playUrl];
            } else {
                AVComposition *composition = [[AKCameraExporter shareInstance] getComposition];
                AVPlayerItem *playerItem;
                if (composition) {
                    playerItem = [AVPlayerItem playerItemWithAsset:composition];
                } else {
                    NSURL *url = [[AKCameraExporter shareInstance] checkExportOutputURL];
                    if (!url) {
                        return;
                    }
                    playerItem = [AVPlayerItem playerItemWithURL:url];
                }
                
                mPlayer = [AVPlayer playerWithPlayerItem:playerItem];
            }
            [videoPlayer setPlayer:mPlayer];
            //检测视频加载状态，加载完成隐藏风火轮
            [mPlayer.currentItem addObserver:self forKeyPath:@"status"
                                     options:NSKeyValueObservingOptionNew
                                     context:nil];
            
            //添加视频播放完成的notifation
            [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(moviePlayDidEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:mPlayer.currentItem];
        });
        
    }
}
- (BOOL)isPlaying{
    return isPlaying;
}
- (void)play{
    [self playButtonTapped:nil];
}
- (void)stop{
    if (mPlayer) {
        if (isPlaying) {
            [mPlayer pause];
        }
        [self playerReset];
    }
}
- (void)pause{
    if (isPlaying) {
        [mPlayer pause];
        [self toggleVideoInfo:NO];
        [self start:NO];
        isPlaying = NO;
    }
}
- (void)setClipImage:(UIImage *)image{
    _clipImageView.image = image;
    if (image.size.width != image.size.height) {
        self.contentMode = UIViewContentModeScaleAspectFill;
    } else {
        self.contentMode = UIViewContentModeScaleToFill;
    }
}
- (void)toggleVideoInfo:(BOOL)hidden{
    if (hidden) {
        [UIView animateWithDuration:.2
                              delay:0
                            options: UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             _playButton.alpha = 0;
                             _clipImageView.alpha = 0;
                             _clipImageView.userInteractionEnabled = NO;
                         }
                         completion:^(BOOL finished){
                         }];
    }else if(!hidden){
        [UIView animateWithDuration:.2
                              delay:0
                            options: UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             _playButton.alpha = 1;
                             //_clipImageView.alpha = 1;
                             //_clipImageView.userInteractionEnabled = YES;
                         }
                         completion:^(BOOL finished){
                             
                         }];
    }
}


#pragma mark timer

- (void)updateProgress{
    //    NSTimeInterval elaspedTime = [_playView currentPlaybackTime];
    CGFloat elaspedTime = (CGFloat)mPlayer.currentItem.currentTime.value / mPlayer.currentItem.currentTime.timescale;
    if(isnan(elaspedTime) ){
        return;
    }
    
    //CGFloat total = _duration ;
    //CGFloat p = (CGFloat)(elaspedTime / total);
    
    //    [_progressView setProgress: p];
}

- (void)start:(BOOL) isStart{
    return;
    if (isStart) {
        _timer = nil;
        _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
    }else{
        [_timer invalidate];
    }
}

@end