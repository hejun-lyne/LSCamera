//
//  AKRecordView.h
//  aikan
//
//  Created by lihejun on 14-1-13.
//  Copyright (c) 2014年 taobao. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AKVideo.h"

@protocol AKCameraRecordViewDelegate;
@interface AKCameraRecordView : UIView
@property (nonatomic, weak) id<AKCameraRecordViewDelegate> delegate;
@property (nonatomic, readonly) CGFloat progress;

- (void)showCapture:(BOOL)granted;
- (void)finishCapture;
- (void)cancelCapture;

- (void)loadFromCache; // 继续上次未完成的拍摄

@end

@protocol AKCameraRecordViewDelegate <NSObject>

- (void)akRecordViewStartFailed:(AKCameraRecordView *)view error:(NSError *)error;
- (void)akRecordViewEndFailed:(AKCameraRecordView *)view error:(NSError *)error;
- (void)akRecordViewStartStopping:(AKCameraRecordView *)view;
- (void)akRecordViewRequiredDone:(AKCameraRecordView *)view;
- (void)akRecordView:(AKCameraRecordView *)view didFinishWith:(AKVideo *)video keyFrames:(NSArray *)frames;
- (void)akRecordViewProgressTooSmall;

@end
