//
//  AKCameraTool.h
//  TaoVideo
//
//  Created by lihejun on 14-3-14.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AKVideo.h"
#import "AKCameraStyle.h"
#import "AKCameraDefines.h"
#import "AKCameraUtils.h"

#define kTintColor [UIColor colorWithRed:24/255.0f green:186/255.0f blue:250/255.0f alpha:1]
#define kRecordFileType AVFileTypeQuickTimeMovie//AVFileTypeMPEG4//
#define kMovieFileExtension @"mov"
#define kThumbnailSize CGSizeMake(138, 138)
#define kThumbnailExtend @"thumbnail_"
#define kDescriptionMaxLength 16
#define kMaxKeyFrames 20

@protocol AKCameraEditDelegate <NSObject>

- (void)akCameraEditWillFinish;

@end

@class AKCameraTool;
@protocol AKCameraToolDelegate <NSObject>

@optional
// Location provider, format:{city:xxx,district:xxx,poiName:xxx,poiAddress:xxx,lat:xxx,lng:xxx}
- (void)akCameraNeedLocation; // 异步获取地理位置

- (NSArray *)akCameraNeedNearbyLocations:(NSDictionary *)currentLocation; // 同步获取附近地理位置
- (NSArray *)akCameraNeedChannels; // [[id,name], [id,name]] // 同步获取频道信息
- (NSArray *)akCameraNeedBgms; // [[name, pic, path],[name, pic, path]] // 同步获取BGM信息

- (void)akCameraWillFinished:(AKVideo *)video asDraft:(BOOL)asDraft;

@end
@interface AKCameraTool : NSObject
// Parameters
@property (nonatomic, assign)int maxSeconds;
// Cache
@property (nonatomic, strong)AKVideo *video;
// Delegate
@property (nonatomic, weak) id<AKCameraToolDelegate> delegate;

+ (AKCameraTool *)shareInstance;

// Start record
- (void)startRecordFromController:(UIViewController *)controller;

// Edit
- (void)editVideo:(AKVideo *)video fromController:(UIViewController<AKCameraEditDelegate>*)controller;

// Cache
- (void)syncDataToCache;

// Notify
- (void)delegateRequestLocationFinish:(NSDictionary *)location;

@end

#pragma mark - Private
@protocol AKCameraInternalDelegate <NSObject>

- (void)akCameraSaveWillCancel:(BOOL)saveAsDraft; // notify to clear
- (void)akCameraSaveWillFinish; // notify to finish

@end
