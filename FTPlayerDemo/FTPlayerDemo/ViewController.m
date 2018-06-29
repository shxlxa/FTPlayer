//
//  ViewController.m
//  FTPlayerDemo
//
//  Created by aoni on 2018/6/25.
//  Copyright © 2018年 cft. All rights reserved.
//

#import "ViewController.h"
#import "FTPlayer.h"

#define kWebURLString @"http://flv3.bn.netease.com/tvmrepo/2018/6/H/9/EDJTRBEH9/SD/EDJTRBEH9-mobile.mp4"

@interface ViewController ()

@property (nonatomic, strong) FTPlayer *ftPlayer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSString *URLString = @"http://flv3.bn.netease.com/tvmrepo/2018/6/M/B/EDJTRBCMB/SD/EDJTRBCMB-mobile.mp4";
    NSURL *url = [NSURL URLWithString:URLString];
    CGRect frame = CGRectMake(0, 20, kScreenWidth, kScreenWidth*9/16.0);
    self.ftPlayer = [[FTPlayer alloc] initWithFrame:frame videoUrl:url];
    self.ftPlayer.placehoderImage = [UIImage imageNamed:@"timg.jpeg"];
    [self.view addSubview:self.ftPlayer];
}





@end
