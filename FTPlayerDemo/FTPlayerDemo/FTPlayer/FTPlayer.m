//
//  FTPlayer.m
//  PlayVideoAndAudio
//
//  Created by aoni on 2018/6/5.
//  Copyright © 2018年 cft. All rights reserved.
//

#import "FTPlayer.h"
#import "Masonry.h"

#define kObserveKeyStatus                   @"status"
#define kObserveKeyLoadedTimeRanges         @"loadedTimeRanges"
#define kObserveKeyPlaybackBufferEmpty      @"playbackBufferEmpty"
#define kObserveKeyPlaybackLikelyToKeepUp   @"playbackLikelyToKeepUp"
#define kObserveKeyduration                 @"duration"

#define FTPlayerPath(file) [@"FTPlayer.bundle" stringByAppendingPathComponent:file]
#define FTPlayerImage(file) [UIImage imageNamed:FTPlayerPath(file)]

static void *PlayViewStatusObservationContext = &PlayViewStatusObservationContext;

@interface FTPlayer()


@property (strong, nonatomic) AVPlayerItem *playerItem;
@property (strong, nonatomic) AVPlayerLayer *playerLayer;
@property (strong, nonatomic) UIView *videoLayer;

@property (nonatomic, assign) BOOL isPlaying;

@property (nonatomic, strong) NSURL *url;


@property (assign, nonatomic) CGFloat videoPlaybackPosition; //视频回放位置

@property (nonatomic, strong) UIButton  *midPlayButton;

@property (nonatomic, assign) CGFloat totalTime; //总时长，秒

//监听播放起状态的监听者
@property (nonatomic ,strong) id playbackTimeObserver;

// UI control


@property (nonatomic, strong) UIView  *contentView;
@property (nonatomic, strong) UIImageView  *bottomView;
@property (nonatomic, strong) UIImageView  *topView;

// 进度条滑块
@property (nonatomic, strong) UISlider  *progressSlider;
//当前时间
@property (nonatomic, strong) UILabel  *currentTimeLabel;
//总时间
@property (nonatomic, strong) UILabel  *totalTimeLabel;
// 播放，暂停按钮
@property (nonatomic, strong) UIButton  *playBtn;



@end

@implementation FTPlayer

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
}

- (instancetype)initWithFrame:(CGRect)frame videoUrl:(NSURL *)url{
    self = [super initWithFrame:frame];
    if (self) {
        self.url = url;
        self.backgroundColor = [UIColor whiteColor];
        [self addViews];
    }
    return self;
}

- (void)addViews{
    
    [self addPlayer];
    [self addPlayButton];
    [self addNotification];
    [self addStatusObserve];
}

- (void)addNotification{
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(moviePlayDidEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
}

- (void)moviePlayDidEnd:(NSNotification *)notification {
    if (self.delegate && [self.delegate respondsToSelector:@selector(playerDidPlayToEnd:)]) {
        [self.delegate playerDidPlayToEnd:self];
    }
    [self.player seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
        if (finished) {
            NSLog(@"cft-play finished-------");
            [self pauseVideo];
        }
    }];
}

- (void)addStatusObserve{
    // 状态
    [_playerItem addObserver:self forKeyPath:kObserveKeyStatus options:NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];
    //不断加载缓存
    [_playerItem addObserver:self forKeyPath:kObserveKeyLoadedTimeRanges options:NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];
    //缓存区空了，不断获取缓冲进度
    [_playerItem addObserver:self forKeyPath:kObserveKeyPlaybackBufferEmpty options:NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];
    //缓存区数据足够了
    [_playerItem addObserver:self forKeyPath:kObserveKeyPlaybackLikelyToKeepUp options:NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];
    // 时长
    [_playerItem addObserver:self forKeyPath:kObserveKeyduration options:NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if (context == PlayViewStatusObservationContext) {
        if ([keyPath isEqualToString:kObserveKeyStatus]) {
            AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
            [self playerStatusChangedWithStatus:status];
        }
        else if ([keyPath isEqualToString:kObserveKeyLoadedTimeRanges]){// 会不断调用,不断获取缓冲进度
            NSLog(@"cft-kObserveKeyLoadedTimeRanges---");
        }
        else if ([keyPath isEqualToString:kObserveKeyPlaybackBufferEmpty]){//缓存空
            NSLog(@"cft-kObserveKeyPlaybackBufferEmpty---");
        }
        else if ([keyPath isEqualToString:kObserveKeyPlaybackLikelyToKeepUp]){// 当缓冲好的时候
            NSLog(@"cft-kObserveKeyPlaybackLikelyToKeepUp---");
        }
        else if ([keyPath isEqualToString:kObserveKeyduration]){//获取到时长
            _totalTime = (CGFloat)CMTimeGetSeconds(_playerItem.duration);
            NSLog(@"cft-totalTime:%f",_totalTime);
        }
    }
}

//status变化处理
- (void)playerStatusChangedWithStatus:(AVPlayerStatus)status{
    NSLog(@"cft-status:%ld",status);
    switch (status) {
        case AVPlayerStatusUnknown:{//刚开始的状态，还没有开始加载数据
            NSLog(@"cft-AVPlayerStatusUnknown");
            break;
        }
        case AVPlayerStatusReadyToPlay:{//准备播放
            NSLog(@"cft-AVPlayerStatusReadyToPlay");
            [self initTimer];
            break;
        }
        case AVPlayerStatusFailed:{//加载失败
            NSLog(@"cft-AVPlayerStatusFailed");
            break;
        }
            
        default:
            break;
    }
}

#pragma  mark - 定时器
-(void)initTimer{
    //多久调用一次，决定了多久刷新一次进度条
    CMTime interval = CMTimeMakeWithSeconds(1.0, NSEC_PER_SEC);
    __weak typeof(self) weakSelf = self;
    self.playbackTimeObserver = [self.player addPeriodicTimeObserverForInterval:interval queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        [weakSelf updateProgress];
    }];
}

