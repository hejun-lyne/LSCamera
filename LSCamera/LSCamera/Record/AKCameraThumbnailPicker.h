//
//  AKCameraThumbnailPicker.h
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AKCameraThumbnailPicker;

@protocol ThumbnailPickerViewDelegate <NSObject>
@optional
- (void)thumbnailPickerView:(AKCameraThumbnailPicker *)thumbnailPickerView didSelectImageWithIndex:(NSUInteger)index;
@end


@protocol ThumbnailPickerViewDataSource <NSObject>
- (NSUInteger)numberOfImagesForThumbnailPickerView:(AKCameraThumbnailPicker *)thumbnailPickerView;
- (UIImage *)thumbnailPickerView:(AKCameraThumbnailPicker *)thumbnailPickerView imageAtIndex:(NSUInteger)index;
@end

@interface AKCameraThumbnailPicker : UIControl
// NSNotFound if nothing is selected
@property (nonatomic, assign) NSUInteger selectedIndex;
@property (nonatomic, weak) IBOutlet id<ThumbnailPickerViewDataSource> dataSource;
@property (nonatomic, weak) IBOutlet id<ThumbnailPickerViewDelegate> delegate;
@property (nonatomic, assign) CGSize thumbnailSize;
@property (nonatomic,assign) CGSize bigThumbnailSize;
- (void)reloadData;
- (void)reloadThumbnailAtIndex:(NSUInteger)index;

- (void)setSelectedIndex:(NSUInteger)selectedIndex animated:(BOOL)animated;



@end
