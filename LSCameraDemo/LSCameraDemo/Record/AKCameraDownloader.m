//
//  AKCameraDownloader.m
//  LSCameraDemo
//
//  Created by lihejun on 14-4-4.
//  Copyright (c) 2014年 hejun.lyne. All rights reserved.
//

#import "AKCameraDownloader.h"
#import <CFNetwork/CFNetwork.h>
#import "AKCameraUtils.h"

@interface AKCameraDownloader()<NSURLConnectionDelegate>
{
    NSMutableData *_data;
    long long _fileSize;
    NSString *fileName;
}
@end

@implementation AKCameraDownloader

- (void)download:(NSString *)urlString delegate:(id<AKCameraDownloaderDelegate>)delegate {
    _delegate = delegate;
    fileName = [[urlString componentsSeparatedByString:@"/"] lastObject];
    NSURL*url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:100.0];//设置缓存和超时
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
    
    [connection start];
}

typedef void (^AKCameraDownloaderBlock)();

- (void)_enqueueBlockOnMainQueue:(AKCameraDownloaderBlock)block {
    dispatch_async(dispatch_get_main_queue(), ^{
        block();
    });
}

#pragma mark - NSURLConnectionDelegate
- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
{
    _data = [[NSMutableData alloc] init];
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
    
    if(httpResponse && [httpResponse respondsToSelector:@selector(allHeaderFields)]){
        NSDictionary *httpResponseHeaderFields = [httpResponse allHeaderFields];
        _fileSize = [[httpResponseHeaderFields objectForKey:@"Content-Length"] longLongValue];
    }
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
    NSLog(@"%@", error);
    if (_delegate) {
        [self _enqueueBlockOnMainQueue:^(void){
            if ([_delegate respondsToSelector:@selector(akCameraDownloaderDidFailed:)]) {
                [_delegate akCameraDownloaderDidFailed:self];
            }
        }];
    }
}
-(void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
    [_data appendData:data];
    if (_delegate) {
        [self _enqueueBlockOnMainQueue:^(void){
            if ([_delegate respondsToSelector:@selector(akCameraDownloader:progress:)])
                [_delegate akCameraDownloader:self progress:[data length] / (float)_fileSize];
        }];
    }
}

-(void)connectionDidFinishLoading:(NSURLConnection*)connection
{
    if (_delegate) {
        [self _enqueueBlockOnMainQueue:^(void){
            [_delegate akCameraDownloader:self didFinish:_data];
        }];
    }
}

@end
