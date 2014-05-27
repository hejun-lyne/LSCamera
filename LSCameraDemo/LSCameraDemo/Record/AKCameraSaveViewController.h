//
//  AKCameraSaveViewController.h
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AKVideo.h"
#import "AKCameraViewController.h"

@class AKCameraSaveViewController;

@interface AKCameraSaveViewController : AKCameraViewController
@property (nonatomic, strong)NSURL *videoFileUrlBeforeExport;
@property (nonatomic, weak)AKVideo *video;
@end
