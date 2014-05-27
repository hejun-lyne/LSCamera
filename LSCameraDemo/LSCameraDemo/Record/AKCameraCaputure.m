//
//  AKVideoCaputure.m
//  aikan
//
//  Created by lihejun on 14-2-24.
//  Copyright (c) 2014年 taobao. All rights reserved.
//

#import "AKCameraCaputure.h"
#import <ImageIO/ImageIO.h>
#import <OpenGLES/EAGL.h>
#import "AKCameraExporter.h"
#import "AKCameraUtils.h"

static uint64_t const AKCameraRequiredMinimumDiskSpaceInBytes = 49999872; // ~ 47 MB
static CGFloat const AKCameraThumbnailWidth = 160.0f;

// KVO contexts

static NSString * const AKCameraFocusObserverContext = @"AKCameraFocusObserverContext";
static NSString * const AKCameraFlashAvailabilityObserverContext = @"AKCameraFlashAvailabilityObserverContext";
static NSString * const AKCameraTorchAvailabilityObserverContext = @"AKCameraTorchAvailabilityObserverContext";
static NSString * const AKCameraCaptureStillImageIsCapturingStillImageObserverContext = @"AKCameraCaptureStillImageIsCapturingStillImageObserverContext";

static uint64_t const AKAVCaptureRequiredMinimumDiskSpaceInBytes = 49999872; // ~ 47 MB

// photo dictionary key definitions

NSString * const AKCameraPhotoMetadataKey = @"AKCameraPhotoMetadataKey";
NSString * const AKCameraPhotoJPEGKey = @"AKCameraPhotoJPEGKey";
NSString * const AKCameraPhotoImageKey = @"AKCameraPhotoImageKey";
NSString * const AKCameraPhotoThumbnailKey = @"AKCameraPhotoThumbnailKey";

// video dictionary key definitions
NSString * const AKCameraVideoCompotionKey = @"AKCameraVideoCompotionKey";
NSString * const AKCameraVideoPathKey = @"AKCameraVideoPathKey";
NSString * const AKCameraVideoThumbnailKey = @"AKCameraVideoThumbnailKey";

@interface AKCameraCaputure () <
AVCaptureAudioDataOutputSampleBufferDelegate,
AVCaptureVideoDataOutputSampleBufferDelegate>
{
    // AV
    AVCaptureSession *_captureSession;
    
    AVCaptureDevice *_captureDeviceFront;
    AVCaptureDevice *_captureDeviceBack;
    AVCaptureDevice *_captureDeviceAudio;
    
    AVCaptureDeviceInput *_captureDeviceInputFront;
    AVCaptureDeviceInput *_captureDeviceInputBack;
    AVCaptureDeviceInput *_captureDeviceInputAudio;
    
    AVCaptureStillImageOutput *_captureOutputPhoto;
    AVCaptureAudioDataOutput *_captureOutputAudio;
    AVCaptureVideoDataOutput *_captureOutputVideo;
    
    // vision core
    dispatch_queue_t _captureSessionDispatchQueue;
    dispatch_queue_t _captureVideoDispatchQueue;
    
    AKCameraDevice _cameraDevice;
    AKCameraMode _cameraMode;
    AKCameraOrientation _cameraOrientation;
    
    AKFocusMode _focusMode;
    AKFlashMode _flashMode;
    
    NSString *_captureSessionPreset;
    
    AVCaptureDevice *_currentDevice;
    AVCaptureDeviceInput *_currentInput;
    AVCaptureOutput *_currentOutput;
    
    AVCaptureVideoPreviewLayer *_previewLayer;
    CGRect _cleanAperture;
    
    // flags
    struct {
        unsigned int previewRunning:1;
        unsigned int changingModes:1;
        unsigned int recording:1;
        unsigned int paused:1;
        unsigned int interrupted:1;
        unsigned int videoWritten:1;
        unsigned int videoRenderingEnabled:1;
        unsigned int thumbnailEnabled:1;
    } __block _flags;
}
@end
@implementation AKCameraCaputure
@synthesize delegate = _delegate;
@synthesize previewLayer = _previewLayer;
@synthesize cleanAperture = _cleanAperture;
@synthesize cameraOrientation = _cameraOrientation;
@synthesize cameraDevice = _cameraDevice;
@synthesize cameraMode = _cameraMode;
@synthesize focusMode = _focusMode;
@synthesize flashMode = _flashMode;
@synthesize context = _context;
@synthesize captureSessionPreset = _captureSessionPreset;

#pragma mark - singleton
+ (AKCameraCaputure *)sharedInstance
{
    static AKCameraCaputure *singleton = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
        singleton = [[AKCameraCaputure alloc] init];
    });
    return singleton;
}

#pragma mark - lifecycle
#pragma mark - init

- (id)init
{
    self = [super init];
    if (self) {
        _captureSessionPreset = AVCaptureSessionPresetMedium; // 默认为AVCaptureSessionPresetHigh
        
        // setup queues
        _captureSessionDispatchQueue = dispatch_queue_create("com.taobao.taobaohuyan.captureSessionDispatchQueue", DISPATCH_QUEUE_SERIAL); // protects session
        _captureVideoDispatchQueue = dispatch_queue_create("com.taobao.taobaohuyan.captureVideoDispatchQueue", DISPATCH_QUEUE_SERIAL); // protects capture
        
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillEnterForeground:) name:@"UIApplicationWillEnterForegroundNotification" object:[UIApplication sharedApplication]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationDidEnterBackground:) name:@"UIApplicationDidEnterBackgroundNotification" object:[UIApplication sharedApplication]];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _delegate = nil;
    [self _destroyCamera];
}

