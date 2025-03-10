#import "React/RCTConvert.h"
#import "RCTVLCPlayer.h"
#import "React/RCTBridgeModule.h"
#import "React/RCTEventDispatcher.h"
#import "React/UIView+React.h"
#import <TVVLCKit/TVVLCKit.h>
#import <AVFoundation/AVFoundation.h>
static NSString *const statusKeyPath = @"status";
static NSString *const playbackLikelyToKeepUpKeyPath = @"playbackLikelyToKeepUp";
static NSString *const playbackBufferEmptyKeyPath = @"playbackBufferEmpty";
static NSString *const readyForDisplayKeyPath = @"readyForDisplay";
static NSString *const playbackRate = @"rate";

@interface RCTVLCPlayer () <VLCMediaPlayerDelegate,VLCMediaDelegate>
@end

@implementation RCTVLCPlayer
{

    /* Required to publish events */
    RCTEventDispatcher *_eventDispatcher;
    VLCMediaPlayer *_player;

    NSDictionary * _source;
    BOOL _paused;
    BOOL _started;

}

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher
{
    if ((self = [super init])) {
        _eventDispatcher = eventDispatcher;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];

    }

    return self;
}


- (void)applicationWillResignActive:(NSNotification *)notification
{
    if (!_paused) {
        [self setPaused:_paused];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self applyModifiers];
}

- (void)applyModifiers
{
    if(!_paused)
        [self play];
}

- (void)setPaused:(BOOL)paused
{
    if(_player){
        if(!paused){
            [self play];
        }else {
            [_player pause];
            _paused =  YES;
            _started = NO;
        }
    }
}

-(void)play
{
    if(_player){
        [_player play];
        _paused = NO;
        _started = YES;
    }
}

-(void)setResume:(BOOL)autoplay
{
    @try{
        char * videoRatio = nil;
        if(_player){
            videoRatio = _player.videoAspectRatio;
            [_player stop];
            _player = nil;
        }
        NSMutableDictionary* mediaOptions = [_source objectForKey:@"mediaOptions"];
        NSArray* options = [_source objectForKey:@"initOptions"];
        NSString* uri    = [_source objectForKey:@"uri"];
        NSInteger initType = [RCTConvert NSInteger:[_source objectForKey:@"initType"]];
        BOOL autoplay = [RCTConvert BOOL:[_source objectForKey:@"autoplay"]];
        BOOL isNetWork   = [RCTConvert BOOL:[_source objectForKey:@"isNetwork"]];
        NSURL* _uri    = [NSURL URLWithString:uri];
        if(uri && uri.length > 0){
            // init player && play
            if(initType == 2){
                _player = [[VLCMediaPlayer alloc] initWithOptions:options];
            }else{
                _player = [[VLCMediaPlayer alloc] init];
            }
            [_player setDrawable:self];
            _player.delegate = self;
            _player.scaleFactor = 0;
            //设置缓存多少毫秒
            // [mediaDictonary setObject:@"1500" forKey:@"network-caching"];
            VLCMedia *media = nil;
            if(isNetWork){
                media = [VLCMedia mediaWithURL:_uri];
            }else{
                media = [VLCMedia mediaWithPath: uri];
            }
            media.delegate = self;
            if(mediaOptions){
                [media addOptions:mediaOptions];
            }
            /*if(videoRatio){
                _player.videoAspectRatio = videoRatio;
            }*/
            [media parseWithOptions:VLCMediaParseLocal|VLCMediaFetchLocal|VLCMediaParseNetwork|VLCMediaFetchNetwork];
            _player.media = media;
            if(autoplay)
                [self play];
            if(self.onVideoLoadStart){
                self.onVideoLoadStart(@{
                                        @"target": self.reactTag
                                        });
            }
        }
    }
    @catch(NSException *exception){
        NSLog(@"%@", exception);
    }
}

