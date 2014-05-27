//
//  AKCameraEditViewController.h
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AKCameraTool.h"
#import "AKCameraExporter.h"
#import "AKCameraViewController.h"

@interface AKCameraEditViewController : AKCameraViewController<AKCameraExporterDelegate>

@property (copy, nonatomic) NSArray *images;
@property (weak, nonatomic) AKVideo *video;
@property (assign,nonatomic)BOOL fromLocal; // 来自本地视频
@property (nonatomic, weak) id<AKCameraEditDelegate> delegate;

@end
