//
//  AKCameraSwitch.m
//  TaoVideo
//
//  Created by lihejun on 14-3-18.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraSwitch.h"
#import <QuartzCore/QuartzCore.h>

@interface AKCameraSwitch () <UIGestureRecognizerDelegate> {
    CAShapeLayer *_thumbLayer;
    CAShapeLayer *_fillLayer;
    CAShapeLayer *_backLayer;
    BOOL _dragging;
    BOOL _on;
}
@property (nonatomic, assign) BOOL pressed;
- (void) setBackgroundOn:(BOOL)on animated:(BOOL)animated;
- (void) showFillLayer:(BOOL)show animated:(BOOL)animated;
- (CGRect) thumbFrameForState:(BOOL)isOn;
@end

@implementation AKCameraSwitch

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self configure];
    }
    return self;
}

- (void) awakeFromNib {
    [super awakeFromNib];
    [self layoutIfNeeded]; //会马上重新计算布局（如果需要），而setNeedsLayout则会在稍后才重新layout，作者提到在这里的作用是“force the calculation of MBSwitch's frame (necessary when using in storyboard)”
    [self configure];
}

- (void) configure {
    //Check width > height
    if (self.frame.size.height > self.frame.size.width*0.65) {
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, ceilf(0.6*self.frame.size.width));
    }
    
    [self setBackgroundColor:[UIColor clearColor]];
    self.onTintColor = [UIColor colorWithRed:0.27f green:0.85f blue:0.37f alpha:1.00f]; //绿色
    self.tintColor = [UIColor colorWithRed:0.90f green:0.90f blue:0.90f alpha:1.00f]; //灰色
    _on = NO;
    _pressed = NO;
    _dragging = NO;
    
    
    /*背景层*/
    _backLayer = [[CAShapeLayer layer] retain];
    _backLayer.backgroundColor = [[UIColor clearColor] CGColor];
    _backLayer.frame = self.bounds;
    _backLayer.cornerRadius = self.bounds.size.height/2.0;
    CGPathRef path1 = [UIBezierPath bezierPathWithRoundedRect:_backLayer.bounds cornerRadius:floorf(_backLayer.bounds.size.height/2.0)].CGPath;
    _backLayer.path = path1;
    [_backLayer setValue:[NSNumber numberWithBool:NO] forKey:@"isOn"];
    _backLayer.fillColor = [_tintColor CGColor]; //填充颜色，背景使用灰色填充
    [self.layer addSublayer:_backLayer];
    
    _fillLayer = [[CAShapeLayer layer] retain];
    _fillLayer.backgroundColor = [[UIColor clearColor] CGColor];
    _fillLayer.frame = CGRectInset(self.bounds, 1.5, 1.5); //为了制造边框
    CGPathRef path = [UIBezierPath bezierPathWithRoundedRect:_fillLayer.bounds cornerRadius:floorf(_fillLayer.bounds.size.height/2.0)].CGPath;
    _fillLayer.path = path;
    [_fillLayer setValue:[NSNumber numberWithBool:YES] forKey:@"isVisible"];
    _fillLayer.fillColor = [[UIColor whiteColor] CGColor]; //默认使用白色
    [self.layer addSublayer:_fillLayer];
    
    
    _thumbLayer = [[CAShapeLayer layer] retain];
    _thumbLayer.backgroundColor = [[UIColor clearColor] CGColor];
    _thumbLayer.frame = CGRectMake(1.0, 1.0, self.bounds.size.height-2.0, self.bounds.size.height-2.0); //圆形
    _thumbLayer.cornerRadius = self.bounds.size.height/2.0;
    CGPathRef knobPath = [UIBezierPath bezierPathWithRoundedRect:_thumbLayer.bounds cornerRadius:floorf(_thumbLayer.bounds.size.height/2.0)].CGPath;
    _thumbLayer.path = knobPath;
    _thumbLayer.fillColor = [UIColor whiteColor].CGColor; //使用白色
    /*设置阴影*/
    _thumbLayer.shadowColor = [UIColor blackColor].CGColor;
    _thumbLayer.shadowOffset = CGSizeMake(0.0, 3.0);
    _thumbLayer.shadowRadius = 3.0;
    _thumbLayer.shadowOpacity = 0.3;
    [self.layer addSublayer:_thumbLayer];
    
	UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                           action:@selector(tapped:)];
	[tapGestureRecognizer setDelegate:self];
	[self addGestureRecognizer:tapGestureRecognizer];
    
	UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                           action:@selector(toggleDragged:)];
    //[panGestureRecognizer requireGestureRecognizerToFail:tapGestureRecognizer];
	[panGestureRecognizer setDelegate:self];
	[self addGestureRecognizer:panGestureRecognizer];
    
    [tapGestureRecognizer release];
    [panGestureRecognizer release];
}

#pragma mark -
#pragma mark Animations

- (BOOL) isOn {
    return _on;
}