#pragma mark - App NSNotifications
- (void)_applicationWillEnterForeground:(NSNotification *)notification
{
    ////DLog(@"AKCameraCapture applicationWillEnterForeground");
    [self _enqueueBlockInCaptureSessionQueue:^{
        if (!_flags.previewRunning)
            return;
        
        [self _enqueueBlockOnMainQueue:^{
            [self startPreview];
        }];
    }];
}

- (void)_applicationDidEnterBackground:(NSNotification *)notification
{
    //DLog(@"AKCameraCapture applicationDidEnterBackground");
    
    if (_flags.previewRunning) {
        [self stopPreview];
        [self _enqueueBlockInCaptureSessionQueue:^{
            _flags.previewRunning = YES;
        }];
    }
}

#pragma mark - queue helper methods

typedef void (^AKCameraCaptureBlock)();

- (void)_enqueueBlockInCaptureSessionQueue:(AKCameraCaptureBlock)block {
    dispatch_async(_captureSessionDispatchQueue, ^{
        block();
    });
}

- (void)_enqueueBlockInCaptureVideoQueue:(AKCameraCaptureBlock)block {
    dispatch_async(_captureVideoDispatchQueue, ^{
        block();
    });
}

- (void)_enqueueBlockOnMainQueue:(AKCameraCaptureBlock)block {
    dispatch_async(dispatch_get_main_queue(), ^{
        block();
    });
}

- (void)_executeBlockOnMainQueue:(AKCameraCaptureBlock)block {
    dispatch_sync(dispatch_get_main_queue(), ^{
        block();
    });
}

#pragma mark - camera

