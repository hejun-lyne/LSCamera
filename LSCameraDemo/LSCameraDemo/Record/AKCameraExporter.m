//
//  AKVideoExporter.m
//  aikan
//
//  Created by lihejun on 14-2-24.
//  Copyright (c) 2014年 taobao. All rights reserved.
//

#import "AKCameraExporter.h"
#import "AKCameraUtils.h"
#import "AKCameraTool.h"
#import <OpenGLES/EAGL.h>
#import "AKCameraDefines.h"

enum
{
    AKCameraUniformY,
    AKCameraUniformUV,
    AKCameraUniformCount
};
GLint _uniforms[AKCameraUniformCount];

enum
{
    AKCameraAttributeVertex,
    AKCameraAttributeTextureCoord,
    AKCameraAttributeCount
};

static AKCameraExporter *instance;

@interface AKCameraExporter()
{
    CGSize videoSize;
    
    // timestamps
    int32_t _currentFrame;

    // flags
    struct {
        unsigned int recording:1;
        unsigned int paused:1;
        unsigned int interrupted:1;
        unsigned int videoWritten:1;
        unsigned int videoRenderingEnabled:1;
        unsigned int isAudioReady:1;
        unsigned int isVideoReady:1;
    } __block _flags;
    
    // core
    AKOutputFormat _outputFormat;
    
    NSInteger _audioAssetBitRate;
    CGFloat _videoAssetBitRate;
    NSInteger _videoAssetFrameInterval;
    
    CMTime _timeOffset;
    CMTime _startTimestamp;
    CMTime _audioTimestamp;
    CMTime _videoTimestamp;
    
    // texture
    EAGLContext *_context;
    GLuint _program;
    CVOpenGLESTextureRef _lumaTexture;
    CVOpenGLESTextureRef _chromaTexture;
    CVOpenGLESTextureCacheRef _videoTextureCache;
    
    // sample buffer rendering
    AKCameraDevice _bufferDevice;
    AKCameraOrientation _bufferOrientation;
    size_t _bufferWidth;
    size_t _bufferHeight;
    CGRect _presentationFrame;
    
    // key frames
    NSMutableArray *_currentKeyFrames;
    
    AVAssetWriter *assetWriter;
	AVAssetWriterInput *assetWriterAudioIn;
	AVAssetWriterInput *assetWriterVideoIn;
    AVAssetWriterInputPixelBufferAdaptor *assetWriterPixelBufferInput;
    
    NSMutableArray *usedFiles;
    
    // composition
    AVMutableComposition *mutableComposition;
    AVAssetExportSession *exporter;
    CMTime videoDuration;
    CMTime currentDuration;
    NSMutableArray *durationArray;
    
    AKCameraTool *akTool;
}
@end
@implementation AKCameraExporter
@synthesize outputFormat = _outputFormat;
@synthesize presentationFrame = _presentationFrame;
@synthesize audioAssetBitRate = _audioAssetBitRate;
@synthesize videoAssetBitRate = _videoAssetBitRate;
@synthesize videoAssetFrameInterval = _videoAssetFrameInterval;

#pragma mark - lifecycle
#pragma mark - init
+ (AKCameraExporter *)shareInstance{
    if (!instance) {
        instance = [[self alloc] init];
    }
    return instance;
}

+ (void)deallocInstance{
    instance = nil;
}

- (void)restore{
    if (exporter) {
        [exporter cancelExport];
        exporter = Nil;
    }
}

- (id)init{
    self = [super init];
    if (self) {
        // setup GLES
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (!_context) {
            //DLog(@"failed to create GL context");
        }
        [self _setupGL];
        // default audio/video configuration
        _audioAssetBitRate = 64000;
        
        // Average bytes per second based on video dimensions
        // lower the bitRate, higher the compression
        // 87500, good for 480 x 360
        // 437500, good for 640 x 480
        // 1312500, good for 1280 x 720
        // 2975000, good for 1920 x 1080
        // 3750000, good for iFrame 960 x 540
        // 5000000, good for iFrame 1280 x 720
        
        CGFloat bytesPerSecond = 437500;
        _videoAssetBitRate = bytesPerSecond * 8;
        _videoAssetFrameInterval = 30;
        
        // Init flags
        _flags.recording = NO;
        _flags.paused = NO;
        
        [self resetupAssetWriter];
        
#if COREVIDEO_USE_EAGLCONTEXT_CLASS_IN_API
        CVReturn cvError = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_videoTextureCache);
#else
        CVReturn cvError = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, (__bridge void *)_context, NULL, &_videoTextureCache);
#endif
        if (cvError) {
            NSLog(@"error CVOpenGLESTextureCacheCreate (%d)", cvError);
        }
        
        _startTimestamp = kCMTimeInvalid;
        
        // Setup akTool
        akTool = [AKCameraTool shareInstance];
        
        //backupWriteQueue = dispatch_queue_create("com.taobao.taobaohuyan.backupWriteQueue", NULL);
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationDidEnterBackground:) name:@"UIApplicationDidEnterBackgroundNotification" object:[UIApplication sharedApplication]];
    }
    return self;
}

- (NSArray *)_metadataArray
{
    UIDevice *currentDevice = [UIDevice currentDevice];
    
    // device model
    AVMutableMetadataItem *modelItem = [[AVMutableMetadataItem alloc] init];
    [modelItem setKeySpace:AVMetadataKeySpaceCommon];
    [modelItem setKey:AVMetadataCommonKeyModel];
    [modelItem setValue:[currentDevice localizedModel]];
    
    // software
    AVMutableMetadataItem *softwareItem = [[AVMutableMetadataItem alloc] init];
    [softwareItem setKeySpace:AVMetadataKeySpaceCommon];
    [softwareItem setKey:AVMetadataCommonKeySoftware];
    [softwareItem setValue:[NSString stringWithFormat:@"%@ %@ AKCameraCapture", [currentDevice systemName], [currentDevice systemVersion]]];
    
    // creation date
    AVMutableMetadataItem *creationDateItem = [[AVMutableMetadataItem alloc] init];
    [creationDateItem setKeySpace:AVMetadataKeySpaceCommon];
    [creationDateItem setKey:AVMetadataCommonKeyCreationDate];
    [creationDateItem setValue:[NSString AKformattedTimestampStringFromDate:[NSDate date]]];
    
    return @[modelItem, softwareItem, creationDateItem];
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _delegate = nil;
    
    [self _cleanUpTextures];
    if (_videoTextureCache) {
        CFRelease(_videoTextureCache);
        _videoTextureCache = NULL;
    }
    [self _destroyGL];
}