- (void) setOn:(BOOL)on {
    [self setOn:on animated:NO];
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
    
    if (_on != on) {
        _on = on;
        [self sendActionsForControlEvents:UIControlEventValueChanged]; //发送事件，以便其他监听者可以处理事件
    }
    if (animated) {
        /*CATransaction is the Core Animation mechanism for batching multiple layer-tree operations into atomic updates to the render tree.*/
        [CATransaction begin]; //CATransaction用来处理multi-layer tree的动画转换为render tree的atomic update
        [CATransaction setAnimationDuration:0.3];
        [CATransaction setDisableActions:NO]; //设置变化动画过程是否显示，默认为YES不显示
        _thumbLayer.frame = [self thumbFrameForState:_on];
        /*这样效率应该更高一点*/
        /*
         [self applyBackgroundOn:_on];
         [self applyFillLayer:_on];
         */
        [CATransaction commit];
        [self setBackgroundOn:_on animated:animated];
        [self showFillLayer:!_on animated:animated];
    }else {
        [CATransaction setDisableActions:YES];
        _thumbLayer.frame = [self thumbFrameForState:_on];
        [self applyBackgroundOn:_on];
        [self applyFillLayer:_on];
    }
    
}

- (void)setOnWithoutEvent:(BOOL)on animated:(BOOL)animated{
    if (_on != on) {
        _on = on;
    }
    if (animated) {
        /*CATransaction is the Core Animation mechanism for batching multiple layer-tree operations into atomic updates to the render tree.*/
        [CATransaction begin]; //CATransaction用来处理multi-layer tree的动画转换为render tree的atomic update
        [CATransaction setAnimationDuration:0.3];
        [CATransaction setDisableActions:NO]; //设置变化动画过程是否显示，默认为YES不显示
        _thumbLayer.frame = [self thumbFrameForState:_on];
        /*这样效率应该更高一点*/
        /*
         [self applyBackgroundOn:_on];
         [self applyFillLayer:_on];
         */
        [CATransaction commit];
        [self setBackgroundOn:_on animated:animated];
        [self showFillLayer:!_on animated:animated];
    }else {
        [CATransaction setDisableActions:YES];
        _thumbLayer.frame = [self thumbFrameForState:_on];
        [self applyBackgroundOn:_on];
        [self applyFillLayer:_on];
    }
}

- (void) applyBackgroundOn:(BOOL)on{
    BOOL isOn = [[_backLayer valueForKey:@"isOn"] boolValue];
    if (on != isOn) {
        [_backLayer setValue:[NSNumber numberWithBool:on] forKey:@"isOn"];
        _backLayer.fillColor = on ? _onTintColor.CGColor : _tintColor.CGColor;
    }
}

- (void) applyFillLayer:(BOOL)show{
    BOOL isVisible = [[_fillLayer valueForKey:@"isVisible"] boolValue];
    if (isVisible != show) {
        [_fillLayer setValue:[NSNumber numberWithBool:show] forKey:@"isVisible"];
        CGFloat scale = show ? 1.0 : 0.0;
        _fillLayer.transform = CATransform3DMakeScale(scale,scale,1.0);
    }
}

- (void) setBackgroundOn:(BOOL)on animated:(BOOL)animated {
    BOOL isOn = [[_backLayer valueForKey:@"isOn"] boolValue];
    if (on != isOn) {
        [_backLayer setValue:[NSNumber numberWithBool:on] forKey:@"isOn"];
        if (animated) {
            /*CABasicAnimation provides basic, single-keyframe animation capabilities for a layer property. */
            CABasicAnimation *animateColor = [CABasicAnimation animationWithKeyPath:@"fillColor"]; //为什么又改用CABasicAnimation了呢？
            animateColor.duration = 0.22;
            animateColor.fromValue = on ? (id)_tintColor.CGColor : (id)_onTintColor.CGColor;
            animateColor.toValue = on ? (id)_onTintColor.CGColor : (id)_tintColor.CGColor;
            animateColor.removedOnCompletion = NO;
            animateColor.fillMode = kCAFillModeForwards;
            [_backLayer addAnimation:animateColor forKey:@"animateColor"];
            [CATransaction commit]; //去除这行代码也没有任何变化
        }else {
            [_backLayer removeAllAnimations];
            _backLayer.fillColor = on ? _onTintColor.CGColor : _tintColor.CGColor;
        }
    }
}

- (void) showFillLayer:(BOOL)show animated:(BOOL)animated {
    BOOL isVisible = [[_fillLayer valueForKey:@"isVisible"] boolValue];
    if (isVisible != show) {
        [_fillLayer setValue:[NSNumber numberWithBool:show] forKey:@"isVisible"];
        CGFloat scale = show ? 1.0 : 0.0;
        if (animated) {
            CGFloat from = show ? 0.0 : 1.0;
            CABasicAnimation *animateScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
            animateScale.duration = 0.22;
            animateScale.fromValue = [NSValue valueWithCATransform3D:CATransform3DMakeScale(from, from, 1.0)];
            animateScale.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeScale(scale, scale, 1.0)];
            animateScale.removedOnCompletion = NO;
            animateScale.fillMode = kCAFillModeForwards;
            animateScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [_fillLayer addAnimation:animateScale forKey:@"animateScale"];
        }else {
            [_fillLayer removeAllAnimations];
            _fillLayer.transform = CATransform3DMakeScale(scale,scale,1.0);
        }
    }
}

