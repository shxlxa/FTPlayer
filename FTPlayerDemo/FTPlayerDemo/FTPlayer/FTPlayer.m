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

@property (nonatomic, assign) CGFloat totalTime; //总时长，秒

//监听播放起状态的监听者
@property (nonatomic ,strong) id playbackTimeObserver;

/**
 *  定时器
 */
@property (nonatomic, retain) NSTimer        *autoDismissTimer;

@property (nonatomic, strong) NSDateFormatter  *dateFormatter;

//进度条是否在滑动
@property (nonatomic, assign) BOOL isSliderDragging;

// UI control


@property (nonatomic, strong) UIView  *contentView;
@property (nonatomic, strong) UIImageView  *bottomView;
@property (nonatomic, strong) UIImageView  *topView;

// 进度条滑块
@property (nonatomic, strong) UISlider  *progressSlider;
//显示缓冲进度
@property (nonatomic,strong) UIProgressView *loadingProgress;
//当前时间
@property (nonatomic, strong) UILabel  *currentTimeLabel;
//总时间
@property (nonatomic, strong) UILabel  *totalTimeLabel;
// 播放，暂停按钮
@property (nonatomic, strong) UIButton  *playBtn;

@property (nonatomic, strong) UIButton  *fullScreenBtn;

//菊花（加载框）
@property (nonatomic,strong) UIActivityIndicatorView *loadingView;

@property (nonatomic, strong) UITapGestureRecognizer *singleTap;

@property (nonatomic, strong) UITapGestureRecognizer  *doubleTap;

@end

@implementation FTPlayer

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_playerItem removeObserver:self forKeyPath:kObserveKeyStatus];
    [_playerItem removeObserver:self forKeyPath:kObserveKeyLoadedTimeRanges];
    [_playerItem removeObserver:self forKeyPath:kObserveKeyPlaybackBufferEmpty];
    [_playerItem removeObserver:self forKeyPath:kObserveKeyPlaybackLikelyToKeepUp];
    [_playerItem removeObserver:self forKeyPath:kObserveKeyduration];
    
    [self.player removeTimeObserver:self.playbackTimeObserver];
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
    
    [self initViews];
    [self addPlayer];
    [self addNotification];
    [self addStatusObserve];
}

- (void)addNotification{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayDidEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
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

#pragma mark 进入后台
- (void)appDidEnterBackground:(NSNotification*)note{
    NSLog(@"cft-进入后台--");
    if (self.playBtn.isSelected==NO) {//如果是播放中，则继续播放
        NSArray *tracks = [self.playerItem tracks];
        for (AVPlayerItemTrack *playerItemTrack in tracks) {
            if ([playerItemTrack.assetTrack hasMediaCharacteristic:AVMediaCharacteristicVisual]) {
                playerItemTrack.enabled = YES;
            }
        }
        self.playerLayer.player = nil;
        [self.player play];
    }
}
#pragma mark
#pragma mark 进入前台
- (void)appWillEnterForeground:(NSNotification*)note{
    if (self.playBtn.isSelected==NO) {//如果是播放中，则继续播放
        NSArray *tracks = [self.playerItem tracks];
        for (AVPlayerItemTrack *playerItemTrack in tracks) {
            if ([playerItemTrack.assetTrack hasMediaCharacteristic:AVMediaCharacteristicVisual]) {
                playerItemTrack.enabled = YES;
            }
        }
        self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        self.playerLayer.frame = self.contentView.bounds;
        self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        [self.contentView.layer insertSublayer:_playerLayer atIndex:0];
        [self.player play];
    }
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
            NSLog(@"cft-正在缓冲---");
            // 计算缓冲进度
            NSTimeInterval timeInterval = [self availableDuration];
            CMTime duration             = self.playerItem.duration;
            CGFloat totalDuration       = CMTimeGetSeconds(duration);
            [self.loadingProgress setProgress:timeInterval / totalDuration animated:NO];
        }
        else if ([keyPath isEqualToString:kObserveKeyPlaybackBufferEmpty]){//缓存空
            NSLog(@"cft-kObserveKeyPlaybackBufferEmpty---");
            if (self.playerItem.playbackBufferEmpty) {
                NSLog(@"cft-缓存真的空了---");
                [self.loadingView startAnimating];
            }
        }
        else if ([keyPath isEqualToString:kObserveKeyPlaybackLikelyToKeepUp]){// 当缓冲好的时候
            NSLog(@"cft-缓冲好了---");
            [self.loadingView stopAnimating];
        }
        else if ([keyPath isEqualToString:kObserveKeyduration]){//获取到时长
            _totalTime = (CGFloat)CMTimeGetSeconds(_playerItem.duration);
            NSLog(@"cft-totalTime:%f",_totalTime);
            if (_totalTime > 0) {
                self.totalTimeLabel.text = [self convertTimeWithSecond:(int)(_totalTime+0.5)];
            }
        }
    }
}

