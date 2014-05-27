//
//  AKCameraThumbnailPicker.m
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraThumbnailPicker.h"
#import <QuartzCore/QuartzCore.h>

//static const CGSize kThumbnailSize        = {26, 27};
//static const CGSize kBigThumbnailSize     = {32, 32};
static const NSUInteger kThumbnailSpacing = 0;

static const NSUInteger kTagOffset = 100;
static const NSUInteger kBigThumbnailTagOffset = 1000;

@interface AKCameraThumbnailPicker()
- (UIImageView *)_createThumbnailImageViewWithSize:(CGSize)size;
- (void)_setup;
- (void)_updateSelectedIndexForTouch:(UITouch *)touch fineGrained:(BOOL)fineGrained;
- (void)_updateBigThumbnailPositionVerbose:(BOOL)verbose animated:(BOOL)animated;
- (void)_memoryWarning:(NSNotification *)notification;

- (void)_prepareImageViewForReuse:(UIImageView *)imageView;
- (UIImageView *)_dequeueReusableImageView;

@property (nonatomic, assign) NSUInteger visibleThumbnailsCount;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, weak) UIImageView *bigThumbnailImageView;
@property (nonatomic, strong, readonly) NSMutableSet *reusableThumbnailImageViews;
@end
@implementation AKCameraThumbnailPicker

@synthesize selectedIndex = _selectedIndex;
@synthesize dataSource = _dataSource, delegate = _delegate;
@synthesize visibleThumbnailsCount = _visibleThumbnailsCount;
@synthesize contentView = _contentView, bigThumbnailImageView = _bigThumbnailImageView;
@synthesize reusableThumbnailImageViews = _reusableThumbnailImageViews;
@synthesize bigThumbnailSize = _kBigThumbnailSize;
@synthesize thumbnailSize = _kThumbnailSize;

- (UIImageView *)_createThumbnailImageViewWithSize:(CGSize)size
{
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.backgroundColor = [UIColor clearColor];
    imageView.layer.borderWidth = 0;
    imageView.layer.borderColor = [UIColor whiteColor].CGColor;
    imageView.clipsToBounds = YES;
    imageView.userInteractionEnabled = NO;
    return imageView;
}

- (void)_setup
{
    self.selectedIndex = NSNotFound;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_memoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    self.backgroundColor = [UIColor clearColor];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _setup];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self _setup];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

