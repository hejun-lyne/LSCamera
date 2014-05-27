//
//  AKCameraChannelViewController.m
//  TaoVideo
//
//  Created by lihejun on 14-3-18.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraChannelViewController.h"
#import "AKCameraTool.h"
#import "AKCameraMessageHUD.h"
#import "AKCameraNavigationBar.h"

@interface AKCameraChannelViewController ()<UITableViewDelegate, UITableViewDataSource>
{
    NSArray *_channels;
}
@property (nonatomic, strong) UITableView *contentView;
@end

@implementation AKCameraChannelViewController

+ (AKCameraChannelViewController *)shareInstance {
    static AKCameraChannelViewController *s_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_instance = [self new];
    });
    return s_instance;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [self setNaviBarTitle:@"选择频道"];
    UIButton *cancelButton = [AKCameraNavigationBar createNormalNaviBarBtnByTitle:@"取消" target:self action:@selector(cancel:)];
    [self setNaviBarLeftBtn:cancelButton];
    
    // Content view
    [self.view addSubview:self.contentView];
    
    [AKCameraMessageHUD show:@"正在获取所有频道..."];
    [self performSelector:@selector(loadChannels) withObject:nil afterDelay:0.5];
}

- (void)loadChannels {
    _channels = [[AKCameraTool shareInstance].delegate akCameraNeedChannels];
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [_contentView reloadData];
        [AKCameraMessageHUD dismiss];
    });
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions
- (void)cancel:(id)sender{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_channels count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AKChannelCell *cell = [tableView dequeueReusableCellWithIdentifier:@"akChannelCell"];
    if (!cell) {
        cell = [[AKChannelCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"akChannelCell"];
    }
    cell.channel = [_channels objectAtIndex:indexPath.row];
    if (_activeChannel && [[cell.channel objectAtIndex:0] intValue] == [[_activeChannel objectAtIndex:0] intValue]) {
        [cell setSelected:YES animated:NO];
    }
    return cell;
}

#pragma mark - TableViewDelegate Methods
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 50;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if(_delegate){
        [_delegate viewController:self didSelectChannel:[_channels objectAtIndex:indexPath.row]];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Getters
- (UITableView *)contentView{
    if (!_contentView) {
        //table view
        CGRect r = self.view.frame;
        if ([ [ [ UIDevice currentDevice ] systemVersion ] floatValue ] >= 7.0) {
            r.origin.y += 20;
            r.size.height -= 20;
        }
        r.origin.y += 44;
        r.size.height -= 44;
        _contentView = [[UITableView alloc] initWithFrame:r];
        [_contentView setBackgroundColor:[UIColor clearColor]];
        _contentView.dataSource = self;
        _contentView.delegate = self;
        _contentView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    return _contentView;
}

@end

@interface AKChannelCell()
@property (nonatomic, strong)UILabel *nameLabel;
@property (nonatomic, strong)UILabel *countLabel;
@end

@implementation AKChannelCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        [self config];
    }
    return self;
}

- (void)config {
    CGRect r = self.frame;
    r.size.height = 50.0f;
    self.frame = r;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    [self addSubview:self.nameLabel];
    [self addSubview:self.countLabel];
    [self addSubview:[AKCameraStyle lineForMiddleCell:self]];
}

#pragma mark - Setters
- (void)setChannel:(NSArray *)channel {
    _channel = channel;
    if (_channel) {
        _nameLabel.text = [channel objectAtIndex:1];
        if ([_channel count] > 3) {
            _countLabel.text = [NSString stringWithFormat:@"%d 视频",[[_channel objectAtIndex:2] intValue]];
        }
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    // Configure the view for the selected state
    if (selected) {
        _nameLabel.textColor = [AKCameraStyle colorForHightlight];
        _countLabel.textColor = [AKCameraStyle colorForHightlight];
    } else {
        _nameLabel.textColor = [UIColor darkGrayColor];
        _countLabel.textColor = [UIColor lightGrayColor];
    }
    
}

#pragma mark - Getters
- (UILabel *)nameLabel {
    if (!_nameLabel) {
        _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 17, 181, 16)];
        _nameLabel.backgroundColor = [UIColor clearColor];
        _nameLabel.font = [UIFont systemFontOfSize:16.0f];
        _nameLabel.textAlignment = NSTextAlignmentLeft;
        _nameLabel.textColor = [UIColor darkGrayColor];
    }
    return _nameLabel;
}

- (UILabel *)countLabel {
    if (!_countLabel) {
        _countLabel = [[UILabel alloc] initWithFrame:CGRectMake(209, 17, 91, 16)];
        _countLabel.backgroundColor = [UIColor clearColor];
        _countLabel.font = [UIFont systemFontOfSize:14.0f];
        _countLabel.textAlignment = NSTextAlignmentRight;
        _countLabel.textColor = [UIColor lightGrayColor];
    }
    return _countLabel;
}

@end