//status变化处理
- (void)playerStatusChangedWithStatus:(AVPlayerStatus)status{
    NSLog(@"cft-status:%ld",status);
    switch (status) {
        case AVPlayerStatusUnknown:{//刚开始的状态，还没有开始加载数据
            NSLog(@"cft-AVPlayerStatusUnknown");
            self.loadingProgress.progress = 0.0;
            [self.loadingView startAnimating];
            break;
        }
        case AVPlayerStatusReadyToPlay:{//准备播放
            NSLog(@"cft-AVPlayerStatusReadyToPlay");
            [self initTimer];
            break;
        }
        case AVPlayerStatusFailed:{//加载失败
            NSLog(@"cft-AVPlayerStatusFailed");
            [self.loadingView stopAnimating];
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
    NSLog(@"cft-更新进度条---");
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration)){
        self.progressSlider.minimumValue = 0.0;
        return;
    }
    CGFloat nowTime = _playerItem.currentTime.value/_playerItem.currentTime.timescale;
    self.currentTimeLabel.text = [self convertTimeWithSecond:(int)(nowTime+0.5)];
    self.totalTimeLabel.text = [self convertTimeWithSecond:(int)(_totalTime+0.5)];
    if (_isSliderDragging == NO) {
        CGFloat value = nowTime / _totalTime;
        [self.progressSlider setValue:value];
    }
}


- (void)addPlayer{
    //播放器相关
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:self.url];
    self.playerItem = item;
    
    self.player = [AVPlayer playerWithPlayerItem:item];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.contentsGravity = AVLayerVideoGravityResizeAspect;
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    //[self.contentView.layer addSublayer:self.playerLayer];
    [self.contentView.layer insertSublayer:self.playerLayer atIndex:0];
    self.playerLayer.frame = self.contentView.bounds;
    [self playVideo];
}

#pragma mark - 初始化UI
- (void)initViews{
    [self addSubview:self.contentView];
    [self.contentView addSubview:self.bottomView];
    [self.contentView addSubview:self.topView];
    [self.contentView addSubview:self.loadingView];
    [self.contentView addSubview:self.playBtn];
    
    [self.bottomView addSubview:self.currentTimeLabel];
    [self.bottomView addSubview:self.totalTimeLabel];
    [self.bottomView addSubview:self.progressSlider];
    [self.bottomView addSubview:self.fullScreenBtn];
    [self.bottomView addSubview:self.progressSlider];
    [self.bottomView addSubview:self.loadingProgress];
    [self.topView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.equalTo(self.contentView);
        make.height.mas_equalTo(70);
    }];
    [self.bottomView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.contentView);
        make.height.mas_equalTo(40);
    }];
    
    [self.loadingView startAnimating];
    [self.loadingView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.contentView);
    }];
    
    [self.playBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.contentView);
        make.width.height.mas_equalTo(60);
    }];
    [self.currentTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.bottomView).offset(2);
        make.centerY.equalTo(self.bottomView);
        make.height.mas_equalTo(20);
        make.width.mas_equalTo(45);
    }];
    [self.totalTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.bottomView).offset(-30);
        make.centerY.width.height.equalTo(self.currentTimeLabel);
    }];
    
    [self.fullScreenBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.bottomView).offset(0);
        make.width.height.mas_equalTo(35);
        make.centerY.equalTo(self.bottomView);
    }];
    
    [self.progressSlider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.bottomView).offset(50);
        make.right.equalTo(self.bottomView).offset(-80);
        make.centerY.equalTo(self.bottomView).offset(0);
    }];
    // loadingProgress要与progressSlider进度条重合，必须下移一个像素
    [self.loadingProgress mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.progressSlider);
        make.centerY.equalTo(self.bottomView).offset(1);
    }];
    
    //给进度条添加单击事件
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(actionTapGesture:)];
    [self.progressSlider addGestureRecognizer:tap];
    
    // 单击的 Recognizer
    [self.contentView addGestureRecognizer:self.singleTap];
    
    // 双击的 Recognizer
    [self.contentView addGestureRecognizer:self.doubleTap];
    [self.singleTap requireGestureRecognizerToFail:self.doubleTap];//如果双击成立，则取消单击手势（双击的时候不回走单击事件）
}