#pragma mark - App NSNotifications
// TODO: support suspend/resume video recording
- (void)_applicationDidEnterBackground:(NSNotification *)notification
{
    //DLog(@"AKCameraExporter applicationDidEnterBackground");
    if (_flags.recording && !_flags.paused)
        [self pauseVideoCapture];
}

#pragma mark - Record Phases
- (void)setupParameters{
    _timeOffset = kCMTimeZero;
    _audioTimestamp = kCMTimeZero;
    _videoTimestamp = kCMTimeZero;
    _startTimestamp = kCMTimeInvalid;
    
    _flags.recording = YES;
    _flags.paused = NO;
    _flags.interrupted = NO;
    _flags.videoWritten = NO;
    
    if (!_currentKeyFrames) {
        _currentKeyFrames = [NSMutableArray array];
    } else {
        [_currentKeyFrames removeAllObjects];
    }
    
    if (!usedFiles) {
        usedFiles = [NSMutableArray array];
    } else {
        [usedFiles removeAllObjects];
    }
    
    if (!durationArray) {
        durationArray = [NSMutableArray array];
    } else {
        [durationArray removeAllObjects];
    }
    
    mutableComposition = Nil;
    exporter = Nil;
    
    currentDuration = kCMTimeZero;
    videoDuration = kCMTimeZero;
}

- (void)resetupAssetWriter{
    assetWriter = nil; // make sure
    NSError *error = nil;
    NSURL *outputURL = [NSURL fileURLWithPath:_maxSeconds >= 60 ? [self uniqueMergeMovieFilePath] : [self uniqueTempMovieFilePath]];
    assetWriter = [[AVAssetWriter alloc] initWithURL:outputURL fileType:kRecordFileType error:&error];
    if (error) {
        //DLog(@"error setting up the asset writer (%@)", error);
        assetWriter = nil;
        [self _enqueueBlockOnMainQueue:^{
            if ([_delegate respondsToSelector:@selector(akExporterDidStartVideoCapture: error:)])
                [_delegate akExporterDidStartVideoCapture:self error:error];
        }];
        return;
    }
    assetWriter.movieFragmentInterval = CMTimeMakeWithSeconds(1.0, 1000);
    assetWriter.shouldOptimizeForNetworkUse = YES;
    assetWriter.metadata = [self _metadataArray];
    
    _flags.isAudioReady = NO;
    _flags.isVideoReady = NO;
    
    // It's possible to capture video without audio. If the user has denied access to the microphone, we don't need to setup the audio output device
    if (IOSVersion >= 7.0 && [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio] == AVAuthorizationStatusDenied) {
        _flags.isAudioReady = YES;
    }
}

- (void)startVideoCapture{
    if (_flags.recording || _flags.paused)
        return;
    
    [self setupParameters];
    
    [self _enqueueBlockOnMainQueue:^{
        if ([_delegate respondsToSelector:@selector(akExporterDidStartVideoCapture: error:)])
            [_delegate akExporterDidStartVideoCapture:self error:nil];
    }];
}

- (void)pauseVideoCapture{
    if (!_flags.recording)
        return;
    
    if (!assetWriter) {
        //DLog(@"media writer unavailable to stop");
        return;
    }
    
    //DLog(@"pausing video capture");
    
    _flags.paused = YES;
    _flags.interrupted = YES;
    
    Float64 duration = CMTimeGetSeconds(videoDuration);
    // no delete back for 60s
    
    if (_maxSeconds >= 60) {
        // no delete back
        [self _enqueueBlockOnMainQueue:^{
            if ([_delegate respondsToSelector:@selector(akExporterDidPauseVideoCapture: duration:)])
                [_delegate akExporterDidPauseVideoCapture:self duration:duration];
        }];
        return;
    }
    if([self finishAssetWriter]) {
        [self pushSegement];
    } else {
        [_delegate akExporterDidPauseVideoCaptureFailed:self];
    }
    
    [self setupAssetWriter];
    [self reset];
    
    [self _enqueueBlockOnMainQueue:^{
        if ([_delegate respondsToSelector:@selector(akExporterDidPauseVideoCapture: duration:)])
            [_delegate akExporterDidPauseVideoCapture:self duration:duration];
    }];
}

- (void)resumeVideoCapture{
    if (!_flags.recording || !_flags.paused)
        return;
    
    if (!assetWriter) {
        //DLog(@"media writer unavailable to resume");
        return;
    }
    
    //DLog(@"resuming video capture");
    
    _flags.paused = NO;
    
    // add frames to queue.
    if ([_currentKeyFrames count] > 0) {
        [akTool.video.keyFrames addObject:[_currentKeyFrames copy]];
    }
    [_currentKeyFrames removeAllObjects];
    
    [self _enqueueBlockOnMainQueue:^{
        if ([_delegate respondsToSelector:@selector(akExporterDidResumeVideoCapture:)])
            [_delegate akExporterDidResumeVideoCapture:self];
    }];
}

