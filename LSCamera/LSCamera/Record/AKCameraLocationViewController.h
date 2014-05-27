//
//  AKCameraLocationViewController.h
//  TaoVideo
//
//  Created by lihejun on 14-3-18.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AKCameraViewController.h"

@class AKCameraLocationViewController;
@protocol AKCameraLocationDelegate <NSObject>

@optional
- (void)viewController:(AKCameraLocationViewController *)controller didSelectLocation:(NSDictionary *)location;

@end

@interface AKCameraLocationViewController : AKCameraViewController
@property (weak, nonatomic)id<AKCameraLocationDelegate> delegate;
@property (strong, nonatomic)NSDictionary *location;
@property (strong, nonatomic)NSArray *locations;

+ (AKCameraLocationViewController *)shareInstance;

@end

@interface AKLocationCell : UITableViewCell
@property (nonatomic, weak)NSDictionary *location;
@end
