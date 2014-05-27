//
//  AKCameraSaveViewController.m
//  TaoVideo
//
//  Created by lihejun on 14-3-17.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraSaveViewController.h"
#import "AKCameraTextView.h"
#import "AKCameraSwitch.h"
#import "AKCameraTool.h"
#import "AKCameraUtils.h"
#import "AKCameraMessageHUD.h"
#import "AKCameraChannelViewController.h"
#import "AKCameraLocationViewController.h"
#import <MediaPlayer/MediaPlayer.h>

@interface AKCameraSaveViewController ()<UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, AKChannelSelectDelegate, AKCameraLocationDelegate>
{
    AKCameraTool<AKCameraInternalDelegate> *akTool;
}
@property (nonatomic, strong)UITableView *contentView;
@property (nonatomic, strong)UIImageView *coverImageView;
@property (nonatomic, strong)UIButton *playButton;
@property (nonatomic, strong)AKCameraTextView *descriptionTextView;
@property (nonatomic, strong)UIButton *selectTagButton;
@property (nonatomic, strong)UIView *firstWrapper;
@property (nonatomic, strong)UIButton *locationButton;
@property (nonatomic, strong)UILabel *locationLabel;
@property (nonatomic, strong)UIView *locationWrapper;
@property (nonatomic, strong)UIButton *anonymousButton;
@property (nonatomic, strong)UIButton *personalButton;
@property (nonatomic, strong)UIView *publishWayWrapper;
@property (nonatomic, strong)AKCameraSwitch *allVisibleSwitch;
@property (nonatomic, strong)UIView *allVisibleWrapper;
@property (nonatomic, strong)AKCameraSwitch *shareSwitch;
@property (nonatomic, strong)UIView *shareWrapper;
@end

@implementation AKCameraSaveViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [self layoutViews];
    [self config];
}

#pragma mark - Style
- (void)layoutViews {
    [self setNaviBarTitle:@"视频信息"];
    [self setNaviBarLeftBtnTitle:@"编辑"];
    // 创建一个自定义的按钮，并添加到导航条右侧。
    UIButton *nextButton = [AKCameraNavigationBar createNormalNaviBarBtnByTitle:@"保存" target:self action:@selector(finish:)];
    [self setNaviBarRightBtn:nextButton];
    
    [self.view addSubview:self.contentView];
    
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboardTextView)];
    [self.view addGestureRecognizer:recognizer];
    recognizer.cancelsTouchesInView = NO;  // this prevents the gesture recognizers to 'block' touches
}