- (void)endVideoCapture{
    if (!_flags.recording)
        return;
    
    if (!assetWriter) {
        //DLog(@"media writer unavailable to end");
        return;
    }
    
    if (_maxSeconds >= 60) {
        _flags.recording = NO;
        _flags.paused = NO;
        void (^finishWritingCompletionHandler)(void) = ^{
            _timeOffset = kCMTimeZero;
            _audioTimestamp = kCMTimeZero;
            _videoTimestamp = kCMTimeZero;
            //_startTimestamp = CMClockGetTime(CMClockGetHostTimeClock());
            _flags.interrupted = NO;
            
            // add and save
            [akTool.video.movieFilePaths addObject:assetWriter.outputURL];
            [akTool syncDataToCache];
            
            // just call end
            [self _enqueueBlockOnMainQueue:^{
                if ([_delegate respondsToSelector:@selector(akExporterDidEndVideoCapture: error:)])
                    [_delegate akExporterDidEndVideoCapture:self error:assetWriter.error];
            }];
        };
        [assetWriter finishWritingWithCompletionHandler:finishWritingCompletionHandler];
        return;
    }
    
    
    if (!_flags.paused) {
        // Must be paused
        APP_ASSERT_STOP
        //[self pauseVideoCapture];
    }
    
    [self _enqueueBlockOnMainQueue:^{
        if ([_delegate respondsToSelector:@selector(akExporterDidEndVideoCapture: error:)])
            [_delegate akExporterDidEndVideoCapture:self error:assetWriter.error];
    }];
}


-(void)cancelVideoCapture{
    /// 取消队列
    _flags.recording = NO;
    
    // 删除缓存文件
    [_currentKeyFrames removeAllObjects];
    
    if (assetWriter.status == AVAssetWriterStatusCompleted)
    {
        return;
    }
    
    if( assetWriter.status == AVAssetWriterStatusWriting )
    {
        [assetWriterVideoIn markAsFinished];
        [assetWriterAudioIn markAsFinished];
    }
    [assetWriter cancelWriting];
}

#pragma mark restore from cache
- (void)restoreFromMoviesWithProgress:(NSArray *)progresses {
    for (NSValue *progress in progresses) {
        [durationArray addObject:progress];
        ////DLog(@"push progress: %f, current: %f", CMTimeGetSeconds(videoDuration), CMTimeGetSeconds(currentDuration));
        videoDuration = CMTimeAdd(videoDuration, progress.CMTimeValue);
    }
}

#pragma mark merge movie files
- (NSURL *)mergeMovieFiles{
    NSUInteger count = [akTool.video.movieFilePaths count];
    mutableComposition = [AVMutableComposition composition];
    AVMutableCompositionTrack *audioTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *videoTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    NSError *error = nil;
    
    NSURL *url = Nil;
    CMTime audioOffset = kCMTimeZero;
    CMTime videoOffset = kCMTimeZero;
    AVURLAsset* asset;
    AVAssetTrack *at, *vt;
    for (int i = 0; i < count; i++) {
        url = [akTool.video.movieFilePaths objectAtIndex:i];
        asset = [[AVURLAsset alloc]initWithURL:url options:nil];
        
        // add audio
        if ([[asset tracksWithMediaType:AVMediaTypeAudio] count] > 0) {
            at = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
            if(![audioTrack insertTimeRange:at.timeRange ofTrack:at atTime:audioOffset error:&error]){
                //DLog(@"add audio track failed");
            } else {
                //DLog(@"add audio range:%f : %f at: %f", CMTimeGetSeconds(at.timeRange.start), CMTimeGetSeconds(at.timeRange.duration), CMTimeGetSeconds(audioOffset));
            }
            audioOffset = CMTimeAdd(audioOffset, at.timeRange.duration);
        } else {
            //DLog(@"no audio track: %@", url);
        }
        
        // add video
        if ([[asset tracksWithMediaType:AVMediaTypeVideo] count] > 0) {
            vt = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
            if (![videoTrack insertTimeRange:vt.timeRange ofTrack:vt atTime:videoOffset error:&error]) {
                //DLog(@"add video track failed");
            } else {
                //DLog(@"add video range:%f : %f at: %f", CMTimeGetSeconds(vt.timeRange.start), CMTimeGetSeconds(vt.timeRange.duration), CMTimeGetSeconds(videoOffset));
            }
            videoOffset  = CMTimeAdd(videoOffset, vt.timeRange.duration);
        } else {
            //DLog(@"no video track: %@", url);
        }
        
    }
    
    akTool.video.duration = @(CMTimeGetSeconds(videoOffset)); //duration
    
    if (count == 1) {
        return [akTool.video.movieFilePaths firstObject];
    }
    
    [self doExport];
    return nil;
}

- (void)doExport{
    exporter = [[AVAssetExportSession alloc]initWithAsset:mutableComposition presetName:AVAssetExportPresetMediumQuality];
    exporter.outputFileType = ([[[UIDevice currentDevice] systemVersion] floatValue] < 6.0 ? AVFileTypeQuickTimeMovie : kRecordFileType);
    exporter.outputURL = [NSURL fileURLWithPath:[self uniqueMergeMovieFilePath]];
    
    // do the export
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        AVAssetExportSessionStatus exportStatus = exporter.status;
        switch (exportStatus) {
            case AVAssetExportSessionStatusFailed:{
                NSError *exportError = exporter.error;
                NSLog (@"AVAssetExportSessionStatusFailed: %@", exportError);
                if (_delegate && [_delegate respondsToSelector:@selector(akExporterDidExportMovie:movieUrl:)]) {
                    [_delegate akExporterDidExportMovie:self movieUrl:Nil];
                }
                break;
            }
            case AVAssetExportSessionStatusCompleted:{
                //DLog (@"AVAssetExportSessionStatusCompleted");
                if (_delegate && [_delegate respondsToSelector:@selector(akExporterDidExportMovie:movieUrl:)]) {
                    [_delegate akExporterDidExportMovie:self movieUrl:exporter.outputURL];
                }
                break;
            }
            default:
                //DLog(@"status unknown");
                break;
                
        }
    }];
}

- (void)reset{
    _startTimestamp = kCMTimeInvalid; // new start time
    _timeOffset = kCMTimeZero;
    _audioTimestamp = kCMTimeZero;
    _videoTimestamp = kCMTimeZero;
    
    _flags.recording = YES;
    _flags.paused = YES;
    _flags.interrupted = NO;
    _flags.videoWritten = NO;
    
    // resetup input
    _flags.isAudioReady = NO;
    _flags.isVideoReady = NO;
    
    // duration
    currentDuration = kCMTimeZero;
}

