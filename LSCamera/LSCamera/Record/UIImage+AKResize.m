//
//  UIImage+AKResize.m
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "UIImage+AKResize.h"

@implementation UIImage (AKResize)

- (UIImage *)imageByCroppingToSize:(CGSize)size
{
    double x = (self.size.width - size.width) / 2.0;
    double y = (self.size.height - size.height) / 2.0;
    
    CGRect cropRect = CGRectMake(x, y, size.height, size.width);
    CGImageRef imageRef = CGImageCreateWithImageInRect([self CGImage], cropRect);
    
    UIImage *cropped = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    return cropped;
}

- (UIImage*)imageByScalingAndCroppingForSize:(CGSize)targetSize {
    CGSize size = self.size;
    if (size.width == targetSize.width && size.height == targetSize.height) {
        return self;
    }
    
    CGFloat scale = [[UIScreen mainScreen] scale];
    if (scale == 2.0f) {
        targetSize = CGSizeMake(targetSize.width * 2, targetSize.height * 2);
    }
    
    
    UIImage *squareImage = Nil;
    if (targetSize.width == targetSize.height && size.width != size.height) {
        // get center square
        squareImage = [self imageByCroppingToSize:CGSizeMake(size.width, size.width)];
    }
    /*
     CGFloat ratio = 1;
     if ((size.height > targetSize.height) || (size.width > targetSize.width)) {
     
     CGFloat widthFactor = targetSize.width / size.width;
     CGFloat heightFactor = targetSize.height / size.height;
     
     if (widthFactor <= heightFactor) {
     ratio = widthFactor;
     } else {
     ratio = heightFactor;
     }
     }
     CGRect rect = CGRectMake(0.0, 0.0, ratio * size.width, ratio * size.height);
     */
    CGRect rect = CGRectMake(0.0, 0.0, targetSize.width, targetSize.height);
    UIGraphicsBeginImageContext(rect.size);
    if (squareImage) {
        [squareImage drawInRect:rect];
    } else {
        [self drawInRect:rect];
    }
    UIImage *_image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return _image;
}

@end
