//
//  AKCameraLocationViewController.m
//  TaoVideo
//
//  Created by lihejun on 14-3-18.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraLocationViewController.h"
#import "AKCameraStyle.h"
#import "AKCameraTool.h"
#import "AKCameraMessageHUD.h"

@interface AKCameraLocationViewController ()<UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *contentView;
@property (nonatomic, strong)UILabel *currentSelectedLabel;
@property (nonatomic, strong)UIView *currentSelectedWrapper;
@property (nonatomic, strong)UIView *innerCurrentSelectedWrapper;
@end

@implementation AKCameraLocationViewController

+ (AKCameraLocationViewController *)shareInstance {
    static AKCameraLocationViewController *s_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_instance = [AKCameraLocationViewController new];
    });
    return s_instance;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [self setNaviBarTitle:@"选择地理位置"];
    UIButton *cancelButton = [AKCameraNavigationBar createNormalNaviBarBtnByTitle:@"取消" target:self action:@selector(cancel:)];
    [self setNaviBarLeftBtn:cancelButton];
    [self hideBottomLine];
    
    [self.view addSubview:self.contentView];
    [self.view addSubview:self.currentSelectedWrapper];
    [AKCameraMessageHUD show:@"正在获取地理位置..."];
    [self performSelector:@selector(loadNearLocations) withObject:nil afterDelay:0.5];
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

- (void)loadNearLocations {
    _locations = [[AKCameraTool shareInstance].delegate akCameraNeedNearbyLocations:_location];
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [_contentView reloadData];
        [AKCameraMessageHUD dismiss];
    });
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_locations count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AKLocationCell *cell = [tableView dequeueReusableCellWithIdentifier:@"akLocationCell"];
    if (!cell) {
        cell = [[AKLocationCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"akLocationCell"];
    }
    cell.location = [_locations objectAtIndex:indexPath.row];
    return cell;
}

#pragma mark - TableViewDelegate Methods
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 50;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(_delegate){
        [_delegate viewController:self didSelectLocation:[_locations objectAtIndex:indexPath.row]];
    }
    [self cancel:nil];
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
        r.origin.y += self.currentSelectedWrapper.bounds.size.height;
        r.size.height -= self.currentSelectedWrapper.bounds.size.height;
        
        _contentView = [[UITableView alloc] initWithFrame:r];
        [_contentView setBackgroundColor:[UIColor clearColor]];
        _contentView.dataSource = self;
        _contentView.delegate = self;
        _contentView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    return _contentView;
}
@synthesize currentSelectedLabel = _currentSelectedLabel, currentSelectedWrapper = _currentSelectedWrapper, innerCurrentSelectedWrapper = _innerCurrentSelectedWrapper;
- (UILabel *)currentSelectedLabel{
    if (!_currentSelectedLabel) {
        _currentSelectedLabel = [[UILabel alloc] init];
        _currentSelectedLabel.backgroundColor = [UIColor clearColor];
        _currentSelectedLabel.font = [UIFont systemFontOfSize:13];
        _currentSelectedLabel.frame = CGRectMake(10, 0, 260, 25);
        _currentSelectedLabel.textAlignment = NSTextAlignmentCenter;
        _currentSelectedLabel.textColor = [AKCameraStyle colorForHightlight];
        if (_location) {
             _currentSelectedLabel.text = [NSString stringWithFormat:@"%@ %@", [_location objectForKey:@"poiName"], [_location objectForKey:@"poiAddress"]];
        } else {
            _currentSelectedLabel.text = @"未选择地理位置";
        }
        
    }
    return _currentSelectedLabel;
}
- (UIView *)currentSelectedWrapper{
    if (!_currentSelectedWrapper) {
        CGFloat y = 0;
        BOOL iosNewerThan7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
        if (iosNewerThan7) {
            y += 20 + 44;
        }
        _currentSelectedWrapper = [[UIView alloc] initWithFrame:CGRectMake(0, y, 320, 30)];
        _currentSelectedWrapper.backgroundColor = [AKCameraStyle colorForNavigationBar];
        _innerCurrentSelectedWrapper = [[UIView alloc] initWithFrame:CGRectMake((320 - 280) / 2, 0, 280, 25)];
        _innerCurrentSelectedWrapper.layer.cornerRadius = 3;
        _innerCurrentSelectedWrapper.layer.masksToBounds = YES;
        _innerCurrentSelectedWrapper.backgroundColor = [UIColor colorWithRed:240/255.0f green:240/255.0f blue:240/255.0f alpha:1];
        [_currentSelectedWrapper addSubview:_innerCurrentSelectedWrapper];
        [_innerCurrentSelectedWrapper addSubview:self.currentSelectedLabel];
        //UIView *topLine = [StyleSheet lineForTopCell:_currentSelectedWrapper];
        //topLine.frame = CGRectMake((320 - 80) / 2, 0, 80, 0.5);
        //[_currentSelectedWrapper addSubview:topLine];
        UIView *line = [AKCameraStyle lineForEndCell:_currentSelectedWrapper];
        if (!iosNewerThan7) {
            CGRect r = line.frame;
            r.origin.y += 6;
            line.frame = r;
        }
        [_currentSelectedWrapper addSubview:line];
    }
    return _currentSelectedWrapper;
}

#pragma mark - Setters
- (void)setLocations:(NSArray *)locations {
    _locations = locations;
    [self.contentView reloadData];
}

@end

@interface AKLocationCell()
@property (strong, nonatomic)UILabel *buildingLabel;
@property (strong, nonatomic)UILabel *districtLabel;
@end

@implementation AKLocationCell

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
    [self addSubview:self.buildingLabel];
    [self addSubview:self.districtLabel];
    [self addSubview:[AKCameraStyle lineForMiddleCell:self]];
}

#pragma mark - Setters
- (void)setLocation:(NSDictionary *)location {
    _location = location;
    if (_location) {
        _buildingLabel.text = [_location objectForKey:@"poiName"];
        _districtLabel.text = [NSString stringWithFormat:@"%@ %@", [_location objectForKey:@"city"],[_location objectForKey:@"district"]];
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    // Configure the view for the selected state
    if (selected) {
        _buildingLabel.textColor = [AKCameraStyle colorForHightlight];
        _districtLabel.textColor = [AKCameraStyle colorForHightlight];
    } else {
        _buildingLabel.textColor = [UIColor darkGrayColor];
        _districtLabel.textColor = [UIColor lightGrayColor];
    }
    
}

#pragma mark - Getters
- (UILabel *)buildingLabel {
    if (!_buildingLabel) {
        _buildingLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 9, 285, 15)];
        _buildingLabel.backgroundColor = [UIColor clearColor];
        _buildingLabel.font = [UIFont systemFontOfSize:15.0f];
        _buildingLabel.textColor = [UIColor darkGrayColor];
    }
    return _buildingLabel;
}

- (UILabel *)districtLabel {
    if (!_districtLabel) {
        _districtLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 29, 292, 12)];
        _districtLabel.backgroundColor = [UIColor clearColor];
        _districtLabel.font = [UIFont systemFontOfSize:12.0f];
        _districtLabel.textColor = [UIColor lightGrayColor];
    }
    return _districtLabel;
}
@end