- (void)_memoryWarning:(NSNotification *)notification
{
    [self.reusableThumbnailImageViews removeAllObjects];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex animated:(BOOL)animated
{
    if (_selectedIndex != selectedIndex) {
        _selectedIndex = selectedIndex;
        if (_selectedIndex != NSNotFound)
            [self _updateBigThumbnailPositionVerbose:NO animated:animated];
    }
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex
{
    [self setSelectedIndex:selectedIndex animated:NO];
}

- (NSMutableSet *)reusableThumbnailImageViews
{
    if (!_reusableThumbnailImageViews) {
        _reusableThumbnailImageViews = [NSMutableSet set];
    }
    return _reusableThumbnailImageViews;
}

- (UIImageView *)_dequeueReusableImageView
{
    UIImageView *imageView = [self.reusableThumbnailImageViews anyObject];
    
    if (imageView) {
        [self.reusableThumbnailImageViews removeObject:imageView];
        //        //DLog(@"found reusable image view!");
    }
    
    return imageView;
}

- (void)_prepareImageViewForReuse:(UIImageView *)imageView
{
    if (imageView.tag != 0) {
        imageView.image = nil;
        imageView.tag = 0;
        [self.reusableThumbnailImageViews addObject:imageView];
        [imageView removeFromSuperview];
    }
}

- (void)setDataSource:(id<ThumbnailPickerViewDataSource>)dataSource
{
    if (_dataSource != dataSource) {
        _dataSource = dataSource;
        [self setNeedsLayout]; // layoutSubviews calls reloadData
    }
}

- (void)reloadData
{
    NSUInteger totalItemsCount = [self.dataSource numberOfImagesForThumbnailPickerView:self];
    if (totalItemsCount == 0)
        return;
    
    CGFloat contentsWidth = totalItemsCount * _kThumbnailSize.width + (totalItemsCount-1) * kThumbnailSpacing; // cw = i*w + (i-1)*s
    if (contentsWidth > self.bounds.size.width) {
        self.visibleThumbnailsCount = floor((self.bounds.size.width+kThumbnailSpacing)/(_kThumbnailSize.width+kThumbnailSpacing)); // i = (c+s)/(w+s)
        contentsWidth = self.visibleThumbnailsCount * _kThumbnailSize.width + (self.visibleThumbnailsCount-1) * kThumbnailSpacing;
    } else {
        self.visibleThumbnailsCount = totalItemsCount;
    }
    
    NSMutableArray *indices = [NSMutableArray arrayWithCapacity:self.visibleThumbnailsCount];
    if (self.visibleThumbnailsCount < totalItemsCount) {
        for (NSUInteger i = 0; i < self.visibleThumbnailsCount; i++) {
            [indices addObject:[NSNumber numberWithUnsignedInteger:(float)i/(self.visibleThumbnailsCount-1)*(totalItemsCount-1)]];
        }
    } else {
        for (NSUInteger i = 0; i < self.visibleThumbnailsCount; i++) {
            [indices addObject:[NSNumber numberWithUnsignedInteger:i]];
        }
    }
    
    if (!self.contentView) {
        self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, contentsWidth, _kThumbnailSize.height)];
        self.contentView.userInteractionEnabled = NO;
        self.contentView.backgroundColor = [UIColor clearColor];
        [self addSubview:self.contentView];
    } else {
        
        [self.contentView.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if (![indices containsObject:[NSNumber numberWithInt:[obj tag]-kTagOffset]]) {
                [self _prepareImageViewForReuse:obj];
            }
        }];
        
        CGRect contentViewFrame = self.contentView.frame;
        contentViewFrame.size.width = contentsWidth;
        self.contentView.frame = contentViewFrame;
    }
    
    UIImageView *imageView = nil;
    CGRect imageViewFrame;
    NSUInteger index;
    NSInteger tag;
    
    for (NSUInteger i = 0; i < self.visibleThumbnailsCount; i++) {
        index = [[indices objectAtIndex:i] unsignedIntegerValue];
        tag = index + kTagOffset;
        
        imageView = (UIImageView *)[self.contentView viewWithTag:tag];
        if (!imageView) {
            imageView = [self _dequeueReusableImageView];
            if (!imageView) {
                imageView = [self _createThumbnailImageViewWithSize:_kThumbnailSize];
            }
            imageView.tag = tag;
        }
        
        imageViewFrame = imageView.frame;
        imageViewFrame.origin.x = i * (_kThumbnailSize.width + kThumbnailSpacing);
        [imageView setFrame:imageViewFrame];
        
        [self.contentView addSubview:imageView];
        
        dispatch_queue_t imageLoadingQueue = dispatch_queue_create("image loading queue", NULL);
        dispatch_async(imageLoadingQueue, ^{
            UIImage *image = [self.dataSource thumbnailPickerView:self imageAtIndex:index];
            dispatch_async(dispatch_get_main_queue(),^{
                imageView.image = image;
            });
        });
        //dispatch_release(imageLoadingQueue);
    }
    [self _updateBigThumbnailPositionVerbose:NO animated:NO];
}

- (void)reloadThumbnailAtIndex:(NSUInteger)index
{
    //    UIImageView *imageView = (UIImageView *)[self.contentView viewWithTag:index + kTagOffset];
    //    if (imageView) {
    //        dispatch_queue_t imageLoadingQueue = dispatch_queue_create("image loading queue", NULL);
    //        dispatch_async(imageLoadingQueue, ^{
    //            UIImage *image = [self.dataSource thumbnailPickerView:self imageAtIndex:index];
    //            dispatch_async(dispatch_get_main_queue(),^{
    //                imageView.image = image;
    //                if (index == self.selectedIndex) {
    //                    self.bigThumbnailImageView.image = image;
    //                }
    //            });
    //        });
    //        dispatch_release(imageLoadingQueue);
    //    }
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    [self _updateSelectedIndexForTouch:touch fineGrained:NO];
    [self _updateBigThumbnailPositionVerbose:YES animated:NO];
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    [self _updateSelectedIndexForTouch:touch fineGrained:YES];
    [self _updateBigThumbnailPositionVerbose:YES animated:NO];
    return YES;
}

