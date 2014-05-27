//
//  AKVideoCaputure.h
//  aikan
//
//  Created by lihejun on 14-2-24.
//  Copyright (c) 2014年 taobao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

// akCamera types
typedef NS_ENUM(NSInteger, AKCameraDevice) {
    AKCameraDeviceBack = UIImagePickerControllerCameraDeviceRear,
    AKCameraDeviceFront = UIImagePickerControllerCameraDeviceFront
};

typedef NS_ENUM(NSInteger, AKCameraMode) {
    AKCameraModePhoto = UIImagePickerControllerCameraCaptureModePhoto,
    AKCameraModeVideo = UIImagePickerControllerCameraCaptureModeVideo
};

typedef NS_ENUM(NSInteger, AKCameraOrientation) {
    AKCameraOrientationPortrait = AVCaptureVideoOrientationPortrait,
    AKCameraOrientationPortraitUpsideDown = AVCaptureVideoOrientationPortraitUpsideDown,
    AKCameraOrientationLandscapeRight = AVCaptureVideoOrientationLandscapeRight,
    AKCameraOrientationLandscapeLeft = AVCaptureVideoOrientationLandscapeLeft,
};

typedef NS_ENUM(NSInteger, AKFocusMode) {
    AKFocusModeLocked = AVCaptureFocusModeLocked,
    AKFocusModeAutoFocus = AVCaptureFocusModeAutoFocus,
    AKFocusModeContinuousAutoFocus = AVCaptureFocusModeContinuousAutoFocus
};

typedef NS_ENUM(NSInteger, AKFlashMode) {
    AKFlashModeOff  = AVCaptureFlashModeOff,
    AKFlashModeOn   = AVCaptureFlashModeOn,
    AKFlashModeAuto = AVCaptureFlashModeAuto
};

// photo dictionary keys
extern NSString * const AKCameraPhotoMetadataKey;
extern NSString * const AKCameraPhotoJPEGKey;
extern NSString * const AKCameraPhotoImageKey;
extern NSString * const AKCameraPhotoThumbnailKey; // 160x120

// video dictionary keys
extern NSString * const AKCameraVideoPathKey;
extern NSString * const AKCameraVideoCompotionKey;
extern NSString * const AKCameraVideoThumbnailKey;

@class EAGLContext;

@protocol AKCameraCaputureDelegate;
@class AKCameraExporter;
@interface AKCameraCaputure : NSObject
// delegate
@property (nonatomic, weak) id<AKCameraCaputureDelegate> delegate;
// exporter
@property (nonatomic, weak) AKCameraExporter *exporter;
// session
@property (nonatomic, readonly, getter=isCaptureSessionActive) BOOL captureSessionActive;
// setup
@property (nonatomic) AKCameraOrientation cameraOrientation;
@property (nonatomic) AKCameraDevice cameraDevice;
@property (nonatomic) AKCameraMode cameraMode;
@property (nonatomic) AKFocusMode focusMode;
@property (nonatomic) AKFlashMode flashMode;
@property (nonatomic) BOOL captureAsYUV;
@property (nonatomic, readonly, getter=isFlashAvailable) BOOL flashAvailable;
// video output settings
@property (nonatomic, strong) NSString *captureSessionPreset;
// preview
@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, readonly) CGRect cleanAperture;
// photo
@property (nonatomic, readonly) BOOL canCapturePhoto;
@property (nonatomic) BOOL thumbnailEnabled; // thumbnail generation, disabling reduces processing time for an photo
// video
@property (nonatomic, readonly) BOOL supportsVideoCapture;
@property (nonatomic, readonly) BOOL canCaptureVideo;
@property (nonatomic, getter=isVideoRenderingEnabled) BOOL videoRenderingEnabled;
@property (nonatomic, readonly) EAGLContext *context;

+ (AKCameraCaputure *)sharedInstance;
// check camera available
- (BOOL)isCameraDeviceAvailable:(AKCameraDevice)cameraDevice;
// preview
- (void)startPreview;
- (void)stopPreview;
- (void)unfreezePreview; // preview is automatically timed and frozen with photo capture
// focus
- (void)focusAtAdjustedPoint:(CGPoint)adjustedPoint;
// photo
- (void)capturePhoto;
// video
- (void)startVideoCapture;
- (void)pauseVideoCapture;
- (void)resumeVideoCapture;
- (void)endVideoCapture;
- (void)cancelVideoCapture;
@end

@protocol AKCameraCaputureDelegate <NSObject>
@optional

- (void)akCameraSessionWillStart:(AKCameraCaputure *)akCamera;
- (void)akCameraSessionDidStart:(AKCameraCaputure *)akCamera;
- (void)akCameraSessionDidStop:(AKCameraCaputure *)akCamera;

- (void)akCameraModeWillChange:(AKCameraCaputure *)akCamera;
- (void)akCameraModeDidChange:(AKCameraCaputure *)akCamera;

- (void)akCamera:(AKCameraCaputure *)akCamera didChangeCleanAperture:(CGRect)cleanAperture;

- (void)akCameraWillStartFocus:(AKCameraCaputure *)akCamera;
- (void)akCameraDidStopFocus:(AKCameraCaputure *)akCamera;

- (void)akCameraDidChangeFlashAvailablility:(AKCameraCaputure *)akCamera; // flash and torch

// preview
- (void)akCameraSessionDidStartPreview:(AKCameraCaputure *)akCamera;
- (void)akCameraSessionDidStopPreview:(AKCameraCaputure *)akCamera;

// photo
- (void)akCameraWillCapturePhoto:(AKCameraCaputure *)akCamera;
- (void)akCameraDidCapturePhoto:(AKCameraCaputure *)akCamera;
- (void)akCamera:(AKCameraCaputure *)akCamera capturedPhoto:(NSDictionary *)photoDict error:(NSError *)error;
@end