- (void)config{
    akTool = (id<AKCameraInternalDelegate>)[AKCameraTool shareInstance];
    
    //设置封面
    self.coverImageView.image = [UIImage imageWithContentsOfFile:[[AKCameraUtils getCoverPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@", kThumbnailExtend, _video.coverFileName]]];
    
    //描述
    if (_video.videoDescription) {
        [self.descriptionTextView setText:_video.videoDescription];
    }
    
    //标签
    if (_video.channel) {
        [self.selectTagButton setTitle:[NSString stringWithFormat:@"#%@#", [_video.channel objectAtIndex:1]] forState:UIControlStateNormal];
    } else {
        [self.selectTagButton setTitle:@"#尚无频道#" forState:UIControlStateNormal];
    }
    
    //匿名
    if ([_video.anonymity intValue] == 0) {
        self.anonymousButton.selected = NO;
        self.personalButton.selected = YES;
    } else {
        self.anonymousButton.selected = YES;
        self.personalButton.selected = NO;
    }
    
    //地理位置
    if (_video.location) {
        [self.locationLabel setText:[NSString stringWithFormat:@"%@ %@", [_video.location objectForKey:@"poiName"],[_video.location objectForKey:@"poiAddress"]]];
    } else {
        [self.locationLabel setText:@"正在获取地理位置..."];
        [self performSelector:@selector(loadLocations) withObject:nil afterDelay:0.5];
    }
}

- (void)loadLocations {
    NSArray *arr = [akTool.delegate akCameraNeedNearbyLocations:_video.location]; // 附近地点
    if ([arr count] > 0) {
        _video.location = [arr objectAtIndex:0];
        [self.locationLabel setText:[NSString stringWithFormat:@"%@ %@", [_video.location objectForKey:@"poiName"],[_video.location objectForKey:@"poiAddress"]]];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // config switchers
    //所有人可见
    if ([_video.access intValue] == 0) {
        [self.allVisibleSwitch setOnWithoutEvent:YES animated:YES];
    }else{
        [self.allVisibleSwitch setOnWithoutEvent:NO animated:YES];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions
- (void)finish:(id)sender {
    if (self.descriptionTextView.text.length > kDescriptionMaxLength) {
        [AKCameraMessageHUD showError:@"字数超过限制！"];
        return;
    }
    
    if (_videoFileUrlBeforeExport) {
        //删除原来的视频文件
        NSFileManager *fm = [[NSFileManager alloc] init];
        BOOL exists = [fm fileExistsAtPath:[_videoFileUrlBeforeExport path]];
        if (exists) {
            [fm removeItemAtURL:_videoFileUrlBeforeExport error:nil];
            //DLog(@"file deleted:%@",_videoFileUrlBeforeExport);
        } else {
            //DLog(@"file not exists:%@",_videoFileUrlBeforeExport);
        }
    }
    [akTool akCameraSaveWillFinish];
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)chooseChannel:(id)sender {
    // Check if channels ready
    AKCameraChannelViewController *controller = [AKCameraChannelViewController shareInstance];
    controller.activeChannel = _video.channel;
    controller.delegate = self;
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)chooseLocation:(id)sender {
    AKCameraLocationViewController *controller = [[AKCameraLocationViewController alloc] init];
    controller.location = _video.location;
    controller.delegate = self;
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)playVideo:(id)sender {
    [self playMovieAtURL:[_video getVideoPath]];
}

#pragma mark - BackButtonHandlerDelegate
- (BOOL)navigationShouldPopOnBackButton{
    if (_videoFileUrlBeforeExport) {
        _video.videoFilePath = _videoFileUrlBeforeExport; //reset to original
    }
    [akTool akCameraSaveWillCancel:NO];
    return YES;
}

#pragma mark - AKChannelSelectDelegate
- (void)viewController:(AKCameraChannelViewController *)viewController didSelectChannel:(NSArray *)channel{
    _video.channel = channel;
    [self.selectTagButton setTitle:[NSString stringWithFormat:@"#%@#", [channel objectAtIndex:1]] forState:UIControlStateNormal];
}

#pragma mark - AKCameraLocationDelegate
-(void)viewController:(AKCameraLocationViewController *)controller didSelectLocation:(NSDictionary *)location{
    _video.location = location;
    self.locationLabel.text = [NSString stringWithFormat:@"%@ %@", [location objectForKey:@"poiName"], [location objectForKey:@"poiAddress"]];
}

#pragma mark textview delegate
#define MAXLENGTH 16

- (void)hideKeyboardTextView{
    [self.descriptionTextView resignFirstResponder];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range
 replacementText:(NSString *)text {
    if ([text isEqualToString:@"\n"]) {
        [textView resignFirstResponder];
        return NO;
    }
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView{
    if (textView.text.length > kDescriptionMaxLength) {
        int l = kDescriptionMaxLength - textView.text.length;
        textView.text = [NSString stringWithFormat:@"%i" ,l];
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView{
    if ([_descriptionTextView.text length] > 0) {
        _video.videoDescription = _descriptionTextView.text;
    } else if (_video.location){
        _video.videoDescription = [NSString stringWithFormat:@"%@ %@ %@", [_video.location objectForKey:@"city"], [_video.location objectForKey:@"poiName"], [_video.location objectForKey:@"poiAddress"]];
    }
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    int count = 4;
    if ([AKCameraStyle hideLocationSelection]) {
        count --;
    }
    if ([AKCameraStyle hidePublishWaySelection]) {
        count --;
    }
    if ([AKCameraStyle hideVisibleSelection]) {
        count --;
    }
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    if (indexPath.row == 0) {
        //first row
        cell = [tableView dequeueReusableCellWithIdentifier:@"firstRow"];
        if (!cell) {
            //create new cell
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"firstRow"];
            [cell setBackgroundColor:[UIColor clearColor]];
            [cell addSubview:self.firstWrapper];
        }
    }else if(indexPath.row == 1){
        //second row
        cell = [tableView dequeueReusableCellWithIdentifier:@"secondRow"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"secondRow"];
            [cell setBackgroundColor:[UIColor clearColor]];
            if ([AKCameraStyle hideLocationSelection]) {
                // check publish way
                if ([AKCameraStyle hidePublishWaySelection]) {
                    // visible
                    [cell addSubview:self.allVisibleWrapper];
                    UIView *fl = [self line];
                    fl.frame = CGRectMake(0, 0, 320, 0.5);
                    [_allVisibleWrapper addSubview:fl];
                } else {
                    // publish way
                    [cell addSubview:self.publishWayWrapper];
                    // add first line
                    UIView *line = [self line];
                    line.frame = Rect(0, 0, 320, 0.5);
                    [_publishWayWrapper addSubview:line];
                    if ([AKCameraStyle hideVisibleSelection]) {
                        line = [_publishWayWrapper viewWithTag:101];
                        CGRect r = line.frame;
                        r.origin.x = 0;
                        r.size.width = 320;
                        line.frame = r;
                    }
                }
            } else {
                [cell addSubview:self.locationWrapper];
            }
        }
    }else if (indexPath.row == 2){
        cell = [tableView dequeueReusableCellWithIdentifier:@"thirdRow"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"thirdRow"];
            [cell setBackgroundColor:[UIColor clearColor]];
            if ([AKCameraStyle hideLocationSelection] || [AKCameraStyle hidePublishWaySelection]) {
                // must be visible
                // visible
                [cell addSubview:self.allVisibleWrapper];
            } else {
                [cell addSubview:self.publishWayWrapper];
                UIView *line = [_publishWayWrapper viewWithTag:101];
                CGRect r = line.frame;
                r.origin.x = 0;
                r.size.width = 320;
                line.frame = r;
            }
        }
    }else if (indexPath.row == 3){
        cell = [tableView dequeueReusableCellWithIdentifier:@"thirdRow"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"thirdRow"];
            [cell setBackgroundColor:[UIColor clearColor]];
            [cell addSubview:self.allVisibleWrapper];
        }
    }/*else if (indexPath.row == 4){
        cell = [tableView dequeueReusableCellWithIdentifier:@"thirdRow"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"thirdRow"];
            [cell setBackgroundColor:[UIColor clearColor]];
            //[cell addSubview:self.shareWrapper]; //no share wrapper
        }
    }
      */
    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    CGSize s = tableView.contentSize;
    if (indexPath.row == 0) {
        s.height = cell.frame.size.height;
    } else {
        s.height += cell.frame.size.height;
    }
    tableView.contentSize = s;
    return cell;
}

#pragma mark - TableViewDelegate Methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    CGFloat height = 0;
    if (indexPath.row == 0) {
        height = self.firstWrapper.frame.size.height;
    }else if(indexPath.row == 1){
        height = self.locationWrapper.frame.size.height;
    }else if (indexPath.row == 2){
        height = self.publishWayWrapper.frame.size.height;
    }else if (indexPath.row == 3){
        height = self.allVisibleWrapper.frame.size.height;
    }else if (indexPath.row == 4){
        height = self.shareWrapper.frame.size.height;
    }
    return height;
}

#pragma mark - Utils
- (void)playMovieAtURL:(NSURL*)theURL
{
    MPMoviePlayerViewController *playerView = [[MPMoviePlayerViewController alloc] initWithContentURL:theURL];
    playerView.view.frame = self.view.frame;//全屏播放（全屏播放不可缺）
    playerView.moviePlayer.scalingMode = MPMovieScalingModeAspectFit;//全屏播放（全屏播放不可缺）
    playerView.moviePlayer.shouldAutoplay= NO;
    [playerView.moviePlayer play];
    [self presentMoviePlayerViewControllerAnimated:playerView];
}

#pragma mark - Getters
@synthesize contentView = _contentView;
- (UITableView *)contentView{
    if (!_contentView) {
        //table view
        CGRect r = self.view.bounds;
        if ([ [ [ UIDevice currentDevice ] systemVersion ] floatValue ] >= 7.0) {
            r.origin.y += 44;
            r.size.height -= 44;
        }
        _contentView = [[UITableView alloc] initWithFrame:r];
        [_contentView setBackgroundColor:[UIColor clearColor]];
        _contentView.dataSource = self;
        _contentView.delegate = self;
        _contentView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    return _contentView;
}

@synthesize coverImageView = _coverImageView, playButton = _playButton, descriptionTextView = _descriptionTextView, selectTagButton = _selectTagButton, firstWrapper = _firstWrapper;
- (UIImageView *)coverImageView{
    if (!_coverImageView) {
        _coverImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        _coverImageView.contentMode = UIViewContentModeScaleAspectFill;
        _coverImageView.layer.masksToBounds = YES;
    }
    return _coverImageView;
}

- (UIButton *)playButton{
    if (!_playButton) {
        _playButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *image = [UIImage imageNamed:@"AKCamera.bundle/play_icon_38"];
        _playButton.frame = CGRectMake(0, 0, image.size.width, image.size.height);
        [_playButton setImage:image forState:UIControlStateNormal];
        [_playButton addTarget:self action:@selector(playVideo:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _playButton;
}

- (AKCameraTextView *)descriptionTextView{
    if (!_descriptionTextView) {
        _descriptionTextView = [[AKCameraTextView alloc] initWithFrame:CGRectMake(0, 0, 210, 83)];
        _descriptionTextView.font = [UIFont systemFontOfSize:14];
        _descriptionTextView.backgroundColor = [UIColor clearColor];
        _descriptionTextView.editable = YES;
        _descriptionTextView.delegate = self;
        _descriptionTextView.placeholder = @"亲，说几句呗";
        _descriptionTextView.returnKeyType = UIReturnKeyDone;
    }
    return _descriptionTextView;
}

- (UIButton *)selectTagButton{
    if (!_selectTagButton) {
        _selectTagButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _selectTagButton.tintColor = [AKCameraStyle colorForHightlight];
        [_selectTagButton setTitleColor:[AKCameraStyle colorForHightlight] forState:UIControlStateNormal];;
        _selectTagButton.titleLabel.font = [UIFont systemFontOfSize:14];
        [_selectTagButton addTarget:self action:@selector(chooseChannel:) forControlEvents:UIControlEventTouchUpInside];
        [self setSelectTagButtonTitle:@"#选择频道#"];
    }
    return _selectTagButton;
}

- (void)setSelectTagButtonTitle:(NSString *)title{
    UILabel *l = [[UILabel alloc] init];
    l.text = title;
    l.font = _selectTagButton.titleLabel.font;
    [l sizeToFit];
    [_selectTagButton setTitle:title forState:UIControlStateNormal];
    CGRect r = _selectTagButton.frame;
    r.size.width = l.frame.size.width + 6;
    r.size.height = l.frame.size.height + 6;
    _selectTagButton.frame = r;
    _selectTagButton.frame = CGRectMake(0, 0,  l.frame.size.width + 6, l.frame.size.height+6);
}

- (UIView *)firstWrapper{
    if (!_firstWrapper) {
        _firstWrapper = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 155)];
        _firstWrapper.backgroundColor = [UIColor clearColor];
        UIView *bkView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 120)];
        bkView.backgroundColor = [UIColor whiteColor];
        UIView *firsetLine = [self line];
        firsetLine.frame = CGRectMake(0, 0, 320, 0.5);
        [bkView addSubview:firsetLine];
        
        UIView *line = [self line];
        line.frame = CGRectMake(0, bkView.frame.size.height - 0.5, 320, 0.5);
        [bkView addSubview:line];
        
        [_firstWrapper addSubview:bkView];
        CGRect r = self.coverImageView.frame;
        r.origin.x = 10;
        r.origin.y = 10;
        self.coverImageView.frame = r;
        [_firstWrapper addSubview:self.coverImageView];
        //playbutton
        r = self.playButton.frame;
        r.origin.x = self.coverImageView.frame.origin.x + (self.coverImageView.frame.size.width - r.size.width) / 2;
        r.origin.y = self.coverImageView.frame.origin.y + (self.coverImageView.frame.size.height - r.size.height) / 2;
        self.playButton.frame = r;
        [_firstWrapper addSubview:self.playButton];
        //textview
        r = self.descriptionTextView.frame;
        r.origin.x = self.coverImageView.frame.origin.x + self.coverImageView.frame.size.width + 10;
        r.origin.y = self.coverImageView.frame.origin.y;
        self.descriptionTextView.frame = r;
        [_firstWrapper addSubview:self.descriptionTextView];
        //tag
        if (![AKCameraStyle hideChannelSelection]) {
            r = self.selectTagButton.frame;
            r.origin.x = 320 - r.size.width - 10;
            r.origin.y = bkView.frame.size.height + 3;
            self.selectTagButton.frame = r;
            [_firstWrapper addSubview:self.selectTagButton];
        }
    }
    return _firstWrapper;
}

- (UIView *)line{
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(14, 43.5, 320 - 14, .5)];
    line.backgroundColor = [AKCameraStyle colorForSeperator];
    return line;
}

@synthesize locationButton = _locationButton, locationLabel = _locationLabel, locationWrapper = _locationWrapper;

- (UIButton *)locationButton{
    if (!_locationButton) {
        _locationButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _locationButton.frame = CGRectMake(0, 0, 320, 44);
        [_locationButton addTarget:self action:@selector(chooseLocation:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _locationButton;
}

- (UILabel *)locationLabel{
    if (!_locationLabel) {
        _locationLabel = [[UILabel alloc] init];
        _locationLabel.backgroundColor = [UIColor clearColor];
        _locationLabel.font = [UIFont systemFontOfSize:13];
        _locationLabel.frame = CGRectMake(0, 0, 268, 30);
        _locationLabel.text = @"点击选择地理位置";
        _locationLabel.textColor = [AKCameraStyle colorForHightlight];
    }
    return _locationLabel;
}

- (UIView *)locationWrapper{
    if (!_locationWrapper) {
        _locationWrapper = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
        _locationWrapper.backgroundColor = [UIColor whiteColor];
        [_locationWrapper addSubview:self.locationButton];
        CGRect r = self.locationLabel.frame;
        r.origin.x = 14;
        r.origin.y = (44 - r.size.height) / 2;
        self.locationLabel.frame = r;
        [_locationWrapper addSubview:self.locationLabel];
        UIImage *arrow = [UIImage imageNamed:@"arrow"];
        UIImageView *arrowView = [[UIImageView alloc] initWithImage:arrow];
        r = arrowView.frame;
        r.origin.x = 320 - r.size.width - 14;
        r.origin.y = (44 -r.size.height) / 2;
        arrowView.frame = r;
        [_locationWrapper addSubview:arrowView];
        [_locationWrapper addSubview:[self line]];
        UIView *fl = [self line];
        fl.frame = CGRectMake(0, 0, 320, 0.5);
        [_locationWrapper addSubview:fl];
    }
    return _locationWrapper;
}

@synthesize anonymousButton = _anonymousButton, personalButton = _personalButton, publishWayWrapper = _publishWayWrapper;

- (UIButton *)anonymousButton{
    if (!_anonymousButton) {
        _anonymousButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *image = [UIImage imageNamed:@"AKCamera.bundle/segmented_radio_left_n"];
        _anonymousButton.frame = CGRectMake(0, 0, image.size.width, image.size.height);
        [_anonymousButton setBackgroundImage:image forState:UIControlStateNormal];
        UIImage *himage = [UIImage imageNamed:@"AKCamera.bundle/segmented_radio_left_h"];
        [_anonymousButton setBackgroundImage:himage forState:UIControlStateHighlighted];
        [_anonymousButton setBackgroundImage:himage forState:UIControlStateSelected];
        _anonymousButton.titleLabel.font = [UIFont systemFontOfSize:14];
        [_anonymousButton setTitle:@"匿名" forState:UIControlStateNormal];
        [_anonymousButton setTitleColor:[AKCameraStyle colorForHightlight] forState:UIControlStateNormal];
        [_anonymousButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
        [_anonymousButton setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
        [_anonymousButton addTarget:self action:@selector(publishWayChanged:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _anonymousButton;
}

- (UIButton *)personalButton{
    if (!_personalButton) {
        _personalButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *image = [UIImage imageNamed:@"AKCamera.bundle/segmented_radio_right_n"];
        _personalButton.frame = CGRectMake(0, 0, image.size.width, image.size.height);
        [_personalButton setBackgroundImage:image forState:UIControlStateNormal];
        UIImage *himage = [UIImage imageNamed:@"AKCamera.bundle/segmented_radio_right_h"];
        [_personalButton setBackgroundImage:himage forState:UIControlStateHighlighted];
        [_personalButton setBackgroundImage:himage forState:UIControlStateSelected];
        _personalButton.titleLabel.font = [UIFont systemFontOfSize:14];
        [_personalButton setTitle:@"个人" forState:UIControlStateNormal];
        [_personalButton setTitleColor:[AKCameraStyle colorForHightlight] forState:UIControlStateNormal];
        [_personalButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
        [_personalButton setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
        [_personalButton addTarget:self action:@selector(publishWayChanged:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _personalButton;
}

- (UIView *)publishWayWrapper{
    if (!_publishWayWrapper) {
        _publishWayWrapper = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
        _publishWayWrapper.backgroundColor = [UIColor whiteColor];
        UILabel *l = [[UILabel alloc] init];
        l.backgroundColor = [UIColor clearColor];
        l.font = [UIFont systemFontOfSize:14];
        l.textColor = [UIColor lightGrayColor];
        l.text = @"发布方式";
        [l sizeToFit];
        CGRect r = l.frame;
        r.origin.x = 14;
        r.origin.y = (44 - r.size.height) / 2;
        l.frame = r;
        [_publishWayWrapper addSubview:l];
        r = self.anonymousButton.frame;
        r.origin.x = 320 - 14 - r.size.width * 2;
        r.origin.y = (44 - r.size.height) / 2;
        self.anonymousButton.frame = r;
        [_publishWayWrapper addSubview:self.anonymousButton];
        r = self.personalButton.frame;
        r.origin.x = self.anonymousButton.frame.origin.x + self.anonymousButton.frame.size.width;
        r.origin.y = self.anonymousButton.frame.origin.y;
        self.personalButton.frame = r;
        [_publishWayWrapper addSubview:self.personalButton];
        UIView *line = [self line];
        line.tag = 101;
        [_publishWayWrapper addSubview:line];
    }
    return _publishWayWrapper;
}

- (void)publishWayChanged:(UIButton *)sender{
    if ([sender isEqual:self.anonymousButton]) {
        self.anonymousButton.selected = YES;
        self.personalButton.selected = NO;
        _video.anonymity = @(1);
    } else {
        self.anonymousButton.selected = NO;
        self.personalButton.selected = YES;
        _video.anonymity = @(0);
    }
}

@synthesize allVisibleSwitch = _allVisibleSwitch, allVisibleWrapper = _allVisibleWrapper;

- (AKCameraSwitch *)allVisibleSwitch{
    if (!_allVisibleSwitch) {
        _allVisibleSwitch = [[AKCameraSwitch alloc] initWithFrame:CGRectMake(0, 0, 51, 31)];
        [_allVisibleSwitch addTarget:self action:@selector(allVisibleValueChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return _allVisibleSwitch;
}

- (UIView *)allVisibleWrapper{
    if (!_allVisibleWrapper) {
        _allVisibleWrapper = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44 + 3 + 32)];
        UIView *bk = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
        bk.backgroundColor = [UIColor whiteColor];
        UIView *fl = [self line];
        fl.tag = 101;
        fl.frame = CGRectMake(0, 43.5, 320, 0.5);
        [bk addSubview:fl];
        [_allVisibleWrapper addSubview:bk];
        _allVisibleWrapper.backgroundColor = [UIColor clearColor];
        UILabel *l = [[UILabel alloc] init];
        l.backgroundColor = [UIColor clearColor];
        l.font = [UIFont systemFontOfSize:14];
        l.textColor = [UIColor lightGrayColor];
        l.text = @"所有人可见";
        [l sizeToFit];
        CGRect r = l.frame;
        r.origin.x = 14;
        r.origin.y = (44 - r.size.height) / 2;
        l.frame = r;
        [_allVisibleWrapper addSubview:l];
        r = self.allVisibleSwitch.frame;
        r.origin.x = 320 - 14 - r.size.width;
        r.origin.y = (44 - r.size.height) / 2;
        self.allVisibleSwitch.frame = r;
        [_allVisibleWrapper addSubview:self.allVisibleSwitch];
        /*
         UILabel *hintLabel = [[UILabel alloc] init];
         hintLabel.font = [UIFont systemFontOfSize:12];
         hintLabel.backgroundColor = [UIColor clearColor];
         hintLabel.textColor = [StyleSheet colorStylec5];
         hintLabel.shadowColor = [UIColor whiteColor];
         hintLabel.shadowOffset = CGSizeMake(0, 1);
         hintLabel.text = @"树洞即匿名发布";
         [hintLabel sizeToFit];
         r = hintLabel.frame;
         r.origin.x = 320 - r.size.width - 14;
         r.origin.y = 6 + 44;
         hintLabel.frame = r;
         
         [_allVisibleWrapper addSubview:hintLabel];
         */
    }
    return _allVisibleWrapper;
}

- (void)allVisibleValueChanged:(AKCameraSwitch *)sender{
    _video.access = sender.on ? @(0) : @(1);
}

@synthesize shareSwitch = _shareSwitch, shareWrapper = _shareWrapper;

- (AKCameraSwitch *)shareSwitch{
    if (!_shareSwitch) {
        _shareSwitch = [[AKCameraSwitch alloc] initWithFrame:CGRectMake(0, 0, 51, 31)];
        [_shareSwitch addTarget:self action:@selector(shareValueChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return _shareSwitch;
}

- (UIView *)shareWrapper{
    if (!_shareWrapper) {
        _shareWrapper = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
        _shareWrapper.backgroundColor = [UIColor whiteColor];
        UILabel *l = [[UILabel alloc] init];
        l.backgroundColor = [UIColor clearColor];
        l.font = [UIFont systemFontOfSize:14];
        l.textColor = [UIColor lightGrayColor];
        l.text = @"分享到新浪微博";
        [l sizeToFit];
        CGRect r = l.frame;
        r.origin.x = 14;
        r.origin.y = (44 - r.size.height) / 2;
        l.frame = r;
        [_shareWrapper addSubview:l];
        r = self.shareSwitch.frame;
        r.origin.x = 320 - 14 - r.size.width;
        r.origin.y = (44 - r.size.height) / 2;
        self.shareSwitch.frame = r;
        [_shareWrapper addSubview:self.shareSwitch];
        [_shareWrapper addSubview:[self line]];
        UIView *fl = [self line];
        fl.frame = CGRectMake(0, 0, 320, 0.5);
        [_shareWrapper addSubview:fl];
    }
    return _shareWrapper;
}

- (void)shareValueChanged:(id)sender{
    //DLog(@"Not support now");
}

@end
