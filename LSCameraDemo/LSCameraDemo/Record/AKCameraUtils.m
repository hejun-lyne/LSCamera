//
//  AKCameraUtils.m
//  TaoVideo
//
//  Created by lihejun on 14-3-14.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraUtils.h"
#import "AKCameraCaputure.h"
#import "UIImage+AKResize.h"
#import "AKCameraTool.h"
#import "AKCameraDefines.h"

@implementation AKCameraUtils
+ (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates inFrame:(CGRect)frame
{
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = frame.size;
    
    switch ([[AKCameraCaputure sharedInstance] cameraOrientation]) {
        case AKCameraOrientationPortrait:
            break;
        case AKCameraOrientationPortraitUpsideDown:
            viewCoordinates = CGPointMake(frameSize.width - viewCoordinates.x, frameSize.height - viewCoordinates.y);
            break;
        case AKCameraOrientationLandscapeLeft:
            viewCoordinates = CGPointMake(viewCoordinates.y, frameSize.width - viewCoordinates.x);
            frameSize = CGSizeMake(frameSize.height, frameSize.width);
            break;
        case AKCameraOrientationLandscapeRight:
            viewCoordinates = CGPointMake(frameSize.height - viewCoordinates.y, viewCoordinates.x);
            frameSize = CGSizeMake(frameSize.height, frameSize.width);
            break;
    }
    
    // TODO: add check for AVCaptureConnection videoMirrored
    //        viewCoordinates.x = frameSize.width - viewCoordinates.x;
    
    AVCaptureVideoPreviewLayer *previewLayer = [[AKCameraCaputure sharedInstance] previewLayer];
    
    if ( [[previewLayer videoGravity] isEqualToString:AVLayerVideoGravityResize] ) {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGSize apertureSize = CGSizeMake(CGRectGetHeight(frame), CGRectGetWidth(frame));
        if (!CGSizeEqualToSize(apertureSize, CGSizeZero)) {
            CGPoint point = viewCoordinates;
            CGFloat apertureRatio = apertureSize.height / apertureSize.width;
            CGFloat viewRatio = frameSize.width / frameSize.height;
            CGFloat xc = .5f;
            CGFloat yc = .5f;
            
            if ( [[previewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspect] ) {
                if (viewRatio > apertureRatio) {
                    CGFloat y2 = frameSize.height;
                    CGFloat x2 = frameSize.height * apertureRatio;
                    CGFloat x1 = frameSize.width;
                    CGFloat blackBar = (x1 - x2) / 2;
                    if (point.x >= blackBar && point.x <= blackBar + x2) {
                        xc = point.y / y2;
                        yc = 1.f - ((point.x - blackBar) / x2);
                    }
                } else {
                    CGFloat y2 = frameSize.width / apertureRatio;
                    CGFloat y1 = frameSize.height;
                    CGFloat x2 = frameSize.width;
                    CGFloat blackBar = (y1 - y2) / 2;
                    if (point.y >= blackBar && point.y <= blackBar + y2) {
                        xc = ((point.y - blackBar) / y2);
                        yc = 1.f - (point.x / x2);
                    }
                }
            } else if ([[previewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                if (viewRatio > apertureRatio) {
                    CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                    xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                    yc = (frameSize.width - point.x) / frameSize.width;
                } else {
                    CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                    yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                    xc = point.y / frameSize.height;
                }
            }
            
            pointOfInterest = CGPointMake(xc, yc);
        }
    }
    
    return pointOfInterest;
}

+ (AVCaptureDevice *)captureDeviceForPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    
    return nil;
}

+ (AVCaptureDevice *)audioDevice
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if ([devices count] > 0)
        return [devices objectAtIndex:0];
    
    return nil;
}

+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections
{
	for ( AVCaptureConnection *connection in connections ) {
		for ( AVCaptureInputPort *port in [connection inputPorts] ) {
			if ( [[port mediaType] isEqual:mediaType] ) {
				return connection;
			}
		}
	}
    
	return nil;
}

+ (CMSampleBufferRef)createOffsetSampleBufferWithSampleBuffer:(CMSampleBufferRef)sampleBuffer usingTimeOffset:(CMTime)timeOffset duration:(CMTime)duration
{
    CMItemCount itemCount;
    
    OSStatus status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, 0, NULL, &itemCount);
    if (status) {
        return NULL;
    }
    
    CMSampleTimingInfo *timingInfo = (CMSampleTimingInfo *)malloc(sizeof(CMSampleTimingInfo) * (unsigned long)itemCount);
    if (!timingInfo) {
        return NULL;
    }
    
    status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, itemCount, timingInfo, &itemCount);
    if (status) {
        free(timingInfo);
        timingInfo = NULL;
        return NULL;
    }
    
    for (CMItemCount i = 0; i < itemCount; i++) {
        timingInfo[i].presentationTimeStamp = CMTimeSubtract(timingInfo[i].presentationTimeStamp, timeOffset);
        timingInfo[i].decodeTimeStamp = CMTimeSubtract(timingInfo[i].decodeTimeStamp, timeOffset);
        timingInfo[i].duration = duration;
    }
    
    CMSampleBufferRef offsetSampleBuffer;
    CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, sampleBuffer, itemCount, timingInfo, &offsetSampleBuffer);
    
    if (timingInfo) {
        free(timingInfo);
        timingInfo = NULL;
    }
    
    return offsetSampleBuffer;
}