#pragma mark - For Delete Back
- (BOOL)finishAssetWriter{
    if (assetWriter.status == AVAssetWriterStatusCompleted)
    {
        [AKCameraUtils deleteFile:assetWriter.outputURL]; //delete file
        return NO;
    } else {
        if (assetWriter.status == AVAssetWriterStatusCompleted || assetWriter.status == AVAssetWriterStatusCancelled || assetWriter.status == AVAssetWriterStatusUnknown)
        {
            return NO;
        }
        @try{
#if (!defined(__IPHONE_6_0) || (__IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_6_0))
            // Not iOS 6 SDK
            [assetWriter finishWriting];
#else
            // iOS 6 SDK
            NSLog(@"%li", (long)assetWriter.status);
            if ([assetWriter respondsToSelector:@selector(finishWritingWithCompletionHandler:)]) {
                // Running iOS 6
                __block BOOL finished = NO;
                [assetWriter finishWritingWithCompletionHandler:^{
                    NSLog(@"finished");
                    finished = YES;
                }]; // 这是一个异步方法
                // 等待返回
                while(!finished){
                    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
                }
            }
            else {
                // Not running iOS 6
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                [assetWriter finishWriting]; // 这是同步方法
#pragma clang diagnostic pop
            }
#endif
        }@catch(id anException){
            //do nothing, obviously it wasn't attached because an exception was thrown
            NSLog(@"%@", anException);
            return NO;
        }

        if (assetWriter.error) {
            //DLog(@"finish assetWriter error: %@", assetWriter.error);
            return NO;
        }
        //DLog(@"backup writer finished:%@", assetWriter.outputURL);
    }
    return YES;
}

- (void)setupAssetWriter{
    // clear
    assetWriter = nil;
    
    NSError *error = nil;
    NSString *filePath = [self uniqueTempMovieFilePath];
    //unlink([filePath UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
    assetWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:filePath] fileType:AVFileTypeMPEG4 error:&error];
    if (error != nil)
    {
        NSLog(@"Error: %@", error);
        return;
    }
    assetWriter.movieFragmentInterval = CMTimeMakeWithSeconds(1.0, 1000);
    assetWriter.shouldOptimizeForNetworkUse = YES;
    assetWriter.metadata = [self _metadataArray];
}

#pragma mark - Segements
- (BOOL)canDeleteLastFragment{
    return _maxSeconds < 60 && [akTool.video.movieFilePaths count] > 0;
}

- (void)deleteLastFragment:(NSInteger)count{
    if (![self canDeleteLastFragment]) {
        //不能删除了
        return;
    }
    while ([akTool.video.movieFilePaths count] > count) { //数量不对
        [self popSegement];
    }
    [self popSegement];
}

- (void)pushSegement{ //在暂停的时候
    [akTool.video.movieFilePaths addObject:assetWriter.outputURL];
    [durationArray addObject:[NSValue valueWithCMTime:videoDuration]];
    NSLog(@"push progress: %f, current: %f", CMTimeGetSeconds(videoDuration), CMTimeGetSeconds(currentDuration));
    videoDuration = CMTimeAdd(videoDuration, currentDuration);
}

// must run on main queue
- (void)popSegement{
    //DLog(@"pop segement");
    //[Tools deleteFile:[finishedVideoFiles lastObject]]; //no delete file
    [akTool.video.movieFilePaths removeLastObject];
    
    // 修正进度
    videoDuration = [(NSValue *)[durationArray objectAtIndex:[durationArray count] - 1] CMTimeValue];
    [durationArray removeLastObject];
    
    // Update cover & keyframes
    NSUInteger count = [akTool.video.movieFilePaths count];
    if ([AKCameraStyle useDefaultCover]) {
        if (count == 0) {
            akTool.video.defaultCover = nil; // reset
        }
    } else {
        [_currentKeyFrames removeAllObjects];
        if (count > 0) {
            _currentKeyFrames = [[akTool.video.keyFrames lastObject] mutableCopy];
            [akTool.video.keyFrames removeLastObject];
        }
    }
    
    
    if ([_delegate respondsToSelector:@selector(akExporterDidDeleteLastSegement:)]) {
        [_delegate akExporterDidDeleteLastSegement:self];
    }
}

#pragma mark - queue helper methods

typedef void (^AKCameraExporterBlock)();

- (void)_enqueueBlockOnMainQueue:(AKCameraExporterBlock)block {
    dispatch_async(dispatch_get_main_queue(), ^{
        block();
    });
}

- (void)_executeBlockOnMainQueue:(AKCameraExporterBlock)block {
    dispatch_sync(dispatch_get_main_queue(), ^{
        block();
    });
}

#pragma mark - sample buffer setup

- (BOOL)_setupMediaWriterAudioInputWithSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    
	const AudioStreamBasicDescription *asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
    if (!asbd) {
        //DLog(@"audio stream description used with non-audio format description");
        return NO;
    }
    
	unsigned int channels = asbd->mChannelsPerFrame;
    double sampleRate = asbd->mSampleRate;
    
    //DLog(@"audio stream setup, channels (%d) sampleRate (%f)", channels, sampleRate);
    
    size_t aclSize = 0;
	const AudioChannelLayout *currentChannelLayout = CMAudioFormatDescriptionGetChannelLayout(formatDescription, &aclSize);
	NSData *currentChannelLayoutData = ( currentChannelLayout && aclSize > 0 ) ? [NSData dataWithBytes:currentChannelLayout length:aclSize] : [NSData data];
    
    NSDictionary *audioCompressionSettings = @{ AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                                AVNumberOfChannelsKey : @(channels),
                                                AVSampleRateKey :  @(sampleRate),
                                                AVEncoderBitRateKey : @(_audioAssetBitRate),
                                                AVChannelLayoutKey : currentChannelLayoutData };
    
    return [self setupAudioOutputDeviceWithSettings:audioCompressionSettings];
}

