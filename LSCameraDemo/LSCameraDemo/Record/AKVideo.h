//
//  AKVideo.h
//  TaoVideo
//
//  Created by lihejun on 14-3-14.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AKVideo : NSObject
@property (nonatomic, strong)NSString *videoFileName; // 视频文件
@property (nonatomic, strong)NSString *coverFileName; // 封面文件
@property (nonatomic, strong)NSDate *createTime; // 创建时间
@property (nonatomic, strong)NSNumber *duration; // 持续时间
@property (nonatomic, strong)NSNumber *videoFileSize; // 视频文件大小
@property (nonatomic, strong)NSDictionary *location; // 地址: {province:xxx,city:xxx,district:xxx,poiName:xxx,poiAddress:xxx,lat:xxx,lng:xxx}
@property (nonatomic, strong)NSNumber *coverSelectedIndex; // 选中的封面索引
@property (nonatomic, strong)NSNumber *access; // 访问权限: 0 - public; 1 - private
@property (nonatomic, strong)NSNumber *anonymity; // 匿名: 0 - no; 1 - yes
@property (nonatomic, strong)NSString *videoDescription; // 视频描述
@property (nonatomic, strong)NSArray *channel; // 频道:[id,name]

// 中断拍摄可继续
@property (nonatomic, strong)NSNumber *maxSeconds; // 最长拍摄时长
@property (nonatomic, strong)NSMutableArray *movieFilePaths; // 分段拍摄的各个分段文件路径，用于恢复上次中断的拍摄
@property (nonatomic, strong)NSMutableArray *keyFrames; // 拍摄过程提取的关键帧
@property (nonatomic, strong)UIImage *defaultCover;

- (void)encodeWithCoder:(NSCoder *)aCoder;
- (id)initWithCoder:(NSCoder *)aDecoder;

- (NSURL *)getVideoPath;
- (NSURL *)getCoverPath;
- (void)setVideoFilePath:(NSURL *)url;
- (void)setCoverFilePath:(NSURL *)url;

@end
