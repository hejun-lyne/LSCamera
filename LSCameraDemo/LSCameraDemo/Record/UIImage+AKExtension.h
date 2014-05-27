//
//  UIImage+AKExtension.h
//  TaoVideo
//
//  Created by lihejun on 14-3-19.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (AKExtension)

/*!
 *  @brief Resized image by given size.
 *  @param size The size to resize.
 *  @return An UIImage object containing a resized image from the image.
 *  @details This method depends on CoreGraphics.
 */
- (UIImage *)imageByResizingToSize:(CGSize)size;

/*!
 *  @brief Color filled image with given color.
 *  @param color The color to fill
 *  @details This method depends on CoreGraphics.
 */
- (UIImage *)imageByFilledWithColor:(UIColor *)color;

/*!
 *  @brief Colored image by given size.
 *  @param color The color to fill.
 *  @param size The image size to create.
 */
+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size;

/*!
 *  @brief Clear colored image.
 */
+ (UIImage *)clearImage;

/*!
 *  @brief Image drawn with bazier path.
 *  @param path The bezier path to draw.
 *  @param color The stroke color for bezier path.
 *  @param backgroundColor The fill color for bezier path.
 */
+ (UIImage *)imageWithBezierPath:(UIBezierPath *)path color:(UIColor *)color backgroundColor:(UIColor *)backgroundColor;

/*
 * 圆角图片
 */
+ (UIImage *)roundedImageWithSize:(CGSize)size color:(UIColor *)color radius:(CGFloat)radius;

@end