+ (CGFloat)angleOffsetFromPortraitOrientationToOrientation:(AVCaptureVideoOrientation)orientation
{
	CGFloat angle = 0.0;
	
	switch (orientation) {
		case AVCaptureVideoOrientationPortraitUpsideDown:
			angle = (CGFloat)M_PI;
			break;
		case AVCaptureVideoOrientationLandscapeRight:
			angle = (CGFloat)-M_PI_2;
			break;
		case AVCaptureVideoOrientationLandscapeLeft:
			angle = (CGFloat)M_PI_2;
			break;
		case AVCaptureVideoOrientationPortrait:
		default:
			break;
	}
    
	return angle;
}

#pragma mark - memory

+ (uint64_t)availableDiskSpaceInBytes
{
    uint64_t totalFreeSpace = 0;
    
    __autoreleasing NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error:&error];
    
    if (dictionary) {
        NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
    }
    
    return totalFreeSpace;
}

#pragma mark - Utils
+ (void)deleteFile:(NSURL*) url
{
    ////DLog(@"deleting file:%@", [url absoluteString]);
    NSFileManager *fm = [[NSFileManager alloc] init];
    // 是否存在
    BOOL isExistsOk = [fm fileExistsAtPath:[url path]];
    
    if (isExistsOk) {
        [fm removeItemAtURL:url error:nil];
        NSLog(@"file deleted:%@",url);
    }
    else {
        NSLog(@"file not exists:%@",url);
    }
}

+ (NSString *)getVideoPath{
    static NSString *videoPath = Nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
        videoPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"AKCameraVideo"];
        if (![fm fileExistsAtPath:videoPath]) {
            [fm createDirectoryAtPath:videoPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    });
    return  videoPath;
}

+ (NSString *)getCoverPath{
    static NSString *videoPath = Nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
        videoPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"AKCameraCover"];
        if (![fm fileExistsAtPath:videoPath]) {
            [fm createDirectoryAtPath:videoPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    });
    return  videoPath;
}

+ (NSString *)getBgmPath {
    static NSString *bgmPath = Nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
        bgmPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"AKCameraBgm"];
        if (![fm fileExistsAtPath:bgmPath]) {
            [fm createDirectoryAtPath:bgmPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    });
    return  bgmPath;
}

+ (NSString *)saveCoverFile:(UIImage *)image with:(NSString *)fileName{
    NSString *filePath = [[self getCoverPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg",fileName ]];
    NSError *error;
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
    }
    
    UIImage *oImage = [image imageByScalingAndCroppingForSize:CGSizeMake(320, 320)];
    //UIImage *cropImage = [oImage croppingForSize:CGSizeMake(640, 640)];
    NSData *imageData = UIImageJPEGRepresentation(oImage, 1.0);
    
    if (![imageData writeToFile:filePath atomically:YES]) {
        //DLog(@"保存封面失败！");
    } else {
        //DLog(@"file saved:%@",filePath);
    }
    UIImage *sImage = [oImage imageByScalingAndCroppingForSize:kThumbnailSize];
    NSString *sFilePath = [[self getCoverPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@.jpg",kThumbnailExtend, fileName]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:sFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:sFilePath error:&error];
    }
    imageData = UIImageJPEGRepresentation(sImage, 1.0);
    if (![imageData writeToFile:sFilePath atomically:YES]) {
        //DLog(@"保存封面缩略图失败！");
    } else {
        //DLog(@"file saved:%@",sFilePath);
    }
    return [NSString stringWithFormat:@"%@.jpg",fileName ];
}

+ (void)deleteCoverFile:(NSString *)fileName{
    NSString *filePath = [[self getCoverPath] stringByAppendingPathComponent:fileName];
    NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
    NSFileManager *fm = [[NSFileManager alloc] init];
    // 是否存在
    BOOL isExistsOk = [fm fileExistsAtPath:[fileUrl path]];
    if (isExistsOk) {
        [fm removeItemAtURL:fileUrl error:nil];
        NSLog(@"file deleted:%@",fileUrl);
    }
    else {
        NSLog(@"file not exists:%@",fileUrl);
    }
    NSString *sFilePath = [[self getCoverPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@",kThumbnailExtend, fileName]];
    NSURL *sFileUrl = [NSURL fileURLWithPath:sFilePath];
    isExistsOk = [fm fileExistsAtPath:[sFileUrl path]];
    if (isExistsOk) {
        [fm removeItemAtURL:sFileUrl error:nil];
        NSLog(@"file deleted:%@",sFileUrl);
    }
    else {
        NSLog(@"file not exists:%@",sFileUrl);
    }
}

+ (void) showCaptureAlert {
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"prefs:root=General"]]) {
        NSString *msg = [NSString stringWithFormat:@"请在\"设置->隐私->相机(麦克风)\"允许“%@”访问相机&麦克风",NSBundle.mainBundle.infoDictionary  [@"CFBundleDisplayName"]];
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:nil message:msg delegate:self cancelButtonTitle:@"设置" otherButtonTitles:@"取消", nil];
        [alert show];
    }
    else {
        NSString *msg = [NSString stringWithFormat:@"请在\"设置->隐私->相机(麦克风)\"允许“%@”访问相机&麦克风",NSBundle.mainBundle.infoDictionary  [@"CFBundleDisplayName"]];
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:nil message:msg delegate:self cancelButtonTitle:@"知道了" otherButtonTitles:nil, nil];
        [alert show];
    }
}