//更新进度条
- (void)updateProgress{
    NSLog(@"cft-updateProgress---");
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration)){
        self.progressSlider.minimumValue = 0.0;
        return;
    }
    long long nowTime = _playerItem.currentTime.value*1000/_playerItem.currentTime.timescale;
    NSLog(@"cft-nowTime:%lld %f",nowTime/1000,_totalTime);
}

#pragma mark - getter
- (CMTime)playerItemDuration{
    AVPlayerItem *playerItem = _playerItem;
    if (playerItem.status == AVPlayerItemStatusReadyToPlay){
        return([playerItem duration]);
    }
    return(kCMTimeInvalid);
}


- (void)addPlayer{
    self.videoLayer = [[UIView alloc] init];
    self.videoLayer.frame = CGRectMake(0, 0, kScreenWidth, kScreenWidth*9/16.0);
    [self addSubview:self.videoLayer];
    self.videoLayer.backgroundColor = [UIColor blackColor];
    //播放器相关
    
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:self.url];
    self.playerItem = item;
    
    self.player = [AVPlayer playerWithPlayerItem:item];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.contentsGravity = AVLayerVideoGravityResizeAspect;
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    [self.videoLayer.layer addSublayer:self.playerLayer];
    self.playerLayer.frame = self.videoLayer.frame;
    [self.player play];
    self.isPlaying = YES;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapOnVideoLayer:)];
    [self.videoLayer addGestureRecognizer:tap];
}

- (void)addPlayButton{
    [self.videoLayer addSubview:self.midPlayButton];
    [self.midPlayButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.centerY.equalTo(self.videoLayer);
        make.width.height.mas_equalTo(60);
    }];
    [self.videoLayer sendSubviewToBack:self.midPlayButton];
}

- (void)seekVideoToPos:(CGFloat)pos{
    CMTime time = CMTimeMakeWithSeconds(pos, self.player.currentTime.timescale);
    [self.player seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}


#pragma mark - click event
#pragma mark - play or pause
- (void)tapOnVideoLayer:(UITapGestureRecognizer *)tap{
    if (self.isPlaying) {
        [self pauseVideo];
    }
    else {
        [self playVideo];
    }
}

- (void)restartPlay{
    [self seekVideoToPos:0];
    [self playVideo];
}

- (void)pauseVideo{
    if (self.delegate && [self.delegate respondsToSelector:@selector(playerDidPaused:)]) {
        [self.delegate playerDidPaused:self];
    }
    [self pausePlayVideo];
}

- (void)pausePlayVideo{
    [self.player pause];
    [self.videoLayer bringSubviewToFront:self.midPlayButton];
    self.isPlaying = false;
}

- (void)playVideo{
    [self midPlayButtonEvent:nil];
}

#pragma mark - ---------------------------------- event handle -----------------------------------

- (void)midPlayButtonEvent:(UIButton *)btn{
    if (!self.isPlaying) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(playerDidPlayed:)]) {
            [self.delegate playerDidPlayed:self];
        }
        [self.player play];
        [self.videoLayer sendSubviewToBack:self.midPlayButton];
        self.isPlaying = true;
    }
}

#pragma mark - ---------------------------------- UI init -----------------------------------
- (UIButton *)midPlayButton{
    if (!_midPlayButton) {
        _midPlayButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_midPlayButton setImage:FTPlayerImage(@"play") forState:UIControlStateNormal];
        [_midPlayButton addTarget:self action:@selector(midPlayButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _midPlayButton;
}

- (UIView *)contentView{
    if (!_contentView) {
        _contentView = [[UIView alloc] init];
        _contentView.backgroundColor = [UIColor clearColor];
    }
    return _contentView;
}

- (UIImageView *)bottomView{
    if (!_bottomView) {
        _bottomView = [[UIImageView alloc] init];
        _bottomView.image = FTPlayerImage(@"bottom_shadow");
    }
    return _bottomView;
}

- (UIImageView *)topView{
    if (!_topView) {
        _topView = [[UIImageView alloc] init];
        _topView.image = FTPlayerImage(@"top_shadow");
    }
    return _topView;
}

@end