- (void)seekVideoToPos:(CGFloat)pos{
    CMTime time = CMTimeMakeWithSeconds(pos, self.player.currentTime.timescale);
    [self.player seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

#pragma mark - click event
#pragma mark - play or pause


- (void)pauseVideo{
    if (self.playBtn.selected) {
        self.playBtn.selected = NO;
        [self.player pause];
        self.isPlaying = FALSE;
    }
}

- (void)playVideo{
    if (!self.playBtn.selected) {
        self.playBtn.selected = YES;
        [self.player play];
        self.isPlaying = YES;
    }
}

#pragma mark - ---------------------------------- event handle -----------------------------------

- (void)playBtnAction:(UIButton *)btn{
    //btn.selected = !btn.selected;
    if (btn.selected) {
        [self pauseVideo];
    }else{
        [self playVideo];
    }
}

//全屏
- (void)fullScreenAction:(UIButton *)btn{
    NSLog(@"cft-%s",__func__);
}

- (void)sliderValueChanged:(UISlider *)slider{
    _isSliderDragging = YES;
}

- (void)sliderTouchUpInsideAction:(UISlider *)slider{
    _isSliderDragging = NO;
    CMTime time = CMTimeMakeWithSeconds(slider.value*_totalTime, _playerItem.currentTime.timescale);
    [self.player seekToTime:time];
}


//视频进度条的点击事件
- (void)actionTapGesture:(UITapGestureRecognizer *)sender {
    CGPoint touchLocation = [sender locationInView:self.progressSlider];
    
    CGFloat value = _totalTime * (touchLocation.x/self.progressSlider.frame.size.width);
    [self.progressSlider setValue:value/_totalTime animated:YES];
   
    [self.player seekToTime:CMTimeMakeWithSeconds(self.progressSlider.value*_totalTime, self.playerItem.currentTime.timescale)];
}

- (void)handleSingleTap:(UITapGestureRecognizer *)tap{
    [self reBuildTimer];
    [UIView animateWithDuration:0.5 animations:^{
        if (self.bottomView.alpha == 0.0) {
            [self showControlView];
        }else{
            [self hiddenControlView];
        }
    } completion:nil];
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)tap{
    [self playBtnAction:self.playBtn];
    [self showControlView];
}

#pragma mark - Helper Method
/**
 *  计算缓冲进度
 *
 *  @return 缓冲进度
 */
- (NSTimeInterval)availableDuration {
    NSArray *loadedTimeRanges = [_playerItem loadedTimeRanges];
    CMTimeRange timeRange     = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds        = CMTimeGetSeconds(timeRange.start);
    float durationSeconds     = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result     = startSeconds + durationSeconds;// 计算缓冲总进度
    return result;
}

- (NSString *)convertTimeWithSecond:(float)second{
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:second];
    if (second/3600 >= 1) {
        [[self dateFormatter] setDateFormat:@"HH:mm:ss"];
    } else {
        [[self dateFormatter] setDateFormat:@"mm:ss"];
    }
    return [[self dateFormatter] stringFromDate:d];
}

///显示操作栏view
-(void)showControlView{
    [UIView animateWithDuration:0.5 animations:^{
        self.bottomView.alpha = 1.0;
        self.topView.alpha = 1.0;
        self.playBtn.alpha = 1.0;
    } completion:^(BOOL finish){
        
    }];
}
///隐藏操作栏view
-(void)hiddenControlView{
    [UIView animateWithDuration:0.5 animations:^{
        self.bottomView.alpha = 0.0;
        self.topView.alpha = 0.0;
        self.playBtn.alpha = 0.0;
        
    } completion:^(BOOL finish){
        
    }];
}

- (void)reBuildTimer{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(autoDismissBottomView:) object:nil];
    
    [self.autoDismissTimer invalidate];
    self.autoDismissTimer = nil;
    self.autoDismissTimer = [NSTimer timerWithTimeInterval:5.0 target:self selector:@selector(autoDismissBottomView:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.autoDismissTimer forMode:NSDefaultRunLoopMode];
}

-(void)autoDismissBottomView:(NSTimer *)timer{
    if (self.isPlaying==YES) {
        if (self.bottomView.alpha==1.0) {
            [self hiddenControlView];//隐藏操作栏
        }
    }
}

#pragma mark - setter
- (void)setPlacehoderImage:(UIImage *)placehoderImage{
    _placehoderImage = placehoderImage;
    if (placehoderImage) {
        self.contentView.layer.contents = (id)_placehoderImage.CGImage;
    }
}

#pragma mark - getter
- (CMTime)playerItemDuration{
    AVPlayerItem *playerItem = _playerItem;
    if (playerItem.status == AVPlayerItemStatusReadyToPlay){
        return([playerItem duration]);
    }
    return(kCMTimeInvalid);
}

- (NSDateFormatter *)dateFormatter {
    if (!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
    }
    return _dateFormatter;
}

#pragma mark - ---------------------------------- UI init -----------------------------------

- (UIView *)contentView{
    if (!_contentView) {
        _contentView = [[UIView alloc] init];
        _contentView.backgroundColor = [UIColor blackColor];
        _contentView.frame = self.bounds;
        _contentView.userInteractionEnabled = YES;
    }
    return _contentView;
}

- (UIImageView *)bottomView{
    if (!_bottomView) {
        _bottomView = [[UIImageView alloc] init];
        _bottomView.image = FTPlayerImage(@"bottom_shadow");
        _bottomView.userInteractionEnabled = YES;
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

- (UILabel *)currentTimeLabel{
    if (!_currentTimeLabel) {
        _currentTimeLabel = [[UILabel alloc] init];
        _currentTimeLabel.textColor = [UIColor whiteColor];
        _currentTimeLabel.font = [UIFont systemFontOfSize:14.0];
        _currentTimeLabel.textAlignment = NSTextAlignmentCenter;
        _currentTimeLabel.text = @"00:00";
    }
    return _currentTimeLabel;
}

- (UILabel *)totalTimeLabel{
    if (!_totalTimeLabel) {
        _totalTimeLabel = [[UILabel alloc] init];
        _totalTimeLabel.textColor = [UIColor whiteColor];
        _totalTimeLabel.font = [UIFont systemFontOfSize:14.0];
        _totalTimeLabel.textAlignment = NSTextAlignmentCenter;
        _totalTimeLabel.text = @"00:00";
    }
    return _totalTimeLabel;
}

- (UISlider *)progressSlider{
    if (!_progressSlider) {
        _progressSlider = [[UISlider alloc] init];
        [_progressSlider setThumbImage:FTPlayerImage(@"dot") forState:UIControlStateNormal];
        _progressSlider.minimumValue = 0.0;
        _progressSlider.maximumValue = 1.0;
        _progressSlider.value = 0.0;
        _progressSlider.minimumTrackTintColor = [UIColor greenColor];
        _progressSlider.maximumTrackTintColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.5];
        [_progressSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        [_progressSlider addTarget:self action:@selector(sliderTouchUpInsideAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _progressSlider;
}

- (UIProgressView *)loadingProgress{
    if (!_loadingProgress) {
        _loadingProgress = [[UIProgressView alloc] init];
        _loadingProgress.progressTintColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.7];
        _loadingProgress.trackTintColor = [UIColor clearColor];
        [_loadingProgress setProgress:0.0];
    }
    return _loadingProgress;
}

- (UIButton *)fullScreenBtn{
    if (!_fullScreenBtn) {
        _fullScreenBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_fullScreenBtn setImage:FTPlayerImage(@"fullscreen") forState:UIControlStateNormal];
        [_fullScreenBtn addTarget:self action:@selector(fullScreenAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _fullScreenBtn;
}

- (UIButton *)playBtn{
    if (!_playBtn) {
        _playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _playBtn.showsTouchWhenHighlighted = YES;
        [_playBtn setImage:FTPlayerImage(@"play") forState:UIControlStateNormal];
        [_playBtn setImage:FTPlayerImage(@"pause") forState:UIControlStateSelected];
        [_playBtn addTarget:self action:@selector(playBtnAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _playBtn;
}

- (UIActivityIndicatorView *)loadingView{
    if (!_loadingView) {
        _loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    }
    return _loadingView;
}

- (UITapGestureRecognizer *)singleTap{
    if (!_singleTap) {
        _singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
        _singleTap.numberOfTapsRequired = 1; // 单击
        _singleTap.numberOfTouchesRequired = 1;
        // 解决点击当前view时候响应其他控件事件
        [_singleTap setDelaysTouchesBegan:YES];
    }
    return _singleTap;
}

- (UITapGestureRecognizer *)doubleTap{
    if (!_doubleTap) {
        UITapGestureRecognizer* doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
        doubleTap.numberOfTouchesRequired = 1; //手指数
        doubleTap.numberOfTapsRequired = 2; // 双击
        // 解决点击当前view时候响应其他控件事件
        [doubleTap setDelaysTouchesBegan:YES];
        _doubleTap = doubleTap;
    }
    return _doubleTap;
}


@end
