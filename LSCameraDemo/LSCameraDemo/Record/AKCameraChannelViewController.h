//
//  AKCameraChannelViewController.h
//  TaoVideo
//
//  Created by lihejun on 14-3-18.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AKCameraViewController.h"

@class AKCameraChannelViewController;
@protocol AKChannelSelectDelegate <NSObject>

-(void)viewController:(AKCameraChannelViewController *)viewController didSelectChannel:(NSArray *)channel;

@end

@interface AKCameraChannelViewController : AKCameraViewController
@property (nonatomic, weak)NSArray *activeChannel;
@property (nonatomic, weak)id<AKChannelSelectDelegate> delegate;

+ (AKCameraChannelViewController *)shareInstance;

@end

@interface AKChannelCell : UITableViewCell
@property (nonatomic, weak)NSArray *channel;
@end
