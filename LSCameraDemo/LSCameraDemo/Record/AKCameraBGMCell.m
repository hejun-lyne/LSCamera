//
//  AKCameraBGMCell.m
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraBGMCell.h"
#import "AKCameraTool.h"
#import "AKCameraStyle.h"
#import "UIImageView+AKCameraWebImageView.h"
#import "AKCameraProgressHUD.h"
#import "AKCameraDownloader.h"
#import "AKCameraCache.h"

@interface AKCameraBGMCell()<AKCameraDownloaderDelegate>
{
    UIButton *bigButton;
    UIImageView *imageView;
    UILabel *titleLabel;
    AKRoundProgressView *progressView;
}
@end

@implementation AKCameraBGMCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        [self config];
    }
    return self;
}

#pragma mark - Style
- (void)config {
    self.userInteractionEnabled = YES;
    CGRect r = self.bounds;
    bigButton = [UIButton buttonWithType:UIButtonTypeCustom];
    bigButton.backgroundColor = [UIColor clearColor];
    bigButton.frame = r;
    [bigButton addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:bigButton];
    
    r.size.height = r.size.width;
    imageView = [[UIImageView alloc] initWithFrame:r];
    imageView.layer.borderColor = kTintColor.CGColor;
    [bigButton addSubview:imageView];
    
    r.origin.y = r.size.height;
    r.size.height = self.bounds.size.height - r.size.width;
    titleLabel = [[UILabel alloc] initWithFrame:r];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont systemFontOfSize:11];
    titleLabel.textColor = [UIColor lightGrayColor];
    [bigButton addSubview:titleLabel];
    
    if ([AKCameraStyle useTaoVideoBgmPicker]) {
        imageView.layer.borderColor = [UIColor colorWithRed:237/255.0f green:75/255.0f blue:28/255.0f alpha:1].CGColor;
        imageView.layer.masksToBounds = YES;
        imageView.layer.cornerRadius = imageView.bounds.size.width / 2;
        titleLabel.font = [UIFont systemFontOfSize:13];
        titleLabel.textColor = [UIColor whiteColor];
    }
}

#pragma mark - Actions
- (void)buttonClicked:(UIButton *)button {
    // 检查是否需要下载
    if (_item.url) {
        // 检查缓存
        NSData *data = [[AKCameraCache shareInstance] dataFromKey:_item.url];
        if (data) {
            _item.path = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        } else {
            if (!progressView) {
                progressView = [[AKRoundProgressView alloc] initWithFrame:self.bounds];
                [self addSubview:progressView];
            }
            progressView.progress = 0;
            AKCameraDownloader *downloader = [AKCameraDownloader new];
            [downloader download:_item.url delegate:self];
        }
    }
    if (_delegate) {
        [_delegate akCameraBGMCellTapped:self];
    }
}

#pragma mark - AKCameraDownloaderDelegate
- (void)akCameraDownloader:(AKCameraDownloader *)downloader didFinish:(NSData *)data {
    NSString *fileName = [[_item.url componentsSeparatedByString:@"/"] lastObject];
    NSString *filePath = [[AKCameraUtils getBgmPath] stringByAppendingPathComponent:fileName];
    if ([data writeToFile:filePath atomically:NO]) {
        [[AKCameraCache shareInstance] storeData:[filePath dataUsingEncoding:NSUTF8StringEncoding] forKey:_item.url];
        _item.path = filePath;
    }
    [progressView removeFromSuperview];
    progressView = nil;
}

- (void)akCameraDownloader:(AKCameraDownloader *)downloader progress:(float)progress {
    progressView.progress = progress;
}

- (void)akCameraDownloaderDidFailed:(AKCameraDownloader *)downloader {
    NSLog(@"file download failed!");
}

#pragma mark - Setter
- (void)setItem:(BGMItem *)item {
    _item = item;
    if (_item.cover) {
        [imageView setImage:[UIImage imageNamed:_item.cover]];
    } else {
        // 网络图片
        [imageView setImageWithURL:[NSURL URLWithString:_item.cover]];
    }
    
    [titleLabel setText:_item.name];
}

- (void)setSelected:(BOOL)selected {
    if (selected) {
        imageView.layer.borderWidth = 3;
    } else {
        imageView.layer.borderWidth = 0;
    }
}

@end