- (BOOL)_setupMediaWriterVideoInputWithSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
	CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);
    
    CMVideoDimensions videoDimensions = dimensions;
    switch (_outputFormat) {
        case AKOutputFormatSquare:
        {
            int32_t min = MIN(dimensions.width, dimensions.height);
            videoDimensions.width = min;
            videoDimensions.height = min;
            break;
        }
        case AKOutputFormatWidescreen:
        {
            videoDimensions.width = dimensions.width;
            videoDimensions.height = (int32_t)(dimensions.width / 1.5f);
            break;
        }
        case AKOutputFormatPreset:
        default:
            break;
    }
    
    NSDictionary *compressionSettings = @{ AVVideoAverageBitRateKey : @(_videoAssetBitRate),
                                           AVVideoMaxKeyFrameIntervalKey : @(_videoAssetFrameInterval) };
    
	NSDictionary *videoSettings = @{ AVVideoCodecKey : AVVideoCodecH264,
                                     AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                                     AVVideoWidthKey : @(videoDimensions.width),
                                     AVVideoHeightKey : @(videoDimensions.height),
                                     AVVideoCompressionPropertiesKey : compressionSettings };
    
    return [self setupVideoOutputDeviceWithSettings:videoSettings];
}

- (BOOL)setupAudioOutputDeviceWithSettings:(NSDictionary *)audioSettings
{
	if ([assetWriter canApplyOutputSettings:audioSettings forMediaType:AVMediaTypeAudio]) {
        
		assetWriterAudioIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
		assetWriterAudioIn.expectsMediaDataInRealTime = YES;
        
        NSLog(@"prepared audio-in with compression settings sampleRate (%f) channels (%lu) bitRate (%ld)",
             [[audioSettings objectForKey:AVSampleRateKey] floatValue],
             (unsigned long)[[audioSettings objectForKey:AVNumberOfChannelsKey] unsignedIntegerValue],
             (long)[[audioSettings objectForKey:AVEncoderBitRateKey] integerValue]);
        
		if ([assetWriter canAddInput:assetWriterAudioIn]) {
			[assetWriter addInput:assetWriterAudioIn];
            _flags.isAudioReady = YES;
		} else {
			//DLog(@"couldn't add asset writer audio input");
		}
        
	} else {
        
		//DLog(@"couldn't apply audio output settings");
        
	}
    
    return _flags.isAudioReady;
}

- (BOOL)setupVideoOutputDeviceWithSettings:(NSDictionary *)videoSettings
{
	if ([assetWriter canApplyOutputSettings:videoSettings forMediaType:AVMediaTypeVideo]) {
		assetWriterVideoIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
		assetWriterVideoIn.expectsMediaDataInRealTime = YES;
		assetWriterVideoIn.transform = CGAffineTransformIdentity;
        
        NSDictionary *videoCompressionProperties = [videoSettings objectForKey:AVVideoCompressionPropertiesKey];
        if (videoCompressionProperties)
            NSLog(@"prepared video-in with compression settings bps (%f) frameInterval (%ld)",
                 [[videoCompressionProperties objectForKey:AVVideoAverageBitRateKey] floatValue],
                 (long)[[videoCompressionProperties objectForKey:AVVideoMaxKeyFrameIntervalKey] integerValue]);
        
		if ([assetWriter canAddInput:assetWriterVideoIn]) {
			[assetWriter addInput:assetWriterVideoIn];
            _flags.isVideoReady = YES;
		} else {
			//DLog(@"couldn't add asset writer video input");
		}
	} else {
		//DLog(@"couldn't apply video output settings");
        
	}
    
    return _flags.isVideoReady;
}
#pragma mark - OpenGLES context support

- (void)_setupBuffers
{
    
    // unit square for testing
    //    static const GLfloat unitSquareVertices[] = {
    //        -1.0f, -1.0f,
    //        1.0f, -1.0f,
    //        -1.0f,  1.0f,
    //        1.0f,  1.0f,
    //    };
    
    CGSize inputSize = CGSizeMake(_bufferWidth, _bufferHeight);
    CGRect insetRect = AVMakeRectWithAspectRatioInsideRect(inputSize, _presentationFrame);
    
    CGFloat widthScale = CGRectGetHeight(_presentationFrame) / CGRectGetHeight(insetRect);
    CGFloat heightScale = CGRectGetWidth(_presentationFrame) / CGRectGetWidth(insetRect);
    
    static GLfloat vertices[8];
    
    vertices[0] = (GLfloat) -widthScale;
    vertices[1] = (GLfloat) -heightScale;
    vertices[2] = (GLfloat) widthScale;
    vertices[3] = (GLfloat) -heightScale;
    vertices[4] = (GLfloat) -widthScale;
    vertices[5] = (GLfloat) heightScale;
    vertices[6] = (GLfloat) widthScale;
    vertices[7] = (GLfloat) heightScale;
    
    static const GLfloat textureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    
    static const GLfloat textureCoordinatesVerticalFlip[] = {
        1.0f, 1.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
    };
    
    glEnableVertexAttribArray(AKCameraAttributeVertex);
    glVertexAttribPointer(AKCameraAttributeVertex, 2, GL_FLOAT, GL_FALSE, 0, vertices);
    
    if (_bufferDevice == AKCameraDeviceFront) {
        glEnableVertexAttribArray(AKCameraAttributeTextureCoord);
        glVertexAttribPointer(AKCameraAttributeTextureCoord, 2, GL_FLOAT, GL_FALSE, 0, textureCoordinatesVerticalFlip);
    } else {
        glEnableVertexAttribArray(AKCameraAttributeTextureCoord);
        glVertexAttribPointer(AKCameraAttributeTextureCoord, 2, GL_FLOAT, GL_FALSE, 0, textureCoordinates);
    }
}

- (void)_setupGL
{
    [EAGLContext setCurrentContext:_context];
    
    [self _loadShaders];
    
    glUseProgram(_program);
    
    glUniform1i(_uniforms[AKCameraUniformY], 0);
    glUniform1i(_uniforms[AKCameraUniformUV], 1);
}

- (void)_destroyGL
{
    [EAGLContext setCurrentContext:_context];
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
    
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
}

#pragma mark - OpenGLES shader support
// TODO: abstract this in future