- (void) setPressed:(BOOL)pressed {
    if (_pressed != pressed) {
        _pressed = pressed;
        
        if (!_on) {
            [self showFillLayer:!_pressed animated:YES];
        }
    }
}

#pragma mark -
#pragma mark Appearance

- (void) setTintColor:(UIColor *)tintColor {
    [_tintColor autorelease];
    _tintColor = [tintColor retain];
    if (![[_backLayer valueForKey:@"isOn"] boolValue]) {
        _backLayer.fillColor = [_tintColor CGColor];
    }
}

- (void) setOnTintColor:(UIColor *)onTintColor {
    [_onTintColor autorelease];
    _onTintColor = [onTintColor retain];
    if ([[_backLayer valueForKey:@"isOn"] boolValue]) {
        _backLayer.fillColor = [_onTintColor CGColor];
    }
}

- (void) setOffTintColor:(UIColor *)offTintColor {
    _fillLayer.fillColor = [offTintColor CGColor];
}

- (UIColor *) offTintColor {
    return [UIColor colorWithCGColor:_fillLayer.fillColor];
}

- (void) setThumbTintColor:(UIColor *)thumbTintColor {
    _thumbLayer.fillColor = [thumbTintColor CGColor];
}

- (UIColor *) thumbTintColor {
    return [UIColor colorWithCGColor:_thumbLayer.fillColor];
}

#pragma mark -
#pragma mark Interaction

- (void)tapped:(UITapGestureRecognizer *)gesture
{
	if (gesture.state == UIGestureRecognizerStateEnded)
		[self setOn:!self.on animated:YES];
}

- (void)toggleDragged:(UIPanGestureRecognizer *)gesture
{
	CGFloat minToggleX = 1.0;
	CGFloat maxToggleX = self.bounds.size.width-self.bounds.size.height+1.0;
    
	if (gesture.state == UIGestureRecognizerStateBegan)
	{
		self.pressed = YES;
        _dragging = YES;
	}
	else if (gesture.state == UIGestureRecognizerStateChanged)
	{
		CGPoint translation = [gesture translationInView:self];
        
		[CATransaction setDisableActions:YES];
        
		self.pressed = YES;
        
		CGFloat newX = _thumbLayer.frame.origin.x + translation.x;
		if (newX < minToggleX) newX = minToggleX;
		if (newX > maxToggleX) newX = maxToggleX;
		_thumbLayer.frame = CGRectMake(newX,
                                       _thumbLayer.frame.origin.y,
                                       _thumbLayer.frame.size.width,
                                       _thumbLayer.frame.size.height);
        
        if (CGRectGetMidX(_thumbLayer.frame) > CGRectGetMidX(self.bounds)
            && ![[_backLayer valueForKey:@"isOn"] boolValue]) {
            [self setBackgroundOn:YES animated:YES];
        }else if (CGRectGetMidX(_thumbLayer.frame) < CGRectGetMidX(self.bounds)
                  && [[_backLayer valueForKey:@"isOn"] boolValue]){
            [self setBackgroundOn:NO animated:YES];
        }
        
        
		[gesture setTranslation:CGPointZero inView:self];
	}
	else if (gesture.state == UIGestureRecognizerStateEnded)
	{
		CGFloat toggleCenter = CGRectGetMidX(_thumbLayer.frame);
        [self setOn:(toggleCenter > CGRectGetMidX(self.bounds)) animated:YES];
        _dragging = NO;
        self.pressed = NO;
	}
    
	CGPoint locationOfTouch = [gesture locationInView:self];
	if (CGRectContainsPoint(self.bounds, locationOfTouch))
		[self sendActionsForControlEvents:UIControlEventTouchDragInside];
	else
		[self sendActionsForControlEvents:UIControlEventTouchDragOutside];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesBegan:touches withEvent:event];
    
    self.pressed = YES;
	
	[self sendActionsForControlEvents:UIControlEventTouchDown];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesEnded:touches withEvent:event];
    if (!_dragging) {
        self.pressed = NO;
    }
	[self sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesCancelled:touches withEvent:event];
    if (!_dragging) {
        self.pressed = NO;
    }
	[self sendActionsForControlEvents:UIControlEventTouchUpOutside];
}

#pragma mark -
#pragma mark Thumb Frame

- (CGRect) thumbFrameForState:(BOOL)isOn {
    return CGRectMake(isOn ? self.bounds.size.width-self.bounds.size.height+1.0 : 1.0,
                      1.0,
                      self.bounds.size.height-2.0,
                      self.bounds.size.height-2.0);
}

#pragma mark -
#pragma mark Dealloc

- (void) dealloc {
    [_tintColor release], _tintColor = nil;
    [_onTintColor release], _onTintColor = nil;
    
    [_thumbLayer release], _thumbLayer = nil;
    [_fillLayer release], _fillLayer = nil;
    [_backLayer release], _backLayer = nil;
    [super dealloc];
}

@end
