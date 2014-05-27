//
//  AKVideo.m
//  TaoVideo
//
//  Created by lihejun on 14-3-14.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKVideo.h"
#import "AKCameraUtils.h"

@implementation AKVideo

-(void)encodeWithCoder:(NSCoder *)aCoder{
    //encode properties/values
    [aCoder encodeObject:_videoFileName forKey:@"videoFileName"];
    [aCoder encodeObject:_coverFileName forKey:@"coverFileName"];
    [aCoder encodeObject:_createTime forKey:@"createTime"];
    [aCoder encodeObject:_duration forKey:@"duration"];
    [aCoder encodeObject:_videoFileSize forKey:@"videoFileSize"];
    [aCoder encodeObject:_location forKey:@"location"];
    [aCoder encodeObject:_coverSelectedIndex forKey:@"coverSelectedIndex"];
    [aCoder encodeObject:_access forKey:@"access"];
    [aCoder encodeObject:_anonymity forKey:@"anonymity"];
    [aCoder encodeObject:_videoDescription forKey:@"videoDescription"];
    [aCoder encodeObject:_channel forKey:@"channel"];
    
    [aCoder encodeObject:_movieFilePaths forKey:@"movieFilePaths"];
    [aCoder encodeObject:_maxSeconds forKey:@"maxSeconds"];
    [aCoder encodeObject:_keyFrames forKey:@"keyFrames"];
    [aCoder encodeObject:_defaultCover forKey:@"defaultCover"];
}

-(id)initWithCoder:(NSCoder *)aDecoder{
    if((self = [super init])) {
        //decode properties/values
        _videoFileName = [aDecoder decodeObjectForKey:@"videoFileName"];
        _coverFileName =[aDecoder decodeObjectForKey:@"coverFileName"];
        _createTime =[aDecoder decodeObjectForKey:@"createTime"];
        _duration =[aDecoder decodeObjectForKey:@"duration"];
        _videoFileSize =[aDecoder decodeObjectForKey:@"videoFileSize"];
        _location =[aDecoder decodeObjectForKey:@"location"];
        _coverSelectedIndex =[aDecoder decodeObjectForKey:@"coverSelectedIndex"];
        _access =[aDecoder decodeObjectForKey:@"access"];
        _anonymity =[aDecoder decodeObjectForKey:@"anonymity"];
        _videoDescription =[aDecoder decodeObjectForKey:@"videoDescription"];
        _channel =[aDecoder decodeObjectForKey:@"channel"];
        _movieFilePaths = [aDecoder decodeObjectForKey:@"movieFilePaths"];
        _maxSeconds = [aDecoder decodeObjectForKey:@"maxSeconds"];
        _keyFrames = [aDecoder decodeObjectForKey:@"keyFrames"];
        _defaultCover = [aDecoder decodeObjectForKey:@"defaultCover"];
    }
    
    return self;
}

- (NSURL *)getVideoPath {
    if (_videoFileName) {
        return [NSURL fileURLWithPath:[[AKCameraUtils getVideoPath] stringByAppendingPathComponent:_videoFileName]];
    }
    return nil;
}

- (NSURL *)getCoverPath {
    if (_coverFileName) {
        return [NSURL fileURLWithPath:[[AKCameraUtils getCoverPath] stringByAppendingPathComponent:_coverFileName]];
    }
    return nil;
}

- (void)setVideoFilePath:(NSURL *)url {
    if (url && ![[url absoluteString] isEqualToString:@""]) {
        NSArray *parts = [[url absoluteString] componentsSeparatedByString:@"/"];
        _videoFileName = [parts lastObject];
    }
    
}

- (void)setCoverFilePath:(NSURL *)url {
    if (url && ![[url absoluteString] isEqualToString:@""]) {
        NSArray *parts = [[url absoluteString] componentsSeparatedByString:@"/"];
        _coverFileName = [parts lastObject];
    }
}

#pragma mark - Getters
- (NSMutableArray *)movieFilePaths {
    if (!_movieFilePaths) {
        _movieFilePaths = [NSMutableArray array];
    }
    return _movieFilePaths;
}

- (NSMutableArray *)keyFrames {
    if (!_keyFrames) {
        _keyFrames = [NSMutableArray array];
    }
    return _keyFrames;
}

@end