-(void)setSource:(NSDictionary *)source
{
    @try{
        if(_player){
            [_player stop];
            _player = nil;
        }
        _source = source;
        NSMutableDictionary* mediaOptions = [source objectForKey:@"mediaOptions"];
        NSArray* options = [source objectForKey:@"initOptions"];
        NSString* uri    = [source objectForKey:@"uri"];
        NSInteger initType = [RCTConvert NSInteger:[source objectForKey:@"initType"]];
        BOOL autoplay = [RCTConvert BOOL:[source objectForKey:@"autoplay"]];
        BOOL isNetWork   = [RCTConvert BOOL:[source objectForKey:@"isNetwork"]];
        NSURL* _uri    = [NSURL URLWithString:uri];
        if(uri && uri.length > 0){
            // init player && play
            if(initType == 2){
                _player = [[VLCMediaPlayer alloc] initWithOptions:options];
            }else{
                _player = [[VLCMediaPlayer alloc] init];
            }
            [_player setDrawable:self];
            _player.delegate = self;
            _player.scaleFactor = 0;
            //设置缓存多少毫秒
            // [mediaDictonary setObject:@"1500" forKey:@"network-caching"];
            VLCMedia *media = nil;
            if(isNetWork){
                media = [VLCMedia mediaWithURL:_uri];
            }else{
                media = [VLCMedia mediaWithPath: uri];
            }
            if(media){
                media.delegate = self;
                if(mediaOptions){
                    [media addOptions:mediaOptions];
                }
                [media parseWithOptions:VLCMediaParseLocal|VLCMediaFetchLocal|VLCMediaParseNetwork|VLCMediaFetchNetwork];
                 _player.media = media;
            }
            if(autoplay)
                [self play];
            if(self.onVideoLoadStart){
                self.onVideoLoadStart(@{
                                       @"target": self.reactTag
                                     });
            }
        }
    }
    @catch(NSException *exception){
          NSLog(@"%@", exception);
    }
}

- (void)mediaPlayerSnapshot:(NSNotification *)aNotification{
     NSLog(@"userInfo %@",[aNotification userInfo]);
    self.onSnapshot(@{
                      @"target": self.reactTag,
                      @"success": [NSNumber numberWithInt:1],
                    });
}


- (void)mediaMetaDataDidChange:(VLCMedia *)aMedia{
    NSLog(@"mediaMetaDataDidChange");
    NSInteger readBytes = aMedia.numberOfReadBytesOnInput;
    NSLog(@"readBytes %zd", readBytes);
    BOOL isPlaying = _player.isPlaying;
    BOOL hasVideoOut = _player.hasVideoOut;
    self.onVideoStateChange(@{
                              @"target": self.reactTag,
                              @"isPlaying": [NSNumber numberWithBool: isPlaying],
                              @"hasVideoOut": [NSNumber numberWithBool: hasVideoOut],
                              @"type": @"mediaMetaDataDidChange",
                            });
}

- (void)mediaDidFinishParsing:(VLCMedia *)aMedia
{
    NSLog(@"mediaDidFinishParsing");
    BOOL isPlaying = _player.isPlaying;
    BOOL hasVideoOut = _player.hasVideoOut;
    self.onVideoStateChange(@{
                              @"target": self.reactTag,
                              @"isPlaying": [NSNumber numberWithBool: isPlaying],
                              @"hasVideoOut": [NSNumber numberWithBool: hasVideoOut],
                              @"type": @"mediaDidFinishParsing",
                            });
    //NSLog(@"readBytes %zd", readBytes);
}

- (void)mediaPlayerTimeChanged:(NSNotification *)aNotification
{
    [self updateVideoProgress];
}

- (void)mediaPlayerStateChanged:(NSNotification *)aNotification
{
    @try{
        if(_player){

            /*
            NSInteger numberOfReadBytesOnInput = _player.media.numberOfReadBytesOnInput;
            NSInteger numberOfPlayedAudioBuffers =  _player.media.numberOfPlayedAudioBuffers;
            NSInteger numberOfSentBytes = _player.media.numberOfSentBytes;
            NSInteger numberOfReadBytesOnDemux =  _player.media.numberOfReadBytesOnDemux;
            NSInteger numberOfSentPackets =  _player.media.numberOfSentPackets;
            NSInteger numberOfCorruptedDataPackets =  _player.media.numberOfCorruptedDataPackets;
            NSInteger numberOfDisplayedPictures =  _player.media.numberOfDisplayedPictures;
            NSInteger numberOfDecodedVideoBlocks =  _player.media.numberOfDecodedVideoBlocks;
            */
            VLCMediaPlayerState state = _player.state;
            switch (state) {
                case VLCMediaPlayerStateOpening:
                    self.onVideoStateChange(@{
                                              @"target": self.reactTag,
                                              @"type": @"Opening",
                                              @"currentTime": [NSNumber numberWithInt:[[_player time] intValue]],
                                              @"duration": [NSNumber numberWithInt:[_player.media.length intValue]]
                                            });
                    break;
                case VLCMediaPlayerStatePaused:
                    _paused = YES;
                    self.onVideoStateChange(@{
                                              @"target": self.reactTag,
                                              @"type": @"Paused",
                                            });
                    break;
                case VLCMediaPlayerStateStopped:
                    self.onVideoStateChange(@{
                                              @"target": self.reactTag,
                                              @"type": @"Stoped",
                                            });
                    break;
                case VLCMediaPlayerStateBuffering:
                    self.onVideoStateChange(@{
                                              @"target": self.reactTag,
                                              @"isBuffering": [NSNumber numberWithBool: !_player.isPlaying],
                                              @"type": @"Buffering",
                                            });
                    break;
                case VLCMediaPlayerStatePlaying:
                    _paused = NO;
                    self.onVideoStateChange(@{
                                              @"target": self.reactTag,
                                              @"type": @"Playing",
                                            });
                    break;
                case VLCMediaPlayerStateESAdded:
                    self.onVideoStateChange(@{
                                              @"target": self.reactTag,
                                              @"type": @"ESAdded",
                                            });
                    break;
                case VLCMediaPlayerStateEnded:
                    NSLog(@"VLCMediaPlayerStateEnded %i",1);
                    self.onVideoStateChange(@{
                                              @"target": self.reactTag,
                                              @"type": @"Ended",
                                            });
                    break;
                case VLCMediaPlayerStateError:
                    self.onVideoStateChange(@{
                                              @"target": self.reactTag,
                                              @"type": @"Error",
                                            });
                    [self _release];
                    break;
            }
        }
    }@catch(NSException *exception){
        NSLog(@"%@", exception);
    }
}

