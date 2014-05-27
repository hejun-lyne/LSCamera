//
//  AKCameraTextView.h
//  TaoVideo
//
//  Created by lihejun on 14-3-18.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AKCameraTextView : UITextView
/**
 The string that is displayed when there is no other text in the text view.
 
 The default value is `nil`.
 */
@property (nonatomic, strong) NSString *placeholder;

/**
 The color of the placeholder.
 
 The default is `[UIColor lightGrayColor]`.
 */
@property (nonatomic, strong) UIColor *placeholderTextColor;

/**
 Returns the drawing rectangle for the text views’s placeholder text.
 
 @param bounds The bounding rectangle of the receiver.
 @return The computed drawing rectangle for the placeholder text.
 */
- (CGRect)placeholderRectForBounds:(CGRect)bounds;
@end
