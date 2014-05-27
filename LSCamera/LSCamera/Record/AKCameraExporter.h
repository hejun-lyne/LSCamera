//
//  AKVideoExporter.h
//  aikan
//
//  Created by lihejun on 14-2-24.
//  Copyright (c) 2014年 taobao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "AKCameraCaputure.h"

// output format
typedef NS_ENUM(NSInteger, AKOutputFormat) {
    AKOutputFormatPreset = 0,
    AKOutputFormatSquare,
    AKOutputFormatWidescreen
};

@protocol AKCameraExporterDelegate;

@interface AKCameraExporter : NSObject
// delegate
@property (nonatomic, weak) id<AKCameraExporterDelegate> delegate;
// video
// use pause/resume if a session is in progress, end finalizes that recording session
@property (nonatomic, readonly, getter=isRecording) BOOL recording;
@property (nonatomic, readonly, getter=isPaused) BOOL paused;
@property (nonatomic) CGRect presentationFrame;
@property (nonatomic, readonly) Float64 capturedAudioSeconds;
@property (nonatomic, readonly) Float64 capturedVideoSeconds;
@property (readwrite) int32_t maxFrames;
@property (readwrite) int32_t maxSeconds;
// compress setting
@property (nonatomic) AKOutputFormat outputFormat;
@property (nonatomic) CGFloat videoAssetBitRate;
@property (nonatomic) NSInteger audioAssetBitRate;
@property (nonatomic) NSInteger videoAssetFrameInterval;
// output
@property (nonatomic, readonly) NSURL *outputURL;
@property (nonatomic, readonly) NSError *error;

+ (AKCameraExporter *)shareInstance;
+ (void)deallocInstance;

// capture progress
- (void)startVideoCapture;
- (void)pauseVideoCapture;
- (void)resumeVideoCapture;
- (void)endVideoCapture;
- (void)cancelVideoCapture;

// restore from files
- (void)restoreFromMoviesWithProgress:(NSArray *)progresses;

- (AVComposition *)getComposition;
- (NSURL *)checkExportOutputURL;
- (Float64)getDuration;
- (CMTime)getSegementStartTime;
- (NSMutableArray *)keyFrames;

- (BOOL)canDeleteLastFragment;
- (void)deleteLastFragment:(NSInteger)count;

- (NSURL *)mergeMovieFiles;
- (void)reset;
- (void)restore;
- (void)resetupAssetWriter;

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer isAudio:(BOOL)isAudio isVideo:(BOOL)isVideo;

@end

@protocol AKCameraExporterDelegate <NSObject>
@optional
// video
- (void)akExporterDidStartVideoCapture:(AKCameraExporter *)akExporter error:(NSError *)error;
- (void)akExporterDidPauseVideoCapture:(AKCameraExporter *)akExporter duration:(Float64) duration; // stopped but not ended
- (void)akExporterDidPauseVideoCaptureFailed:(AKCameraExporter *)akExporter; // stopped but not ended
- (void)akExporterDidResumeVideoCapture:(AKCameraExporter *)akExporter;
- (void)akExporterDidEndVideoCapture:(AKCameraExporter *)akExporter error:(NSError *)error;

// video capture progress
- (void)akExporterDidCaptureVideoSample:(AKCameraExporter *) akExporter;
- (void)akExporterDidCaptureAudioSample:(AKCameraExporter *) akExporter;

// segement
- (void)akExporterDidDeleteLastSegement:(AKCameraExporter *) akExporter;
- (CMTime)akExporterGetPauseTime;

// export
- (void)akExporterDidExportMovie:(AKCameraExporter *) akExporter movieUrl:(NSURL *)url;
@end
