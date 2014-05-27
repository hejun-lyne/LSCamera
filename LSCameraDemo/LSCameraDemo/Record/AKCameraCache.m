//
//  AKCameraCache.m
//  TaoVideo
//
//  Created by lihejun on 14-3-14.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraCache.h"
#import <CommonCrypto/CommonDigest.h>
#import <sys/stat.h>
#import <dirent.h>

static NSString* const kCameraCacheDirectory = @"akCameraCache";

@implementation AKCameraCache

+ (AKCameraCache *)shareInstance {
    static AKCameraCache *s_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_instance = [[self alloc] init];
    });
    return s_instance;
}

- (id)init
{
    if ((self = [super init]))
    {
        // Init the memory cache
        memCache = [[NSMutableDictionary alloc] init];
        
        // Init the disk cache
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        diskCachePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:kCameraCacheDirectory];
		
        if (![[NSFileManager defaultManager] fileExistsAtPath:diskCachePath])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:diskCachePath
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:NULL];
            
        }
		
        // Init the operation queue
        cacheInQueue = [[NSOperationQueue alloc] init];
        cacheInQueue.maxConcurrentOperationCount = 1;
        cacheOutQueue = [[NSOperationQueue alloc] init];
        cacheOutQueue.maxConcurrentOperationCount = 1;
    }
	
    return self;
}

#pragma mark - AKCameraCache (private)
- (NSString *)cachePathForKey:(NSString *)key
{
    const char *str = [key UTF8String];
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]];
	
    return [diskCachePath stringByAppendingPathComponent:filename];
}

- (void)storeData:(NSData *)aData forKey:(NSString *)key
{
    if (!aData || !key)
    {
        return;
    }
	
    [memCache setObject:aData forKey:key];
	
    NSArray *keyWithData = [NSArray arrayWithObjects:key, nil];
    
    [cacheInQueue addOperation:[[NSInvocationOperation alloc] initWithTarget: self selector:@selector(storeKeyWithDataToDisk:) object:keyWithData]];
}

- (void)storeKeyWithDataToDisk:(NSArray *)keyAndData
{
    // Can't use defaultManager another thread
    NSFileManager *fileManager = [[NSFileManager alloc] init];
	
    NSString *key = [keyAndData objectAtIndex:0];
    
	NSData *data= [memCache objectForKey:key];  // be thread safe with no lock
	if (data)
	{
		[fileManager createFileAtPath:[self cachePathForKey:key] contents:data attributes:nil];
	}
}

- (NSData *)dataFromKey:(NSString *)key
{
    if (key == nil)
    {
        return nil;
    }
	
	NSData *data=[memCache objectForKey:key];
	
    if (!data)
    {
		data=[[NSData alloc] initWithContentsOfFile:[self cachePathForKey:key]];
        if (!data) {
            data = [[NSData alloc] initWithContentsOfFile:[self cachePathForKey:key]]; //check permanent
        }
        if (data)
        {
            [memCache setObject:data forKey:key];
        }
    }
	
    return data;
}

- (void)clearDisk
{
    [cacheInQueue cancelAllOperations];
    [[NSFileManager defaultManager] removeItemAtPath:diskCachePath error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:diskCachePath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
}

- (void)removeDataForKey:(NSString *)key
{
    if (key == nil)
    {
        return;
    }
	
    [memCache removeObjectForKey:key];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self cachePathForKey:key]]) {
        [[NSFileManager defaultManager] removeItemAtPath:[self cachePathForKey:key] error:nil];
    }
}

@end
