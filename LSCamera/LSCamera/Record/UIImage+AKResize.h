//
//  UIImage+AKResize.h
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (AKResize)

- (UIImage*)imageByScalingAndCroppingForSize:(CGSize)targetSize;

@end