- (BOOL)_loadShaders
{
    GLuint vertShader;
    GLuint fragShader;
    NSString *vertShaderName;
    NSString *fragShaderName;
    
    _program = glCreateProgram();
    
    vertShaderName = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self _compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderName]) {
        //DLog(@"failed to compile vertex shader");
        return NO;
    }
    
    fragShaderName = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self _compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderName]) {
        //DLog(@"failed to compile fragment shader");
        return NO;
    }
    
    glAttachShader(_program, vertShader);
    glAttachShader(_program, fragShader);
    
    glBindAttribLocation(_program, AKCameraAttributeVertex, "a_position");
    glBindAttribLocation(_program, AKCameraAttributeTextureCoord, "a_texture");
    
    if (![self _linkProgram:_program]) {
        //DLog(@"failed to link program, %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    _uniforms[AKCameraUniformY] = glGetUniformLocation(_program, "u_samplerY");
    _uniforms[AKCameraUniformUV] = glGetUniformLocation(_program, "u_samplerUV");
    
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)_compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        //DLog(@"failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)_linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

#pragma mark - process buffers
#pragma mark - sample buffer processing
- (void)_cleanUpTextures
{
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
    
    if (_lumaTexture) {
        CFRelease(_lumaTexture);
        _lumaTexture = NULL;
    }
    
    if (_chromaTexture) {
        CFRelease(_chromaTexture);
        _chromaTexture = NULL;
    }
}

// convert CoreVideo YUV pixel buffer (Y luminance and Cb Cr chroma) into RGB
// processing is done on the GPU, operation WAY more efficient than converting .on the CPU
- (void)_processSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (!_context)
        return;
    
    if (!_videoTextureCache)
        return;
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    if (CVPixelBufferLockBaseAddress(imageBuffer, 0) != kCVReturnSuccess)
        return;
    
    [EAGLContext setCurrentContext:_context];
    
    [self _cleanUpTextures];
    
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // only bind the vertices once or if parameters change
    
    if (_bufferWidth != width ||
        _bufferHeight != height ||
        _bufferDevice != [[AKCameraCaputure sharedInstance] cameraDevice] ||
        _bufferOrientation != [[AKCameraCaputure sharedInstance] cameraOrientation]) {
        
        _bufferWidth = width;
        _bufferHeight = height;
        _bufferDevice = [[AKCameraCaputure sharedInstance] cameraDevice];
        _bufferOrientation = [[AKCameraCaputure sharedInstance] cameraOrientation];
        [self _setupBuffers];
        
    }
    
    // always upload the texturs since the input may be changing
    
    CVReturn error = 0;
    
    // Y-plane
    glActiveTexture(GL_TEXTURE0);
    error = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                         _videoTextureCache,
                                                         imageBuffer,
                                                         NULL,
                                                         GL_TEXTURE_2D,
                                                         GL_RED_EXT,
                                                         (GLsizei)_bufferWidth,
                                                         (GLsizei)_bufferHeight,
                                                         GL_RED_EXT,
                                                         GL_UNSIGNED_BYTE,
                                                         0,
                                                         &_lumaTexture);
    if (error) {
        //DLog(@"error CVOpenGLESTextureCacheCreateTextureFromImage (%d)", error);
    }
    
    glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture), CVOpenGLESTextureGetName(_lumaTexture));
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // UV-plane
    glActiveTexture(GL_TEXTURE1);
    error = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                         _videoTextureCache,
                                                         imageBuffer,
                                                         NULL,
                                                         GL_TEXTURE_2D,
                                                         GL_RG_EXT,
                                                         (GLsizei)(_bufferWidth * 0.5),
                                                         (GLsizei)(_bufferHeight * 0.5),
                                                         GL_RG_EXT,
                                                         GL_UNSIGNED_BYTE,
                                                         1,
                                                         &_chromaTexture);
    if (error) {
        //DLog(@"error CVOpenGLESTextureCacheCreateTextureFromImage (%d)", error);
    }
    
    glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture), CVOpenGLESTextureGetName(_chromaTexture));
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    if (CVPixelBufferUnlockBaseAddress(imageBuffer, 0) != kCVReturnSuccess)
        return;
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer isAudio:(BOOL)isAudio isVideo:(BOOL)isVideo{
    /*
    if (isAudio) {
        //DLog(@"we have a audio buffer");
    }
    if (isVideo) {
        //DLog(@"we have a video buffer");
    }
     */
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        //DLog(@"audio buffer data is not ready");
        CFRelease(sampleBuffer);
        return;
    }
    
    if (!_flags.recording) {
        CFRelease(sampleBuffer);
        return;
    }
    
    CMTime pTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    if (_flags.paused) {
        // check pause time
        if (!_delegate || ! [_delegate respondsToSelector:@selector(akExporterGetPauseTime)]) {
            CFRelease(sampleBuffer);
            return;
        }
        CMTime pauseTime = [_delegate akExporterGetPauseTime]; // get precise time
        ////DLog(@"pauseTime: %f, sampleBuffer: %f", CMTimeGetSeconds(pauseTime), CMTimeGetSeconds(pTimestamp));
        if (CMTIME_IS_INVALID(pauseTime) || CMTimeCompare(pTimestamp, pauseTime) == 1) {
            CFRelease(sampleBuffer);
            return;
        }
        //DLog(@"we has a delay sampleBuffer");
    }
    
    if (isAudio && !_flags.isAudioReady) {
        [self _setupMediaWriterAudioInputWithSampleBuffer:sampleBuffer];
        //DLog(@"ready for audio (%d)", _flags.isAudioReady);
    }
    
    if (isVideo && !_flags.isVideoReady) {
        [self _setupMediaWriterVideoInputWithSampleBuffer:sampleBuffer];
        //DLog(@"ready for video (%d)", _flags.isVideoReady);
    }
    
    BOOL isReadyToRecord = (_flags.isAudioReady && _flags.isVideoReady);
    if (!isReadyToRecord) {
        CFRelease(sampleBuffer);
        return;
    }
    
    // calculate the length of the interruption
    if (_flags.interrupted && isAudio) {
        _flags.interrupted = NO;
        
        CMTime time = _audioTimestamp;
        // calculate the appropriate time offset
        if (CMTIME_IS_VALID(time)) {
            if (CMTIME_IS_VALID(_timeOffset)) {
                pTimestamp = CMTimeSubtract(pTimestamp, _timeOffset);
            }
            
            CMTime offset = CMTimeSubtract(pTimestamp, _audioTimestamp);
            _timeOffset = (_timeOffset.value == 0) ? offset : CMTimeAdd(_timeOffset, offset);
            //DLog(@"new calculated offset %f valid (%d)", CMTimeGetSeconds(_timeOffset), CMTIME_IS_VALID(_timeOffset));
        } else {
            //DLog(@"invalid audio timestamp, no offset update");
        }
        
        _audioTimestamp.flags = 0;
        _videoTimestamp.flags = 0;
        
    }
    
    CMSampleBufferRef bufferToWrite = NULL;
    
    if (_timeOffset.value > 0) {
        bufferToWrite = [self _createOffsetSampleBuffer:sampleBuffer withTimeOffset:_timeOffset];
        if (!bufferToWrite) {
            //DLog(@"error subtracting the timeoffset from the sampleBuffer");
        }
    } else {
        bufferToWrite = sampleBuffer;
        CFRetain(bufferToWrite);
    }
    
    if (isVideo && !_flags.interrupted) {
        if (bufferToWrite) {
            // update video and the last timestamp
            CMTime time = CMSampleBufferGetPresentationTimeStamp(bufferToWrite);
            CMTime duration = CMSampleBufferGetDuration(bufferToWrite);
            if (duration.value > 0)
                time = CMTimeAdd(time, duration);
            
            if (time.value > _videoTimestamp.value) {
                [self writeSampleBuffer:bufferToWrite ofType:AVMediaTypeVideo];
                _videoTimestamp = time;
                _flags.videoWritten = YES;
                
                // save cover
                if ([AKCameraStyle useDefaultCover]) {
                    if (!akTool.video.defaultCover) {
                        akTool.video.defaultCover = [self imageFromSampleBuffer:bufferToWrite];
                        [akTool syncDataToCache];
                    }
                } else {
                    // save key frames
                    if (_currentFrame % (_maxFrames / kMaxKeyFrames) == 0) {
                        [_currentKeyFrames addObject:[self imageFromSampleBuffer:bufferToWrite]];
                    }
                    _currentFrame ++;
                }
            }
            
            // process the sample buffer for rendering
            if (_flags.videoRenderingEnabled && _flags.videoWritten) {
                [self _executeBlockOnMainQueue:^{
                    [self _processSampleBuffer:bufferToWrite];
                }];
            }
            
            // update progress
            CMTime willDuration = CMTimeSubtract(_videoTimestamp, _startTimestamp);
            if (CMTimeCompare(willDuration, currentDuration) == 1) {
                currentDuration = willDuration;
                ////DLog(@"currentDuration: %f", CMTimeGetSeconds(currentDuration));
            }
            
            [self _enqueueBlockOnMainQueue:^{
                if ([_delegate respondsToSelector:@selector(akExporterDidCaptureVideoSample:)]) {
                    [_delegate akExporterDidCaptureVideoSample:self];
                }
            }];
        }
        
    } else if (isAudio && !_flags.interrupted) {
        
        if (bufferToWrite && _flags.videoWritten) {
            // update the last audio timestamp
            CMTime time = CMSampleBufferGetPresentationTimeStamp(bufferToWrite);
            CMTime duration = CMSampleBufferGetDuration(bufferToWrite);
            if (duration.value > 0)
                time = CMTimeAdd(time, duration);
            
            if (time.value > _audioTimestamp.value) {
                [self writeSampleBuffer:bufferToWrite ofType:AVMediaTypeAudio];
                _audioTimestamp = time;
            }
            
            // update progress
            CMTime willDuration = CMTimeSubtract(_audioTimestamp, _startTimestamp);
            if (CMTimeCompare(willDuration, currentDuration) == 1) {
                currentDuration = willDuration;
                ////DLog(@"currentDuration: %f", CMTimeGetSeconds(currentDuration));
            }[self _enqueueBlockOnMainQueue:^{
                if ([_delegate respondsToSelector:@selector(akExporterDidCaptureAudioSample:)]) {
                    [_delegate akExporterDidCaptureAudioSample:self];
                }
            }];
        }
    }
    
    if (bufferToWrite)
        CFRelease(bufferToWrite);
    
    CFRelease(sampleBuffer);
}


