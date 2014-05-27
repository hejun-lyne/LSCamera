//
//  AKCameraCache.h
//  TaoVideo
//
//  Created by lihejun on 14-3-14.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AKCameraCache : NSObject
{
    NSString *diskCachePath;
    NSOperationQueue *cacheInQueue, *cacheOutQueue;
    NSMutableDictionary *memCache;
}

+ (AKCameraCache *)shareInstance;

- (void)storeData:(NSData *)aData forKey:(NSString *)key;
- (NSData *)dataFromKey:(NSString *)key;
- (void)removeDataForKey:(NSString *)key;
- (void)clearDisk;

@end
