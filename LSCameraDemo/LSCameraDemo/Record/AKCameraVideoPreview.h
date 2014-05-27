//
//  AKCameraVideoPreview.h
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AKCameraVideoPreview;
@protocol AKCameraVideoPreviewDelegate<NSObject>
- (void)previewVideoViewPlay:(AKCameraVideoPreview *)sender;
- (void)previewVideoViewPause:(AKCameraVideoPreview *)sender;
- (void)previewVideoViewStop:(AKCameraVideoPreview *)sender;
@end

@interface AKCameraVideoPreview : UIView
@property (nonatomic, weak) id<AKCameraVideoPreviewDelegate> delegate;

- (void)setClipImage:(UIImage *)image;
- (void)play;
- (void)stop;
- (void)pause;
- (BOOL)isPlaying;
- (void)config:(NSURL *)url;
- (void)observeValueForKeyPath:(NSString*) path ofObject:(id)object change:(NSDictionary*)change context:(void*)context;
- (void)setVolume:(CGFloat)volume;
- (void)playerReset;

@end
