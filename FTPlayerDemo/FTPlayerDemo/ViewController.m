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

    NSString *path = [[NSBundle mainBundle] pathForResource:@"facebook" ofType:@"MP4"];
    NSURL *url = [NSURL fileURLWithPath:path];
    
    url = [NSURL URLWithString:kWebURLString];
    CGRect frame = CGRectMake(0, 20, kScreenWidth, kScreenWidth*9/16.0);
    self.ftPlayer = [[FTPlayer alloc] initWithFrame:frame videoUrl:url];
    [self.view addSubview:self.ftPlayer];
}





@end