+ (NSArray *)extractImagesFromMovie:(NSURL *)filePath {
    NSMutableDictionary* myDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES] ,
                                   AVURLAssetPreferPreciseDurationAndTimingKey ,
                                   [NSNumber numberWithInt:0],
                                   AVURLAssetReferenceRestrictionsKey, nil];
    
    AVURLAsset* movie = [[AVURLAsset alloc] initWithURL:filePath options:myDict];
    
    return [self extractImagesFromAVURLAsset:movie];
}

+ (NSArray *)extractImagesFromAVURLAsset:(AVURLAsset *)movie {
    // set the generator
    AVAssetImageGenerator* generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:movie] ;
    generator.requestedTimeToleranceBefore = kCMTimeZero;
    generator.requestedTimeToleranceAfter = kCMTimeZero;
    
    // look for the video track
    AVAssetTrack* videoTrack;
    bool foundTrack = NO;
    
    for (AVAssetTrack* track in movie.tracks) {
        
        if ([track.mediaType isEqualToString:@"vide"]) {
            if (foundTrack) {
                //DLog (@"Error - - - more than one video tracks");
                return Nil;
            }
            else {
                videoTrack = track;
                foundTrack = YES;
            }
        }
    }
    if (foundTrack == NO) {
        //DLog (@"Error - - No Video Tracks at all");
        return Nil;
    }
    
    // set the number of frames in the movie
    int frameRate = videoTrack.nominalFrameRate;
    float value = movie.duration.value;
    float timeScale = movie.duration.timescale;
    float totalSeconds = value / timeScale;
    int totalFrames = totalSeconds * frameRate;
    
    //DLog (@"total frames %d", totalFrames);
    
    int timeValuePerFrame = movie.duration.timescale / frameRate;
    
    NSMutableArray* allFrames = [NSMutableArray new];
    
    int t = 10;
    int s = (totalFrames -5) / t;
    
    // get each frame
    for (int k=1; k< t; k++) {
        
        int timeValue = timeValuePerFrame * k * s;
        CMTime frameTime;
        frameTime.value = timeValue;
        frameTime.timescale = movie.duration.timescale;
        frameTime.flags = movie.duration.flags;
        frameTime.epoch = movie.duration.epoch;
        
        CMTime gotTime;
        
        CGImageRef myRef = [generator copyCGImageAtTime:frameTime actualTime:&gotTime error:nil];
        if (myRef) {
            [allFrames addObject:[UIImage imageWithCGImage:myRef]];
            CGImageRelease(myRef);
            if (gotTime.value != frameTime.value) {
                //DLog (@"requested %lld got %lld for k %d", frameTime.value, gotTime.value, k);
            }
        }
    }
    //DLog (@"got %d images in the array", [allFrames count]);
    
    return allFrames;
    // do something with images here...
}

+ (void)label:(UILabel *)label setMiniFontSize:(CGFloat)fMiniSize forNumberOfLines:(NSInteger)iLines
{
    if (label)
    {
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = fMiniSize/label.font.pointSize;
        if ((iLines != 1) && (IOSVersion < 7.0f))
        {
            label.adjustsLetterSpacingToFitWidth = YES;
        }else{}
    }else{}
}

+ (BOOL)is4InchScreen
{
    static BOOL bIs4Inch = NO;
    static BOOL bIsGetValue = NO;
    
    if (!bIsGetValue)
    {
        CGRect rcAppFrame = [UIScreen mainScreen].bounds;
        bIs4Inch = (rcAppFrame.size.height == 568.0f);
        
        bIsGetValue = YES;
    }else{}
    
    return bIs4Inch;
}

