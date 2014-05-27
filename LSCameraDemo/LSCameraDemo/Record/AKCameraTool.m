//
//  AKCameraTool.m
//  TaoVideo
//
//  Created by lihejun on 14-3-14.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraTool.h"
#import "AKCameraCache.h"
#import "AKCameraSaveViewController.h"
#import "AKCameraLocationViewController.h"
#import "AKCameraRecordViewController.h"
#import "AKCameraNavigationController.h"
#import "AKCameraEditViewController.h"

#define kVideoKey @"akVideo"

@interface AKCameraTool()<AKCameraInternalDelegate, AKCameraLocationDelegate>
{
    // for save
    NSDictionary *_location;
    NSArray *_locations;
    NSArray *_channels;
    
    // flags
    // flags
    struct {
        unsigned int requestingLocation:1;
    } __block _flags;
    
    dispatch_queue_t akCameraQueue;
}
@property (nonatomic, weak)AKCameraSaveViewController *controller;
@end

@implementation AKCameraTool
@synthesize video = _video;

+ (AKCameraTool *)shareInstance {
    static AKCameraTool *s_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_instance = [[self alloc] init];
    });
    return s_instance;
}

- (id)init {
    self = [super init];
    if (self) {
        akCameraQueue = dispatch_queue_create("com.taobao.akrecord.akCameraQueue", NULL);
    }
    return self;
}

#pragma mark - queue helper methods

typedef void (^AKCameraToolBlock)();
- (void)_enqueueBlockInAKCameraQueue:(AKCameraToolBlock)block {
    dispatch_async(akCameraQueue, ^{
        block();
    });
}

- (void)_executeBlockInAKCameraQueue:(AKCameraToolBlock)block {
    dispatch_sync(akCameraQueue, ^{
        block();
    });
}

- (void)_enqueueBlockOnMainQueue:(AKCameraToolBlock)block {
    dispatch_async(dispatch_get_main_queue(), ^{
        block();
    });
}

- (void)_executeBlockOnMainQueue:(AKCameraToolBlock)block {
    dispatch_sync(dispatch_get_main_queue(), ^{
        block();
    });
}

#pragma mark - AKCameraTool (Public)
- (void)startRecordFromController:(UIViewController *)controller {
    AKCameraRecordViewController *recorder = [AKCameraRecordViewController new];
    _video = [AKVideo new]; //reset video
    [controller presentViewController:[[AKCameraNavigationController alloc] initWithRootViewController:recorder] animated:YES completion:nil];
}

- (void)editVideo:(AKVideo *)video fromController:(UIViewController<AKCameraEditDelegate> *)controller {
    AKCameraEditViewController *vc = [[AKCameraEditViewController alloc] init];
    vc.video = video;
    vc.fromLocal = YES;
    vc.delegate = controller;
    [controller.navigationController pushViewController:vc animated:YES];
}

- (void)syncDataToCache {
    if (_video) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_video];
        [[AKCameraCache shareInstance] storeData:data forKey:kVideoKey];
    } else {
        [[AKCameraCache shareInstance] removeDataForKey:kVideoKey];
    }
}

- (void)akCameraSaveWillCancel:(BOOL)saveAsDraft {
    if (saveAsDraft) {
        // 保存到草稿箱
        // Need handle by delegate
        if (_delegate && [_delegate respondsToSelector:@selector(akCameraWillFinished: asDraft:)]) {
            [_delegate akCameraWillFinished:_video asDraft:YES];
        }
    }
    self.controller = Nil; // retain --
}

- (void)akCameraSaveWillFinish {
    if (_flags.requestingLocation) {
        // 尚在请求地理位置
    }
    if (_location) {
        _video.location = _location;
    }
    // Need handle by delegate
    if (_delegate && [_delegate respondsToSelector:@selector(akCameraWillFinished: asDraft:)]) {
        [_delegate akCameraWillFinished:_video asDraft:NO];
    }
}

#pragma mark - Notify
- (void)delegateRequestLocationFinish:(NSDictionary *)location {
    _location = location;
    _flags.requestingLocation = NO;
}

#pragma mark - Getter
- (AKVideo *)video {
    if (!_video) {
        // Load from cache
        NSData *data = [[AKCameraCache shareInstance] dataFromKey:kVideoKey];
        if (data) {
            _video = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        } else {
            // Create a new video
            _video = [AKVideo new];
        }
    }
    return _video;
}

#pragma mark - Setter
- (void)setVideo:(AKVideo *)video {
    if (!video) {
        [[AKCameraCache shareInstance] removeDataForKey:kVideoKey];
    }
    _video = video;
}
@end
