//
//  AKCameraBGM.m
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraBGM.h"
#import "AKCameraCache.h"

#define kBgmKey @"bgms"

@implementation AKCameraBGM

+ (AKCameraBGM *)shareInstance {
    static AKCameraBGM *s_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_instance = [[self alloc] init];
    });
    return s_instance;
}

- (void)syncDataToCache {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_items];
    [[AKCameraCache shareInstance] storeData:data forKey:kBgmKey];
}

#pragma mark - Getter
- (NSMutableArray *)items {
    if (!_items) {
        _items = [NSMutableArray array];
    }
    return _items;
}

@end

@implementation BGMItem

+ (BGMItem *)itemWithName:(NSString *)name path:(NSString *)path cover:(NSString *)cover url:(NSString *)url {
    BGMItem *item = [[BGMItem alloc] init];
    item.name = name;
    item.path = path;
    item.cover = cover;
    item.url = url;
    return item;
}

-(void)encodeWithCoder:(NSCoder *)aCoder{
    //encode properties/values
    [aCoder encodeObject:_name forKey:@"name"];
    [aCoder encodeObject:_path forKey:@"path"];
    [aCoder encodeObject:_cover forKey:@"cover"];
    [aCoder encodeObject:_url forKey:@"url"];
}

-(id)initWithCoder:(NSCoder *)aDecoder{
    if((self = [super init])) {
        //decode properties/values
        _name = [aDecoder decodeObjectForKey:@"name"];
        _path =[aDecoder decodeObjectForKey:@"path"];
        _cover =[aDecoder decodeObjectForKey:@"cover"];
        _url =[aDecoder decodeObjectForKey:@"url"];
    }
    
    return self;
}

@end