- (void)_setupCamera
{
    if (_captureSession)
        return;
    
    _captureSession = [[AVCaptureSession alloc] init];
    
    _captureDeviceFront = [AKCameraUtils captureDeviceForPosition:AVCaptureDevicePositionFront];
    _captureDeviceBack = [AKCameraUtils captureDeviceForPosition:AVCaptureDevicePositionBack];
    
    NSError *error = nil;
    _captureDeviceInputFront = [AVCaptureDeviceInput deviceInputWithDevice:_captureDeviceFront error:&error];
    if (error) {
        //DLog(@"error setting up front camera input (%@)", error);
        error = nil;
    }
    
    _captureDeviceInputBack = [AVCaptureDeviceInput deviceInputWithDevice:_captureDeviceBack error:&error];
    if (error) {
        //DLog(@"error setting up back camera input (%@)", error);
        error = nil;
    }
    
    if (self.cameraMode != AKCameraModePhoto)
        _captureDeviceAudio = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    _captureDeviceInputAudio = [AVCaptureDeviceInput deviceInputWithDevice:_captureDeviceAudio error:&error];
    if (error) {
        //DLog(@"error setting up audio input (%@)", error);
    }
    
    _captureOutputPhoto = [[AVCaptureStillImageOutput alloc] init];
    if (self.cameraMode != AKCameraModePhoto)
    	_captureOutputAudio = [[AVCaptureAudioDataOutput alloc] init];
    _captureOutputVideo = [[AVCaptureVideoDataOutput alloc] init];
    
    if (self.cameraMode != AKCameraModePhoto)
    	[_captureOutputAudio setSampleBufferDelegate:self queue:_captureVideoDispatchQueue];
    [_captureOutputVideo setSampleBufferDelegate:self queue:_captureVideoDispatchQueue];
    
    // add notification observers
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    // session notifications
    [notificationCenter addObserver:self selector:@selector(_sessionRuntimeErrored:) name:AVCaptureSessionRuntimeErrorNotification object:_captureSession];
    [notificationCenter addObserver:self selector:@selector(_sessionStarted:) name:AVCaptureSessionDidStartRunningNotification object:_captureSession];
    [notificationCenter addObserver:self selector:@selector(_sessionStopped:) name:AVCaptureSessionDidStopRunningNotification object:_captureSession];
    [notificationCenter addObserver:self selector:@selector(_sessionWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:_captureSession];
    [notificationCenter addObserver:self selector:@selector(_sessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:_captureSession];
    
    // capture input notifications
    [notificationCenter addObserver:self selector:@selector(_inputPortFormatDescriptionDidChange:) name:AVCaptureInputPortFormatDescriptionDidChangeNotification object:nil];
    
    // capture device notifications
    [notificationCenter addObserver:self selector:@selector(_deviceSubjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:nil];
    
    // KVO is only used to monitor focus and capture events
    [_captureOutputPhoto addObserver:self forKeyPath:@"capturingStillImage" options:NSKeyValueObservingOptionNew context:(__bridge void *)(AKCameraCaptureStillImageIsCapturingStillImageObserverContext)];
    
    //DLog(@"camera setup");
}

- (void)_destroyCamera
{
    if (!_captureSession)
        return;
    
    // remove notification observers (we don't want to just 'remove all' because we're also observing background notifications
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    // session notifications
    [notificationCenter removeObserver:self name:AVCaptureSessionRuntimeErrorNotification object:_captureSession];
    [notificationCenter removeObserver:self name:AVCaptureSessionDidStartRunningNotification object:_captureSession];
    [notificationCenter removeObserver:self name:AVCaptureSessionDidStopRunningNotification object:_captureSession];
    [notificationCenter removeObserver:self name:AVCaptureSessionWasInterruptedNotification object:_captureSession];
    [notificationCenter removeObserver:self name:AVCaptureSessionInterruptionEndedNotification object:_captureSession];
    
    // capture input notifications
    [notificationCenter removeObserver:self name:AVCaptureInputPortFormatDescriptionDidChangeNotification object:nil];
    
    // capture device notifications
    [notificationCenter removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:nil];
    
    // only KVO use
    [_captureOutputPhoto removeObserver:self forKeyPath:@"capturingStillImage"];
    [_currentDevice removeObserver:self forKeyPath:@"adjustingFocus"];
    
    _captureOutputPhoto = nil;
    _captureOutputAudio = nil;
    _captureOutputVideo = nil;
    
    _captureDeviceAudio = nil;
    _captureDeviceInputAudio = nil;
    
    _captureDeviceInputFront = nil;
    _captureDeviceInputBack = nil;
    
    _captureDeviceFront = nil;
    _captureDeviceBack = nil;
    
    _captureSession = nil;
    
    _currentDevice = nil;
    _currentInput = nil;
    _currentOutput = nil;
    
    //DLog(@"camera destroyed");
}

- (AVCaptureConnection *)videoCaptureConnection {
    for (AVCaptureConnection *connection in [_captureOutputVideo connections] ) {
		for ( AVCaptureInputPort *port in [connection inputPorts] ) {
			if ( [[port mediaType] isEqual:AVMediaTypeVideo] ) {
				return connection;
			}
		}
	}
    
    return nil;
}

#pragma mark - AVCaptureSession

- (BOOL)_canSessionCaptureWithOutput:(AVCaptureOutput *)captureOutput
{
    BOOL sessionContainsOutput = [[_captureSession outputs] containsObject:captureOutput];
    BOOL outputHasConnection = ([captureOutput connectionWithMediaType:AVMediaTypeVideo] != nil);
    return (sessionContainsOutput && outputHasConnection);
}

- (void)_setupSession
{
    if (!_captureSession) {
        //DLog(@"error, no session running to setup");
        return;
    }
    
    BOOL shouldSwitchDevice = (_currentDevice == nil) ||
    ((_currentDevice == _captureDeviceFront) && (_cameraDevice != AKCameraDeviceFront)) ||
    ((_currentDevice == _captureDeviceBack) && (_cameraDevice != AKCameraDeviceBack));
    
    BOOL shouldSwitchMode = (_currentOutput == nil) ||
    ((_currentOutput == _captureOutputPhoto) && (_cameraMode != AKCameraModePhoto)) ||
    ((_currentOutput == _captureOutputVideo) && (_cameraMode != AKCameraModeVideo));
    
    //DLog(@"switchDevice %d switchMode %d", shouldSwitchDevice, shouldSwitchMode);
    
    if (!shouldSwitchDevice && !shouldSwitchMode)
        return;
    
    AVCaptureDeviceInput *newDeviceInput = nil;
    AVCaptureOutput *newCaptureOutput = nil;
    AVCaptureDevice *newCaptureDevice = nil;
    
    [_captureSession beginConfiguration];
    
    // setup session device
    if (shouldSwitchDevice) {
        switch (_cameraDevice) {
            case AKCameraDeviceFront:
            {
                [_captureSession removeInput:_captureDeviceInputBack];
                if ([_captureSession canAddInput:_captureDeviceInputFront]) {
                    [_captureSession addInput:_captureDeviceInputFront];
                    newDeviceInput = _captureDeviceInputFront;
                    newCaptureDevice = _captureDeviceFront;
                }
                break;
            }
            case AKCameraDeviceBack:
            {
                [_captureSession removeInput:_captureDeviceInputFront];
                if ([_captureSession canAddInput:_captureDeviceInputBack]) {
                    [_captureSession addInput:_captureDeviceInputBack];
                    newDeviceInput = _captureDeviceInputBack;
                    newCaptureDevice = _captureDeviceBack;
                }
                break;
            }
            default:
                break;
        }
        
    } // shouldSwitchDevice
    
    // setup session input/output
    if (shouldSwitchMode) {
        // disable audio when in use for photos, otherwise enable it
    	if (self.cameraMode == AKCameraModePhoto) {
            
        	[_captureSession removeInput:_captureDeviceInputAudio];
        	[_captureSession removeOutput:_captureOutputAudio];
            
        } else if (!_captureDeviceAudio && !_captureDeviceInputAudio && !_captureOutputAudio) {
            
            NSError *error = nil;
            _captureDeviceAudio = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
            _captureDeviceInputAudio = [AVCaptureDeviceInput deviceInputWithDevice:_captureDeviceAudio error:&error];
            if (error) {
                //DLog(@"error setting up audio input (%@)", error);
            }
            
            _captureOutputAudio = [[AVCaptureAudioDataOutput alloc] init];
            [_captureOutputAudio setSampleBufferDelegate:self queue:_captureVideoDispatchQueue];
            
        }
        
        [_captureSession removeOutput:_captureOutputVideo];
        [_captureSession removeOutput:_captureOutputPhoto];
        
        switch (_cameraMode) {
            case AKCameraModeVideo:
            {
                // audio input
                if ([_captureSession canAddInput:_captureDeviceInputAudio]) {
                    [_captureSession addInput:_captureDeviceInputAudio];
                }
                // audio output
                if ([_captureSession canAddOutput:_captureOutputAudio]) {
                    [_captureSession addOutput:_captureOutputAudio];
                }
                // vidja output
                if ([_captureSession canAddOutput:_captureOutputVideo]) {
                    [_captureSession addOutput:_captureOutputVideo];
                    newCaptureOutput = _captureOutputVideo;
                }
                break;
            }
            case AKCameraModePhoto:
            {
                // photo output
                if ([_captureSession canAddOutput:_captureOutputPhoto]) {
                    [_captureSession addOutput:_captureOutputPhoto];
                    newCaptureOutput = _captureOutputPhoto;
                }
                break;
            }
            default:
                break;
        }
        
    } // shouldSwitchMode
    
    if (!newCaptureDevice)
        newCaptureDevice = _currentDevice;
    
    if (!newCaptureOutput)
        newCaptureOutput = _currentOutput;
    
    // setup video connection
    AVCaptureConnection *videoConnection = [_captureOutputVideo connectionWithMediaType:AVMediaTypeVideo];
    
    // setup input/output
    
    NSString *sessionPreset = _captureSessionPreset;
    
    if (newCaptureOutput && newCaptureOutput == _captureOutputVideo && videoConnection) {
        
        // setup video orientation
        [self _setOrientationForConnection:videoConnection];
        
        // setup video stabilization, if available
        if ([videoConnection isVideoStabilizationSupported])
            [videoConnection setEnablesVideoStabilizationWhenAvailable:YES];
        
        // discard late frames
        [_captureOutputVideo setAlwaysDiscardsLateVideoFrames:NO];
        
        // specify video preset
        sessionPreset = _captureSessionPreset;
        
        // setup video settings
        // kCVPixelFormatType_420YpCbCr8BiPlanarFullRange Bi-Planar Component Y'CbCr 8-bit 4:2:0, full-range (luma=[0,255] chroma=[1,255])
        // baseAddr points to a big-endian CVPlanarPixelBufferInfo_YCbCrBiPlanar struct
        NSDictionary *videoSettings = nil;
        if (_captureAsYUV) {
            BOOL supportsFullRangeYUV = NO;
            BOOL supportsVideoRangeYUV = NO;
            NSArray *supportedPixelFormats = _captureOutputVideo.availableVideoCVPixelFormatTypes;
            for (NSNumber *currentPixelFormat in supportedPixelFormats) {
                if ([currentPixelFormat intValue] == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
                    supportsFullRangeYUV = YES;
                }
                if ([currentPixelFormat intValue] == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
                    supportsVideoRangeYUV = YES;
                }
            }
            
            if (supportsFullRangeYUV) {
                videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) };
            } else if (supportsVideoRangeYUV) {
                videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) };
            }
        } else {
            videoSettings = videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
        }
        
        
        if (videoSettings)
            [_captureOutputVideo setVideoSettings:videoSettings];
        
        // setup video device configuration
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1) {
            
            NSError *error = nil;
            if ([newCaptureDevice lockForConfiguration:&error]) {
                
                // smooth autofocus for videos
                if ([newCaptureDevice isSmoothAutoFocusSupported])
                    [newCaptureDevice setSmoothAutoFocusEnabled:YES];
                
                // setup framerate range
                // TODO: seek best framerate range for slow-motion recording
                CMTime frameDuration = CMTimeMake( 1, 30 );
                newCaptureDevice.activeVideoMinFrameDuration = frameDuration;
                newCaptureDevice.activeVideoMaxFrameDuration = frameDuration;
                
                [newCaptureDevice unlockForConfiguration];
                
            } else if (error) {
                //DLog(@"error locking device for video device configuration (%@)", error);
            }
            
        } else {
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            // setup framerate
            CMTime frameDuration = CMTimeMake( 1, 30 );
            if ( videoConnection.supportsVideoMinFrameDuration )
                videoConnection.videoMinFrameDuration = frameDuration;
            if ( videoConnection.supportsVideoMaxFrameDuration )
                videoConnection.videoMaxFrameDuration = frameDuration;
#pragma clang diagnostic pop
            
        }
        
    } else if (newCaptureOutput && newCaptureOutput == _captureOutputPhoto) {
        
        // specify photo preset
        sessionPreset = AVCaptureSessionPresetPhoto;
        
        // setup photo settings
        NSDictionary *photoSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                       AVVideoCodecJPEG, AVVideoCodecKey,
                                       nil];
        [_captureOutputPhoto setOutputSettings:photoSettings];
        
        // setup photo device configuration
        NSError *error = nil;
        if ([newCaptureDevice lockForConfiguration:&error]) {
            
            if ([newCaptureDevice isLowLightBoostSupported])
                [newCaptureDevice setAutomaticallyEnablesLowLightBoostWhenAvailable:YES];
            
            [newCaptureDevice unlockForConfiguration];
            
        } else if (error) {
            //DLog(@"error locking device for photo device configuration (%@)", error);
        }
        
    }
    
    // apply presets
    if ([_captureSession canSetSessionPreset:sessionPreset])
        [_captureSession setSessionPreset:sessionPreset];
    
    // KVO
    if (newCaptureDevice) {
        [_currentDevice removeObserver:self forKeyPath:@"adjustingFocus"];
        [_currentDevice removeObserver:self forKeyPath:@"flashAvailable"];
        [_currentDevice removeObserver:self forKeyPath:@"torchAvailable"];
        
        _currentDevice = newCaptureDevice;
        [_currentDevice addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:(__bridge void *)AKCameraFocusObserverContext];
        [_currentDevice addObserver:self forKeyPath:@"flashAvailable" options:NSKeyValueObservingOptionNew context:(__bridge void *)AKCameraFlashAvailabilityObserverContext];
        [_currentDevice addObserver:self forKeyPath:@"torchAvailable" options:NSKeyValueObservingOptionNew context:(__bridge void *)AKCameraTorchAvailabilityObserverContext];
    }
    
    if (newDeviceInput)
        _currentInput = newDeviceInput;
    
    if (newCaptureOutput)
        _currentOutput = newCaptureOutput;
    
    [_captureSession commitConfiguration];
    
    //DLog(@"capture session setup");
}