-(void)updateVideoProgress
{   @try{
        if(_player){
            int currentTime  = [[_player time] intValue];
            int duration     = [_player.media.length intValue];

            if( currentTime >= 0 && currentTime < duration) {
                self.onVideoProgress(@{
                                       @"target": self.reactTag,
                                       @"currentTime": [NSNumber numberWithInt:currentTime],
                                       @"duration": [NSNumber numberWithInt:duration],
                                     });
            }
        }
    }
    @catch(NSException *exception){
        NSLog(@"%@", exception);
    }
}

- (void)jumpBackward:(int)interval
{
    if(interval>=0 && interval <= [_player.media.length intValue])
        [_player jumpBackward:interval];
}

- (void)jumpForward:(int)interval
{
    if(interval>=0 && interval <= [_player.media.length intValue])
        [_player jumpForward:interval];
}

/**
 * audio  -----> start
 */
- (void)setMuted:(BOOL)muted
{
    if(_player){
        VLCAudio *audio = _player.audio;
        [audio setMuted: muted];
    }
}

-(void)setVolume:(int)interval
{
    if(_player){
        VLCAudio *audio = _player.audio;
        if(interval >= 0){
            audio.volume = interval;
        }
    }
}

-(void)setVolumeDown:(int)volume
{
    if(_player){

        VLCAudio *audio = _player.audio;
        [audio volumeDown];
    }
}



-(void)setVolumeUp:(int)volume
{
    if(_player){
        VLCAudio *audio = _player.audio;
        [audio volumeUp];
    }
}

//audio  -----> end


-(void)setSeekTime:(int)time{
    if(_player){
        float ms = time * 1000;
        [_player setTime:[VLCTime timeWithInt:ms]];

        int currentTime  = [[_player time] intValue];
        int duration     = [_player.media.length intValue];
        self.onVideoSeek(@{
                               @"target": self.reactTag,
                               @"currentTime": [NSNumber numberWithInt:currentTime],
                               @"duration": [NSNumber numberWithInt:duration],
                             });
    }
}

-(void)setSnapshotPath:(NSString*)path
{
    if(_player)
        [_player saveVideoSnapshotAt:path withWidth:0 andHeight:0];
}

-(void)setRate:(float)rate
{
    [_player setRate:rate];
}

-(void)setClear:(float)clear
{
    [self _release];
}


-(void)setVideoAspectRatio:(NSString *)ratio{
    if(ratio != nil && ratio.length > 0){
        char *char_content = [ratio cStringUsingEncoding:NSASCIIStringEncoding];
        [_player setVideoAspectRatio:char_content];
    }
}

- (void)_release
{
    if(_player){
        [_player stop];
        _player = nil;
        _eventDispatcher = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc{
     [self _release];
}
#pragma mark - Lifecycle

//- (void)willMoveToSuperview:(UIView *)newSuperview
//- (void)didMoveToSuperview

//- (void)willRemoveSubview:(UIView *)subview


- (void)removeFromSuperview
{
    NSLog(@"removeFromSuperview");
    [self _release];
    [super removeFromSuperview];
}

@end
