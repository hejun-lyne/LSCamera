//
//  AKCameraBGMCell.h
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AKCameraBGM.h"

@class AKCameraBGMCell;
@protocol AKCameraBGMCellDelegate <NSObject>

- (void)akCameraBGMCellTapped:(AKCameraBGMCell *)cell;

@end

@interface AKCameraBGMCell : UIView
@property (nonatomic, weak)BGMItem *item;
@property (nonatomic, assign)BOOL selected;
@property (nonatomic, weak)id<AKCameraBGMCellDelegate> delegate;
@end