#pragma mark - sample buffer writing

- (void)writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType
{
	if ( assetWriter.status == AVAssetWriterStatusUnknown ) {
        
        if ([assetWriter startWriting]) {
            CMTime startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
			[assetWriter startSessionAtSourceTime:startTime];
            _startTimestamp = startTime;
            //DLog(@"started writing with status (%ld)", (long)assetWriter.status);
		} else {
			//DLog(@"error when starting to write (%@)", [assetWriter error]);
		}
        
	}
    
    if ( assetWriter.status == AVAssetWriterStatusFailed ) {
        //DLog(@"writer failure, (%@)", assetWriter.error.localizedDescription);
        return;
    }
	
	if ( assetWriter.status == AVAssetWriterStatusWriting ) {
		if (mediaType == AVMediaTypeVideo) {
			if (assetWriterVideoIn.readyForMoreMediaData) {
				if (![assetWriterVideoIn appendSampleBuffer:sampleBuffer]) {
					//DLog(@"writer error appending video (%@)", [assetWriter error]);
				}
			}
		} else if (mediaType == AVMediaTypeAudio) {
			if (assetWriterAudioIn.readyForMoreMediaData) {
				if (![assetWriterAudioIn appendSampleBuffer:sampleBuffer]) {
					//DLog(@"writer error appending audio (%@)", [assetWriter error]);
				}
			}
		}
        
	}
    
}

- (void)finishWritingWithCompletionHandler:(void (^)(void))handler
{
    if (assetWriter.status == AVAssetWriterStatusUnknown) {
        //DLog(@"asset writer is in an unknown state, wasn't recording");
        return;
    }
    
    [assetWriter finishWritingWithCompletionHandler:handler];
    
    _flags.isAudioReady = NO;
    _flags.isVideoReady = NO;
}

