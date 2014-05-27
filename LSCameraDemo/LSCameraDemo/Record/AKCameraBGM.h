//
//  AKCameraBGM.h
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AKCameraBGM : NSObject
@property (nonatomic, strong)NSMutableArray *items;

+ (AKCameraBGM *)shareInstance;

- (void)syncDataToCache;

@end

@interface BGMItem : NSObject

@property (nonatomic, strong)NSString *name;
@property (nonatomic, strong)NSString *path;
@property (nonatomic, strong)NSString *cover;
@property (nonatomic, strong)NSString *url;

+ (BGMItem *)itemWithName:(NSString *)name path:(NSString *)path cover:(NSString *)cover url:(NSString *)url;

- (void)encodeWithCoder:(NSCoder *)aCoder;
- (id)initWithCoder:(NSCoder *)aDecoder;

@end
