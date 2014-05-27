//
//  UIImageView+AKCameraWebImageView.m
//  LSCameraDemo
//
//  Created by lihejun on 14-4-4.
//  Copyright (c) 2014年 hejun.lyne. All rights reserved.
//

#import "UIImageView+AKCameraWebImageView.h"
#import "AKCameraCache.h"

@implementation UIImageView (AKCameraWebImageView)

- (void)setImageWithURL:(NSURL *)url {
    NSData *data = [[AKCameraCache shareInstance] dataFromKey:[url absoluteString]];
    if (data) {
        self.image = [UIImage imageWithData:data];
        return;
    }
    if (url)
    {
        AKCameraDownloader *downloader = [[AKCameraDownloader alloc] init];
        [downloader download:[url absoluteString] delegate:self];
    }
}
#pragma mark - DownloaderDelegate
- (void)akCameraDownloader:(AKCameraDownloader *)downloader didFinish:(NSData *)data {
    UIImage *img=[UIImage imageWithData:data];
    self.image = img;
    CATransition *transition = [CATransition animation];
    transition.duration = .5f;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    transition.type = kCATransitionFade;
    [self.layer addAnimation:transition forKey:nil];
}

@end