#pragma mark - getter & setter
- (NSURL *)checkExportOutputURL{
    if (!exporter || [akTool.video.movieFilePaths count] == 1) {
        return [akTool.video.movieFilePaths firstObject];
    }
    if (exporter.status == AVAssetExportSessionStatusFailed) {
        return nil;
    } else if (exporter.status == AVAssetExportSessionStatusExporting) {
        while(exporter.status == AVAssetExportSessionStatusExporting){
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
    }
    return exporter.outputURL;
}
- (BOOL)isRecording
{
    return _flags.recording;
}

- (BOOL)isPaused
{
    return _flags.paused;
}

- (void)setVideoRenderingEnabled:(BOOL)videoRenderingEnabled
{
    _flags.videoRenderingEnabled = (unsigned int)videoRenderingEnabled;
}

- (BOOL)isVideoRenderingEnabled
{
    return _flags.videoRenderingEnabled;
}

- (Float64)capturedAudioSeconds
{
    if (_audioTimestamp.value > 0) {
        ////DLog(@"current:%f", CMTimeGetSeconds(CMTimeSubtract(_audioTimestamp, _startTimestamp)));
        return CMTimeGetSeconds(CMTimeSubtract(_audioTimestamp, _startTimestamp));
    } else {
        return 0.0;
    }
}

- (Float64)capturedVideoSeconds
{
    if (_videoTimestamp.value > 0) {
        ////DLog(@"current:%f", CMTimeGetSeconds(CMTimeSubtract(_videoTimestamp, _startTimestamp)));
        return CMTimeGetSeconds(CMTimeSubtract(_videoTimestamp, _startTimestamp));
    } else {
        return 0.0;
    }
}

- (void)setOutputFormat:(AKOutputFormat)outputFormat
{
    //[self _setCameraMode:_cameraMode cameraDevice:_cameraDevice outputFormat:outputFormat];
    _outputFormat = outputFormat;
}

- (AVComposition *)getComposition{
    //return Nil;
    return mutableComposition;
}

- (Float64)getDuration{
    return CMTimeGetSeconds(CMTimeAdd(videoDuration, currentDuration));
}

- (CMTime)getSegementStartTime{
    return _startTimestamp;
}

- (NSMutableArray *)keyFrames{
    // Default cover
    if ([AKCameraStyle useDefaultCover]) {
        return [NSMutableArray arrayWithObject:akTool.video.defaultCover];
    }
    
    // Key frames
    NSMutableArray *result = [NSMutableArray array];
    [akTool.video.keyFrames enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
        [result addObjectsFromArray:(NSArray *)obj];
    }];
    [result addObjectsFromArray:_currentKeyFrames];
    return result;
}

#pragma mark - Utils
- (NSString *)uniqueTempMovieFilePath{
    NSString *name = [AKCameraUtils uniqueMovieFileNameWithPrefix:@"temp" notIn:usedFiles];
    NSLog(@"new file name:%@", name);
    [usedFiles addObject:name];
    return [[AKCameraUtils getVideoPath] stringByAppendingPathComponent:name];
}

- (NSString *)uniqueMergeMovieFilePath{
    NSString *name = [AKCameraUtils uniqueMovieFileNameWithPrefix:@"merged" notIn:usedFiles];
    NSLog(@"new file name:%@", name);
    [usedFiles addObject:name];
    return [[AKCameraUtils getVideoPath] stringByAppendingPathComponent:name];
}

- (CMSampleBufferRef)_createOffsetSampleBuffer:(CMSampleBufferRef)sampleBuffer withTimeOffset:(CMTime)timeOffset
{
    CMItemCount itemCount;
    
    OSStatus status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, 0, NULL, &itemCount);
    if (status) {
        //DLog(@"couldn't determine the timing info count");
        return NULL;
    }
    
    CMSampleTimingInfo *timingInfo = (CMSampleTimingInfo *)malloc(sizeof(CMSampleTimingInfo) * (unsigned long)itemCount);
    if (!timingInfo) {
        //DLog(@"couldn't allocate timing info");
        return NULL;
    }
    
    status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, itemCount, timingInfo, &itemCount);
    if (status) {
        free(timingInfo);
        timingInfo = NULL;
        //DLog(@"failure getting sample timing info array");
        return NULL;
    }
    
    for (CMItemCount i = 0; i < itemCount; i++) {
        timingInfo[i].presentationTimeStamp = CMTimeSubtract(timingInfo[i].presentationTimeStamp, timeOffset);
        timingInfo[i].decodeTimeStamp = CMTimeSubtract(timingInfo[i].decodeTimeStamp, timeOffset);
    }
    
    CMSampleBufferRef outputSampleBuffer;
    CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, sampleBuffer, itemCount, timingInfo, &outputSampleBuffer);
    
    if (timingInfo) {
        free(timingInfo);
        timingInfo = NULL;
    }
    
    return outputSampleBuffer;
}

- (UIImage *)imageFromPixBuffer:(CVPixelBufferRef)pixelBuffer{
    unsigned long w = CVPixelBufferGetWidth(pixelBuffer);
    unsigned long h = CVPixelBufferGetHeight(pixelBuffer);
    unsigned long r = CVPixelBufferGetBytesPerRow(pixelBuffer);
    unsigned long bytesPerPixel = r/w;
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    unsigned char *buffer = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    UIGraphicsBeginImageContext(CGSizeMake(w, h));
    
    CGContextRef c = UIGraphicsGetCurrentContext();
    
    unsigned char* data = CGBitmapContextGetData(c);
    if (data != NULL) {
        unsigned long maxY = h;
        for(int y = 0; y<maxY; y++) {
            for(int x = 0; x<w; x++) {
                unsigned long offset = bytesPerPixel*((w*y)+x);
                data[offset] = buffer[offset];     // R
                data[offset+1] = buffer[offset+1]; // G
                data[offset+2] = buffer[offset+2]; // B
                data[offset+3] = buffer[offset+3]; // A
            }
        }
    }
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return img;
}
// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    /*
    if (height != width) {
        height = width; //make it square --hejun.lhj
    }
     */
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    //    UIImage *newImage = [image imageByScalingAndCroppingForSize:CGSizeMake(640, 640)];
    // Release the Quartz image
    CGImageRelease(quartzImage);
    return image;
}

@end
