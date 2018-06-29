//
//  FTPlayer.h
//  PlayVideoAndAudio
//
//  Created by aoni on 2018/6/5.
//  Copyright © 2018年 cft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#define kScreenHeight  [[UIScreen mainScreen] bounds].size.height
#define kScreenWidth   [[UIScreen mainScreen] bounds].size.width

#ifdef MyLog
#define FTLog(fmt, ...) NSLog((fmt), ##__VA_ARGS__);
#else
# define FTLog(...);
#endif

@class FTPlayer;
@protocol FTPlayerDelegate <NSObject>

- (void)playerDidPlayToEnd:(FTPlayer *)player;

- (void)playerDidPaused:(FTPlayer *)player;

- (void)playerDidPlayed:(FTPlayer *)player;

@end

@interface FTPlayer : UIView

@property (strong, nonatomic) AVPlayer *player;

@property (nonatomic, strong) UIImage  *placehoderImage;


- (instancetype)initWithFrame:(CGRect)frame videoUrl:(NSURL *)url;

// 暂停播放
- (void)pausePlayVideo;

// 开始播放
- (void)playVideo;

- (void)restartPlay;


@property (nonatomic, weak) id<FTPlayerDelegate>delegate;

@end