+ (void)cancelPerformRequestAndNotification:(UIViewController *)viewCtrl
{
    if (viewCtrl)
    {
        [[viewCtrl class] cancelPreviousPerformRequestsWithTarget:viewCtrl];
        [[NSNotificationCenter defaultCenter] removeObserver:viewCtrl];
    }else{}
}

+ (void)resetScrlView:(UIScrollView *)sclView contentInsetWithNaviBar:(BOOL)bHasNaviBar tabBar:(BOOL)bHasTabBar
{
    [[self class] resetScrlView:sclView contentInsetWithNaviBar:bHasNaviBar tabBar:bHasTabBar iOS7ContentInsetStatusBarHeight:0 inidcatorInsetStatusBarHeight:0];
}
+ (void)resetScrlView:(UIScrollView *)sclView contentInsetWithNaviBar:(BOOL)bHasNaviBar tabBar:(BOOL)bHasTabBar iOS7ContentInsetStatusBarHeight:(NSInteger)iContentMulti inidcatorInsetStatusBarHeight:(NSInteger)iIndicatorMulti
{
    if (sclView)
    {
        UIEdgeInsets inset = sclView.contentInset;
        UIEdgeInsets insetIndicator = sclView.scrollIndicatorInsets;
        CGPoint ptContentOffset = sclView.contentOffset;
        CGFloat fTopInset = bHasNaviBar ? NaviBarHeight : 0.0f;
        CGFloat fTopIndicatorInset = bHasNaviBar ? NaviBarHeight : 0.0f;
        CGFloat fBottomInset = bHasTabBar ? TabBarHeight : 0.0f;
        
        fTopInset += StatusBarHeight;
        fTopIndicatorInset += StatusBarHeight;
        
        if (IsiOS7Later)
        {
            fTopInset += iContentMulti * StatusBarHeight;
            fTopIndicatorInset += iIndicatorMulti * StatusBarHeight;
        }else{}
        
        inset.top += fTopInset;
        inset.bottom += fBottomInset;
        [sclView setContentInset:inset];
        
        insetIndicator.top += fTopIndicatorInset;
        insetIndicator.bottom += fBottomInset;
        [sclView setScrollIndicatorInsets:insetIndicator];
        
        ptContentOffset.y -= fTopInset;
        [sclView setContentOffset:ptContentOffset];
    }else{}
}

+ (BOOL) videoFileExists:(NSString *)name
{
    NSString *path = [[self getVideoPath] stringByAppendingPathComponent:name];
    NSFileManager *fm = [NSFileManager defaultManager];
    return [fm fileExistsAtPath:path];
}
+ (NSString *)uniqueMovieFileNameWithPrefix:(NSString *)prefix notIn:(NSArray *)used
{
    NSString *unique = [NSString stringWithFormat:@"%@.%@", prefix, kMovieFileExtension];
    if ([used containsObject:unique] || [self videoFileExists:unique]) {
        int uniqueIx = 1;
        
        do {
            unique = [NSString stringWithFormat:@"%@_%d.%@", prefix, uniqueIx, kMovieFileExtension];
            uniqueIx++;
        } while ([used containsObject:unique] || [self videoFileExists:unique]);
    }
    return unique;
}

+ (BOOL) coverFileExists:(NSString *)name
{
    NSString *path = [[self getCoverPath] stringByAppendingPathComponent:name];
    NSFileManager *fm = [NSFileManager defaultManager];
    return [fm fileExistsAtPath:path];
}

+ (NSString *)uniqueCoverFilenameWithPrefix:(NSString *)prefix
{
    NSString *unique = [NSString stringWithFormat:@"%@.%@", prefix, @"jpg"];
    NSString *uniqueFileName = prefix;
    if ([self coverFileExists:unique]) {
        int uniqueIx = 1;
        
        do {
            uniqueFileName = [NSString stringWithFormat:@"%@_%d", prefix, uniqueIx];
            unique = [NSString stringWithFormat:@"%@_%d.%@", prefix, uniqueIx, @"jpg"];
            uniqueIx++;
        } while ([self coverFileExists:unique]);
    }
    NSLog(@"new cover file:%@", uniqueFileName);
    return uniqueFileName;
}

@end

#pragma mark - NSString Extras

@implementation NSString (AKExtras)

+ (NSString *)AKformattedTimestampStringFromDate:(NSDate *)date
{
    if (!date)
        return nil;
    
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSS'Z'"];
        [dateFormatter setLocale:[NSLocale autoupdatingCurrentLocale]];
    });
    
    return [dateFormatter stringFromDate:date];
}

@end