#pragma mark - preview

- (void)startPreview
{
    [self _enqueueBlockInCaptureSessionQueue:^{
        if (!_captureSession) {
            [self _setupCamera];
            [self _setupSession];
        }
        
        if (_previewLayer && _previewLayer.session != _captureSession) {
            _previewLayer.session = _captureSession;
            [self _setOrientationForConnection:_previewLayer.connection];
        }
        
        if (![_captureSession isRunning]) {
            [_captureSession startRunning];
            
            [self _enqueueBlockOnMainQueue:^{
                if ([_delegate respondsToSelector:@selector(akCameraSessionDidStartPreview:)]) {
                    [_delegate akCameraSessionDidStartPreview:self];
                }
            }];
            //DLog(@"capture session running");
        }
        _flags.previewRunning = YES;
    }];
}

- (void)stopPreview
{
    [self _enqueueBlockInCaptureSessionQueue:^{
        if (!_flags.previewRunning)
            return;
        
        if (_previewLayer)
            _previewLayer.connection.enabled = YES;
        
        [_captureSession stopRunning];
        
        [self _executeBlockOnMainQueue:^{
            if ([_delegate respondsToSelector:@selector(akCameraSessionDidStopPreview:)]) {
                [_delegate akCameraSessionDidStopPreview:self];
            }
        }];
        //DLog(@"capture session stopped");
        _flags.previewRunning = NO;
    }];
}

