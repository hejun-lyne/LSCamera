//
//  AKCameraUtils.h
//  TaoVideo
//
//  Created by lihejun on 14-3-14.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "AKCameraTool.h"

@interface AKCameraUtils : NSObject
+ (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates inFrame:(CGRect)frame;

+ (AVCaptureDevice *)captureDeviceForPosition:(AVCaptureDevicePosition)position;
+ (AVCaptureDevice *)audioDevice;

+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections;

+ (CMSampleBufferRef)createOffsetSampleBufferWithSampleBuffer:(CMSampleBufferRef)sampleBuffer usingTimeOffset:(CMTime)timeOffset duration:(CMTime)duration;

+ (CGFloat)angleOffsetFromPortraitOrientationToOrientation:(AVCaptureVideoOrientation)orientation;

+ (uint64_t)availableDiskSpaceInBytes;

/* 删除文件 */
+ (void)deleteFile:(NSURL*) url;

/* 视频保存位置 */
+ (NSString *)getVideoPath;

/* 封面保存位置 */
+ (NSString *)getCoverPath;

/* 保存封面图片到磁盘 */
+ (NSString *)saveCoverFile:(UIImage *)image with:(NSString *)fileName;

/* 删除封面图片 */
+ (void)deleteCoverFile:(NSString *)fileName;

/* 显示录制权限警告窗口 */
+ (void) showCaptureAlert;

/* 提取封面图片 */
+ (NSArray *)extractImagesFromMovie:(NSURL *)filePath;
+ (NSArray *)extractImagesFromAVURLAsset:(AVURLAsset *)movie;


/* label设置最小字体大小 */
+ (void)label:(UILabel *)label setMiniFontSize:(CGFloat)fMiniSize forNumberOfLines:(NSInteger)iLines;

/* 是否4英寸屏幕 */
+ (BOOL)is4InchScreen;

/* 清除PerformRequests和notification */
+ (void)cancelPerformRequestAndNotification:(UIViewController *)viewCtrl;

/* 重设scroll view的内容区域和滚动条区域 */
+ (void)resetScrlView:(UIScrollView *)sclView contentInsetWithNaviBar:(BOOL)bHasNaviBar tabBar:(BOOL)bHasTabBar;
+ (void)resetScrlView:(UIScrollView *)sclView contentInsetWithNaviBar:(BOOL)bHasNaviBar tabBar:(BOOL)bHasTabBar iOS7ContentInsetStatusBarHeight:(NSInteger)iContentMulti inidcatorInsetStatusBarHeight:(NSInteger)iIndicatorMulti;

/* 取视频文件路径 */
+ (NSString *)uniqueMovieFilePath;

/* 取封面文件路径 */
+ (NSString *)uniqueCoverFilenameWithPrefix:(NSString *)prefix;

@end

@interface NSString (AKExtras)

+ (NSString *)AKformattedTimestampStringFromDate:(NSDate *)date;

@end