- (void)_updateSelectedIndexForTouch:(UITouch *)touch fineGrained:(BOOL)fineGrained
{
    CGPoint pos = [touch locationInView:self.contentView];
    NSUInteger totalItemsCount = [self.dataSource numberOfImagesForThumbnailPickerView:self];
    NSInteger idx;
    if (fineGrained)
        idx = floor(pos.x / self.contentView.frame.size.width * (totalItemsCount-1));
    else
        idx = floor(floor(pos.x/(_kThumbnailSize.width+kThumbnailSpacing)) / (self.visibleThumbnailsCount-1) * (totalItemsCount-1));
    
    idx = MAX(0, idx);
    idx = MIN(totalItemsCount-1, idx);
    
    _selectedIndex = idx;
}

- (void)_updateBigThumbnailPositionVerbose:(BOOL)verbose animated:(BOOL)animated
{
    if (self.selectedIndex != NSNotFound && self.contentView.subviews.count > 0) {
        UIView *subview = nil;
        NSInteger tag = self.selectedIndex+kTagOffset;
        NSInteger tagOffset = 0;
        //        //DLog(@"trying tag %d, tagOffset %d", tag, tagOffset);
        while (!(subview = [self.contentView viewWithTag:tag])) {
            tag += (tagOffset = (tagOffset + (tagOffset>0 ? 1 : -1)) * -1); // 0, 1, -2, 3, -4, 5, -6 ...
            //            //DLog(@"trying tag %d, tagOffset %d", tag, tagOffset);
        }
        
        if (!self.bigThumbnailImageView) {
            UIImageView *bigThumb = [self _createThumbnailImageViewWithSize:_kBigThumbnailSize];
            bigThumb.image = [UIImage imageNamed:@"AKCamera.bundle/cover_tile_selected"];
            self.bigThumbnailImageView = bigThumb;
            [self addSubview:self.bigThumbnailImageView];
        }
        
        void (^animations)(void) = ^ {
            self.bigThumbnailImageView.center = [self.contentView convertPoint:subview.center toView:self];
            dispatch_queue_t imageLoadingQueue = dispatch_queue_create("image loading queue", NULL);
            dispatch_async(imageLoadingQueue, ^{
                UIImage *image = [UIImage imageNamed:@"AKCamera.bundle/cover_tile_selected"];//[self.dataSource thumbnailPickerView:self imageAtIndex:self.selectedIndex];
                dispatch_async(dispatch_get_main_queue(),^{
                    self.bigThumbnailImageView.image = image;
                });
            });
            //dispatch_release(imageLoadingQueue);
        };
        
        if (animated)
            [UIView animateWithDuration:0.2 animations:animations];
        else
            animations();
        
        self.bigThumbnailImageView.tag = tag-kTagOffset+kBigThumbnailTagOffset;
        [self bringSubviewToFront:self.bigThumbnailImageView];
        
        if (verbose && [self.delegate respondsToSelector:@selector(thumbnailPickerView:didSelectImageWithIndex:)])
            [self.delegate thumbnailPickerView:self didSelectImageWithIndex:self.selectedIndex];
    }
}

- (void)layoutSubviews
{
    [self reloadData];
    self.contentView.center = [self convertPoint:self.center fromView:self.superview];
    if (self.bigThumbnailImageView) {
        // center big thumbnail view vertically
        CGRect frame = self.bigThumbnailImageView.frame;
        frame.origin.y = (self.bounds.size.height - frame.size.height) / 2;
        self.bigThumbnailImageView.frame = frame;
        
        UIView *subview = [self.contentView viewWithTag:self.bigThumbnailImageView.tag-kBigThumbnailTagOffset+kTagOffset];
        if (subview)
            self.bigThumbnailImageView.center = [self.contentView convertPoint:subview.center toView:self];
    }
}


@end