- (void)unfreezePreview
{
    if (_previewLayer)
        _previewLayer.connection.enabled = YES;
}

#pragma mark - focus, exposure, white balance
- (void)_focusStarted
{
    //    //DLog(@"focus started");
    if ([_delegate respondsToSelector:@selector(akCameraWillStartFocus:)])
        [_delegate akCameraWillStartFocus:self];
}

- (void)_focusEnded
{
    if ([_delegate respondsToSelector:@selector(akCameraDidStopFocus:)])
        [_delegate akCameraDidStopFocus:self];
    //    //DLog(@"focus ended");
}

- (void)_focus
{
    if ([_currentDevice isAdjustingFocus] || [_currentDevice isAdjustingExposure])
        return;
    
    // only notify clients when focus is triggered from an event
    if ([_delegate respondsToSelector:@selector(akCameraWillStartFocus:)])
        [_delegate akCameraWillStartFocus:self];
    
    CGPoint focusPoint = CGPointMake(0.5f, 0.5f);
    [self focusAtAdjustedPoint:focusPoint];
}

// TODO: should add in exposure and white balance locks for completeness one day
- (void)_setFocusLocked:(BOOL)focusLocked
{
    NSError *error = nil;
    if (_currentDevice && [_currentDevice lockForConfiguration:&error]) {
        
        if (focusLocked && [_currentDevice isFocusModeSupported:AVCaptureFocusModeLocked]) {
            [_currentDevice setFocusMode:AVCaptureFocusModeLocked];
        } else if ([_currentDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            [_currentDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        
        [_currentDevice setSubjectAreaChangeMonitoringEnabled:focusLocked];
        
        [_currentDevice unlockForConfiguration];
        
    } else if (error) {
        //DLog(@"error locking device for focus adjustment (%@)", error);
    }
}

- (void)focusAtAdjustedPoint:(CGPoint)adjustedPoint
{
    if ([_currentDevice isAdjustingFocus] || [_currentDevice isAdjustingExposure])
        return;
    
    NSError *error = nil;
    if ([_currentDevice lockForConfiguration:&error]) {
        
        BOOL isFocusAtPointSupported = [_currentDevice isFocusPointOfInterestSupported];
        BOOL isExposureAtPointSupported = [_currentDevice isExposurePointOfInterestSupported];
        BOOL isWhiteBalanceModeSupported = [_currentDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
        
        if (isFocusAtPointSupported && [_currentDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            [_currentDevice setFocusPointOfInterest:adjustedPoint];
            [_currentDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        
        if (isExposureAtPointSupported && [_currentDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            [_currentDevice setExposurePointOfInterest:adjustedPoint];
            [_currentDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        }
        
        if (isWhiteBalanceModeSupported) {
            [_currentDevice setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
        }
        
        [_currentDevice unlockForConfiguration];
        
    } else if (error) {
        //DLog(@"error locking device for focus adjustment (%@)", error);
    }
}

#pragma mark - photo

- (BOOL)canCapturePhoto
{
    BOOL isDiskSpaceAvailable = [AKCameraUtils availableDiskSpaceInBytes] > AKCameraRequiredMinimumDiskSpaceInBytes;
    return [self isCaptureSessionActive] && !_flags.changingModes && isDiskSpaceAvailable;
}

- (UIImage *)_uiimageFromJPEGData:(NSData *)jpegData
{
    CGImageRef jpegCGImage = NULL;
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)jpegData);
    
    UIImageOrientation imageOrientation = UIImageOrientationUp;
    
    if (provider) {
        CGImageSourceRef imageSource = CGImageSourceCreateWithDataProvider(provider, NULL);
        if (imageSource) {
            if (CGImageSourceGetCount(imageSource) > 0) {
                jpegCGImage = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
                
                // extract the cgImage properties
                CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
                if (properties) {
                    // set orientation
                    CFNumberRef orientationProperty = CFDictionaryGetValue(properties, kCGImagePropertyOrientation);
                    if (orientationProperty) {
                        NSInteger exifOrientation = 1;
                        CFNumberGetValue(orientationProperty, kCFNumberIntType, &exifOrientation);
                        imageOrientation = [self _imageOrientationFromExifOrientation:exifOrientation];
                    }
                    
                    CFRelease(properties);
                }
                
            }
            CFRelease(imageSource);
        }
        CGDataProviderRelease(provider);
    }
    
    UIImage *image = nil;
    if (jpegCGImage) {
        image = [[UIImage alloc] initWithCGImage:jpegCGImage scale:1.0 orientation:imageOrientation];
        CGImageRelease(jpegCGImage);
    }
    return image;
}

- (UIImage *)_thumbnailJPEGData:(NSData *)jpegData
{
    CGImageRef thumbnailCGImage = NULL;
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)jpegData);
    
    if (provider) {
        CGImageSourceRef imageSource = CGImageSourceCreateWithDataProvider(provider, NULL);
        if (imageSource) {
            if (CGImageSourceGetCount(imageSource) > 0) {
                NSMutableDictionary *options = [[NSMutableDictionary alloc] initWithCapacity:3];
                [options setObject:@(YES) forKey:(id)kCGImageSourceCreateThumbnailFromImageAlways];
                [options setObject:@(AKCameraThumbnailWidth) forKey:(id)kCGImageSourceThumbnailMaxPixelSize];
                [options setObject:@(YES) forKey:(id)kCGImageSourceCreateThumbnailWithTransform];
                thumbnailCGImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (__bridge CFDictionaryRef)options);
            }
            CFRelease(imageSource);
        }
        CGDataProviderRelease(provider);
    }
    
    UIImage *thumbnail = nil;
    if (thumbnailCGImage) {
        thumbnail = [[UIImage alloc] initWithCGImage:thumbnailCGImage];
        CGImageRelease(thumbnailCGImage);
    }
    return thumbnail;
}


- (UIImageOrientation)_imageOrientationFromExifOrientation:(NSInteger)exifOrientation
{
    UIImageOrientation imageOrientation = UIImageOrientationUp;
    
    switch (exifOrientation) {
        case 1:
            imageOrientation = UIImageOrientationUp;
            break;
        case 2:
            imageOrientation = UIImageOrientationUpMirrored;
            break;
        case 3:
            imageOrientation = UIImageOrientationDown;
            break;
        case 4:
            imageOrientation = UIImageOrientationDownMirrored;
            break;
        case 5:
            imageOrientation = UIImageOrientationLeftMirrored;
            break;
        case 6:
            imageOrientation = UIImageOrientationRight;
            break;
        case 7:
            imageOrientation = UIImageOrientationRightMirrored;
            break;
        case 8:
            imageOrientation = UIImageOrientationLeft;
            break;
        default:
            break;
    }
    
    return imageOrientation;
}

- (void)_willCapturePhoto
{
    //DLog(@"will capture photo");
    if ([_delegate respondsToSelector:@selector(akCameraWillCapturePhoto:)])
        [_delegate akCameraWillCapturePhoto:self];
    
    // freeze preview
    _previewLayer.connection.enabled = NO;
}

- (void)_didCapturePhoto
{
    if ([_delegate respondsToSelector:@selector(akCameraDidCapturePhoto:)])
        [_delegate akCameraDidCapturePhoto:self];
    //DLog(@"did capture photo");
}

- (void)capturePhoto
{
    if (![self _canSessionCaptureWithOutput:_currentOutput] || _cameraMode != AKCameraModePhoto) {
        //DLog(@"session is not setup properly for capture");
        return;
    }
    
    AVCaptureConnection *connection = [_currentOutput connectionWithMediaType:AVMediaTypeVideo];
    [self _setOrientationForConnection:connection];
    
    [_captureOutputPhoto captureStillImageAsynchronouslyFromConnection:connection completionHandler:
     ^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
         
         if (!imageDataSampleBuffer) {
             //DLog(@"failed to obtain image data sample buffer");
             return;
         }
         
         if (error) {
             if ([_delegate respondsToSelector:@selector(akCamera:capturedPhoto:error:)]) {
                 [_delegate akCamera:self capturedPhoto:nil error:error];
             }
             return;
         }
         
         NSMutableDictionary *photoDict = [[NSMutableDictionary alloc] init];
         NSDictionary *metadata = nil;
         
         // add photo metadata (ie EXIF: Aperture, Brightness, Exposure, FocalLength, etc)
         metadata = (__bridge NSDictionary *)CMCopyDictionaryOfAttachments(kCFAllocatorDefault, imageDataSampleBuffer, kCMAttachmentMode_ShouldPropagate);
         if (metadata) {
             [photoDict setObject:metadata forKey:AKCameraPhotoMetadataKey];
             CFRelease((__bridge CFTypeRef)(metadata));
         } else {
             //DLog(@"failed to generate metadata for photo");
         }
         
         // add JPEG, UIImage, thumbnail
         NSData *jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
         if (jpegData) {
             // add JPEG
             [photoDict setObject:jpegData forKey:AKCameraPhotoJPEGKey];
             
             // add image
             UIImage *image = [self _uiimageFromJPEGData:jpegData];
             if (image) {
                 [photoDict setObject:image forKey:AKCameraPhotoImageKey];
             } else {
                 //DLog(@"failed to create image from JPEG");
                 // TODO: return delegate on error
             }
             
             // add thumbnail
             if (_flags.thumbnailEnabled) {
                 UIImage *thumbnail = [self _thumbnailJPEGData:jpegData];
                 if (thumbnail)
                     [photoDict setObject:thumbnail forKey:AKCameraPhotoThumbnailKey];
             }
             
         }
         
         if ([_delegate respondsToSelector:@selector(akCamera:capturedPhoto:error:)]) {
             [_delegate akCamera:self capturedPhoto:photoDict error:error];
         }
         
         // run a post shot focus
         [self performSelector:@selector(_focus) withObject:nil afterDelay:0.5f];
     }];
}

#pragma mark - video

- (BOOL)supportsVideoCapture
{
    return ([[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count] > 0);
}

- (BOOL)canCaptureVideo
{
    BOOL isDiskSpaceAvailable = [AKCameraUtils availableDiskSpaceInBytes] > AKCameraRequiredMinimumDiskSpaceInBytes;
    return [self supportsVideoCapture] && [self isCaptureSessionActive] && !_flags.changingModes && isDiskSpaceAvailable;
}

- (void)startVideoCapture
{
    if (![self _canSessionCaptureWithOutput:_currentOutput]) {
        //DLog(@"session is not setup properly for capture");
        return;
    }
    
    //DLog(@"starting video capture");
    [self _enqueueBlockInCaptureVideoQueue:^{
        AVCaptureConnection *videoConnection = [_captureOutputVideo connectionWithMediaType:AVMediaTypeVideo];
        [self _setOrientationForConnection:videoConnection];
        
        [_exporter startVideoCapture];
    }];
}

- (void)pauseVideoCapture
{
    [self _enqueueBlockInCaptureVideoQueue:^{
        [_exporter pauseVideoCapture];
    }];
}

- (void)resumeVideoCapture
{
    [self _enqueueBlockInCaptureVideoQueue:^{
        [_exporter resumeVideoCapture];
    }];
}

- (void)endVideoCapture
{
    //DLog(@"ending video capture");
    
    [self _enqueueBlockInCaptureVideoQueue:^{
        [_exporter endVideoCapture];
    }];
}

- (void)cancelVideoCapture
{
    [self _enqueueBlockInCaptureVideoQueue:^{
        [_exporter cancelVideoCapture];
    }];
}

#pragma mark - AV NSNotifications
// capture session
// TODO: add in a better error recovery
- (void)_sessionRuntimeErrored:(NSNotification *)notification
{
    [self _enqueueBlockOnMainQueue:^{
        if ([notification object] == _captureSession) {
            NSError *error = [[notification userInfo] objectForKey:AVCaptureSessionErrorKey];
            if (error) {
                NSInteger errorCode = [error code];
                switch (errorCode) {
                    case AVErrorMediaServicesWereReset:
                    {
                        //DLog(@"error media services were reset");
                        [self _destroyCamera];
                        if (_flags.previewRunning)
                            [self startPreview];
                        break;
                    }
                    case AVErrorDeviceIsNotAvailableInBackground:
                    {
                        //DLog(@"error media services not available in background");
                        break;
                    }
                    default:
                    {
                        //DLog(@"error media services failed, error (%@)", error);
                        [self _destroyCamera];
                        if (_flags.previewRunning)
                            [self startPreview];
                        break;
                    }
                }
            }
        }
    }];
}

- (void)_sessionStarted:(NSNotification *)notification
{
    [self _enqueueBlockOnMainQueue:^{
        if ([notification object] == _captureSession) {
            //DLog(@"session was started");
            
            // ensure there is a capture device setup
            if (_currentInput) {
                AVCaptureDevice *device = [_currentInput device];
                if (device) {
                    [_currentDevice removeObserver:self forKeyPath:@"adjustingFocus"];
                    [_currentDevice removeObserver:self forKeyPath:@"flashAvailable"];
                    [_currentDevice removeObserver:self forKeyPath:@"torchAvailable"];
                    
                    _currentDevice = device;
                    [_currentDevice addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:(__bridge void *)AKCameraFocusObserverContext];
                    [_currentDevice addObserver:self forKeyPath:@"flashAvailable" options:NSKeyValueObservingOptionNew context:(__bridge void *)AKCameraFlashAvailabilityObserverContext];
                    [_currentDevice addObserver:self forKeyPath:@"torchAvailable" options:NSKeyValueObservingOptionNew context:(__bridge void *)AKCameraTorchAvailabilityObserverContext];
                }
            }
            
            if ([_delegate respondsToSelector:@selector(akCameraSessionDidStart:)]) {
                [_delegate akCameraSessionDidStart:self];
            }
        }
    }];
}

- (void)_sessionStopped:(NSNotification *)notification
{
    [self _enqueueBlockInCaptureVideoQueue:^{
        //DLog(@"session was stopped");
        if (_flags.recording)
            [self endVideoCapture];
        
        [self _enqueueBlockOnMainQueue:^{
            if ([notification object] == _captureSession) {
                if ([_delegate respondsToSelector:@selector(akCameraSessionDidStop:)]) {
                    [_delegate akCameraSessionDidStop:self];
                }
            }
        }];
    }];
}

- (void)_sessionWasInterrupted:(NSNotification *)notification
{
    [self _enqueueBlockOnMainQueue:^{
        if ([notification object] == _captureSession) {
            //DLog(@"session was interrupted");
            // notify stop?
        }
    }];
}

- (void)_sessionInterruptionEnded:(NSNotification *)notification
{
    [self _enqueueBlockOnMainQueue:^{
        if ([notification object] == _captureSession) {
            //DLog(@"session interruption ended");
            // notify ended?
        }
    }];
}

// capture input

- (void)_inputPortFormatDescriptionDidChange:(NSNotification *)notification
{
    // when the input format changes, store the clean aperture
    // (clean aperture is the rect that represents the valid image data for this display)
    AVCaptureInputPort *inputPort = (AVCaptureInputPort *)[notification object];
    if (inputPort) {
        CMFormatDescriptionRef formatDescription = [inputPort formatDescription];
        if (formatDescription) {
            _cleanAperture = CMVideoFormatDescriptionGetCleanAperture(formatDescription, YES);
            if ([_delegate respondsToSelector:@selector(akCamera:didChangeCleanAperture:)]) {
                [_delegate akCamera:self didChangeCleanAperture:_cleanAperture];
            }
        }
    }
}

// capture device
- (void)_deviceSubjectAreaDidChange:(NSNotification *)notification
{
    [self _focus];
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ( context == (__bridge void *)AKCameraFocusObserverContext ) {
        
        BOOL isFocusing = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        if (isFocusing) {
            [self _focusStarted];
            //DLog(@"focus start");
        } else {
            [self _focusEnded];
            //DLog(@"focus end");
        }
        
    } else if ( context == (__bridge void *)AKCameraFlashAvailabilityObserverContext ||
               context == (__bridge void *)AKCameraTorchAvailabilityObserverContext ) {
        
        //        //DLog(@"flash/torch availability did change");
        if ([_delegate respondsToSelector:@selector(akCameraDidChangeFlashAvailablility:)])
            [_delegate akCameraDidChangeFlashAvailablility:self];
        
	} else if ( context == (__bridge void *)(AKCameraCaptureStillImageIsCapturingStillImageObserverContext) ) {
        
		BOOL isCapturingStillImage = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
		if ( isCapturingStillImage ) {
            [self _willCapturePhoto];
		} else {
            [self _didCapturePhoto];
        }
        
	} else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
	CFRetain(sampleBuffer);
    
    if (_exporter) {
        [self _enqueueBlockInCaptureVideoQueue:^(void){
            BOOL isAudio = (self.cameraMode != AKCameraModePhoto) && (connection == [_captureOutputAudio connectionWithMediaType:AVMediaTypeAudio]);
            BOOL isVideo = (connection == [_captureOutputVideo connectionWithMediaType:AVMediaTypeVideo]);
            [_exporter processSampleBuffer:sampleBuffer isAudio:isAudio isVideo:isVideo];
        }];
        
    }
}

#pragma mark - getters/setters

- (BOOL)isCaptureSessionActive
{
    return ([_captureSession isRunning]);
}

- (void)setCameraOrientation:(AKCameraOrientation)cameraOrientation
{
    if (cameraOrientation == _cameraOrientation)
        return;
    _cameraOrientation = cameraOrientation;
    
    if ([_previewLayer.connection isVideoOrientationSupported])
        [self _setOrientationForConnection:_previewLayer.connection];
}

- (void)_setOrientationForConnection:(AVCaptureConnection *)connection
{
    if (!connection || ![connection isVideoOrientationSupported])
        return;
    
    AVCaptureVideoOrientation orientation = AVCaptureVideoOrientationPortrait;
    switch (_cameraOrientation) {
        case AKCameraOrientationPortraitUpsideDown:
            orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case AKCameraOrientationLandscapeRight:
            orientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case AKCameraOrientationLandscapeLeft:
            orientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        default:
        case AKCameraOrientationPortrait:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
    }
    
    [connection setVideoOrientation:orientation];
}

- (void)_setCameraMode:(AKCameraMode)cameraMode cameraDevice:(AKCameraDevice)cameraDevice
{
    BOOL changeDevice = (_cameraDevice != cameraDevice);
    BOOL changeMode = (_cameraMode != cameraMode);
    //BOOL changeOutputFormat = (_outputFormat != outputFormat);
    
    ////DLog(@"change device (%d) mode (%d) format (%d)", changeDevice, changeMode, changeOutputFormat);
    
    if (!changeMode && !changeDevice /*&& !changeOutputFormat*/)
        return;
    
    if ([_delegate respondsToSelector:@selector(akCameraModeWillChange:)])
        [_delegate akCameraModeWillChange:self];
    
    _flags.changingModes = YES;
    
    _cameraDevice = cameraDevice;
    _cameraMode = cameraMode;
    
    //_outputFormat = outputFormat;
    
    // since there is no session in progress, set and bail
    if (!_captureSession) {
        _flags.changingModes = NO;
        
        if ([_delegate respondsToSelector:@selector(akCameraModeDidChange:)])
            [_delegate akCameraModeDidChange:self];
        
        return;
    }
    
    [self _enqueueBlockInCaptureSessionQueue:^{
        [self _setupSession];
        [self _enqueueBlockOnMainQueue:^{
            _flags.changingModes = NO;
            
            if ([_delegate respondsToSelector:@selector(akCameraModeDidChange:)])
                [_delegate akCameraModeDidChange:self];
        }];
    }];
}

- (void)setCameraDevice:(AKCameraDevice)cameraDevice
{
    [self _setCameraMode:_cameraMode cameraDevice:cameraDevice];
}

- (void)setCameraMode:(AKCameraMode)cameraMode
{
    [self _setCameraMode:cameraMode cameraDevice:_cameraDevice];
}



- (BOOL)isCameraDeviceAvailable:(AKCameraDevice)cameraDevice
{
    return [UIImagePickerController isCameraDeviceAvailable:(UIImagePickerControllerCameraDevice)cameraDevice];
}

- (void)setFlashMode:(AKFlashMode)flashMode
{
    BOOL shouldChangeFlashMode = (_flashMode != flashMode);
    if (![_currentDevice hasFlash] || !shouldChangeFlashMode)
        return;
    
    _flashMode = flashMode;
    
    NSError *error = nil;
    if (_currentDevice && [_currentDevice lockForConfiguration:&error]) {
        
        switch (_cameraMode) {
            case AKCameraModePhoto:
            {
                if ([_currentDevice isFlashModeSupported:(AVCaptureFlashMode)_flashMode]) {
                    [_currentDevice setFlashMode:(AVCaptureFlashMode)_flashMode];
                }
                break;
            }
            case AKCameraModeVideo:
            {
                if ([_currentDevice isFlashModeSupported:(AVCaptureFlashMode)_flashMode]) {
                    [_currentDevice setFlashMode:AVCaptureFlashModeOff];
                }
                
                if ([_currentDevice isTorchModeSupported:(AVCaptureTorchMode)_flashMode]) {
                    [_currentDevice setTorchMode:(AVCaptureTorchMode)_flashMode];
                }
                break;
            }
            default:
                break;
        }
        
        [_currentDevice unlockForConfiguration];
        
    } else if (error) {
        //DLog(@"error locking device for flash mode change (%@)", error);
    }
}

- (AKFlashMode)flashMode
{
    return _flashMode;
}

- (BOOL)isFlashAvailable
{
    return (_currentDevice && [_currentDevice hasFlash]);
}

@end
