//
//  UIImageView+AKCameraWebImageView.h
//  LSCameraDemo
//
//  Created by lihejun on 14-4-4.
//  Copyright (c) 2014年 hejun.lyne. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AKCameraDownloader.h"

@interface UIImageView (AKCameraWebImageView)<AKCameraDownloaderDelegate>

- (void)setImageWithURL:(NSURL *)url;

@end
