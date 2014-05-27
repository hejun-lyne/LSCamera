//
//  AKCameraSoundTrackView.m
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraSoundTrackView.h"
#import "AKCameraTool.h"

@interface AKCameraSoundTrackView()

@property (strong, nonatomic) UISlider *soundSlider;
@property (strong, nonatomic) UILabel *soundlabel;
@property (strong, nonatomic) UILabel *sourceSoundLabel;
@property (strong, nonatomic) UIButton *originalButton;
@property (strong, nonatomic) UIButton *bgmButton;

@end

@implementation AKCameraSoundTrackView

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self config];
    }
    return self;
}

- (void)awakeFromNib {
    [self config];
}

- (CGFloat)value{
    return _soundSlider.value;
}

- (void)config{
    self.backgroundColor = [UIColor clearColor];
    [self addSubview:self.soundSlider];
    [self addSubview:self.soundlabel];
    [self addSubview:self.sourceSoundLabel];
    [self addSubview:self.originalButton];
    [self addSubview:self.bgmButton];
}

- (void)setSliderValue:(CGFloat )value{
    [_soundSlider setValue:value];
    [self updateLabel];
}
- (void)updateLabel{
    float value = _soundSlider.value;
    int left = 100 * (1-value);
    int right = 100 * value;
    
    if (_delegate) {
        [_delegate soundTrackViewValueChange:value];
    }
    _sourceSoundLabel.text = [NSString stringWithFormat:@"原音音量:%i%%",left];
    _soundlabel.text = [NSString stringWithFormat:@"配乐音量:%i%%",right];
    
}
- (void) sliderValueChanged:(id)sender{
    UISlider* control = (UISlider*)sender;
    if(control == _soundSlider){
        [self updateLabel];
    }
}

#pragma mark - Actions

- (IBAction)fullOriginal:(id)sender {
    [_soundSlider setValue:0 animated:YES];
}

- (IBAction)fullBGM:(id)sender {
    [_soundSlider setValue:1 animated:YES];
}

#pragma mark - Getters
- (UISlider *)soundSlider {
    if (!_soundSlider) {
        _soundSlider = [[UISlider alloc] initWithFrame:CGRectMake(46, 21, 229, 34)];
        _soundSlider.value = 0.5;
        _soundSlider.continuous = YES;
        if ([[[UIDevice currentDevice ] systemVersion ] floatValue ] >= 7.0 ) {
            _soundSlider.tintColor = kTintColor;
        } else
            _soundSlider.minimumTrackTintColor = kTintColor;
        
        [_soundSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return _soundSlider;
}

- (UILabel *)soundlabel {
    if (!_soundlabel) {
        _soundlabel = [[UILabel alloc] initWithFrame:CGRectMake(187, 4, 92, 16)];
        _soundlabel.textColor = [UIColor lightGrayColor];
        _soundlabel.font = [UIFont systemFontOfSize:13];
        _soundlabel.backgroundColor = [UIColor clearColor];
        _soundlabel.text = @"配乐音量:50%";
    }
    return _soundlabel;
}

- (UILabel *)sourceSoundLabel {
    if (!_sourceSoundLabel) {
        _sourceSoundLabel = [[UILabel alloc] initWithFrame:CGRectMake(49, 4, 92, 16)];
        _sourceSoundLabel.textColor = [UIColor lightGrayColor];
        _sourceSoundLabel.font = [UIFont systemFontOfSize:13];
        _sourceSoundLabel.backgroundColor = [UIColor clearColor];
        _sourceSoundLabel.text = @"原音音量:50%";
    }
    return _sourceSoundLabel;
}

- (UIButton *)originalButton {
    if (!_originalButton) {
        _originalButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _originalButton.frame = CGRectMake(0, 9, 42, 42);
        [_originalButton setBackgroundImage:[UIImage imageNamed:@"AKCamera.bundle/original.png"] forState:UIControlStateNormal];
        [_originalButton addTarget:self action:@selector(fullOriginal:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _originalButton;
}

- (UIButton *)bgmButton {
    if (!_bgmButton) {
        _bgmButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _bgmButton.frame = CGRectMake(278, 9, 42, 42);
        [_bgmButton setBackgroundImage:[UIImage imageNamed:@"AKCamera.bundle/music.png"] forState:UIControlStateNormal];
        [_bgmButton addTarget:self action:@selector(fullBGM:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _bgmButton;
}

@end
