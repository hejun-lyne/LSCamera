//
//  AKCameraDownloader.h
//  LSCameraDemo
//
//  Created by lihejun on 14-4-4.
//  Copyright (c) 2014年 hejun.lyne. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AKCameraDownloader;
@protocol AKCameraDownloaderDelegate <NSObject>

- (void)akCameraDownloader:(AKCameraDownloader *)downloader didFinish:(NSData *)data;
@optional
- (void)akCameraDownloaderDidFailed:(AKCameraDownloader *)downloader;
- (void)akCameraDownloader:(AKCameraDownloader *)downloader progress:(float)progress;

@end

@interface AKCameraDownloader : NSObject
@property (nonatomic, weak)id<AKCameraDownloaderDelegate> delegate;

- (void)download:(NSString *)urlString delegate:(id<AKCameraDownloaderDelegate>)delegate;

@end
