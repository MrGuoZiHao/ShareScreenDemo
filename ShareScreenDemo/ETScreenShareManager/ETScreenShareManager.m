//
//  ETScreenShareManager.m
//  MSIMSDK
//
//  Created by Mac on 2026/1/21.
//

#import "ETScreenShareManager.h"
#import "SocketReceiver.h"

@interface ETScreenShareManager ()
@property (nonatomic, strong) SocketReceiver *receiver;
@end

@implementation ETScreenShareManager

+ (instancetype)sharedManager {
    static ETScreenShareManager *instance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        instance = [[[self class] alloc] init];
    });
    return instance;
}
- (instancetype)init {
    self = [super init];
    
    if (self) {
        [self makeInit];
    }
    
    return self;
}
-(void)makeInit{
    
}

static void broadcastStoppedCallback(CFNotificationCenterRef center,
                                     void *observer,
                                     CFNotificationName name,
                                     const void *object,
                                     CFDictionaryRef userInfo)
{
    // 屏幕共享停止了
    [[ETScreenShareManager sharedManager] stopSocket];
}

static void broadcastStartCallback(CFNotificationCenterRef center,
                                   void *observer,
                                   CFNotificationName name,
                                   const void *object,
                                   CFDictionaryRef userInfo)
{
    
    [[ETScreenShareManager sharedManager] startSocket];
   
}


-(void)regisNotification{
    
    CFNotificationCenterAddObserver(
                                    CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    broadcastStartCallback,
                                    CFSTR("iOS_BroadcastStarted"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately
                                    );
    
    CFNotificationCenterAddObserver(
                                    CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    broadcastStoppedCallback,
                                    CFSTR("iOS_BroadcastStopped"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately
                                    );
}

-(void)startSocket{
    
    [self.receiver start];
}

-(void)stopSocket{
    [self.receiver stop];
}

// 关闭屏幕共享
-(void)closeShareScreen{
    CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
    CFStringRef notificationName = CFSTR("closeShareScreen");
    CFNotificationCenterPostNotification(darwinCenter, notificationName, NULL, NULL, true);
}


-(SocketReceiver *)receiver{
    if (!_receiver) {
        NSString *groupPath = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"替换成你勾选的 App Groups Id"] path];
        NSString *socketPath = [groupPath stringByAppendingPathComponent:@"rtc_SSFD"];
        
        _receiver = [[SocketReceiver alloc] initWithSocketPath:socketPath];
        
        _receiver.didReceivePixelBuffer = ^(CVPixelBufferRef pixelBuffer) {
            if (!pixelBuffer) return;
            
            
//            // 关键：在独立的 autoreleasepool 中处理
//            @autoreleasepool {
//                // 确保 pixel buffer 被正确 retain
//                CVPixelBufferRetain(pixelBuffer);
//
//                // 直接使用 RTCCVPixelBuffer，它会处理格式转换
//                RTCCVPixelBuffer *rtcBuffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer:pixelBuffer];
//
//                if (!rtcBuffer) {
//                    CVPixelBufferRelease(pixelBuffer);
//                    return;
//                }
//
//                int64_t timestampNs = (int64_t)(CACurrentMediaTime() * NSEC_PER_SEC);
//
//                RTCVideoFrame *frame = [[RTCVideoFrame alloc] initWithBuffer:rtcBuffer
//                                                                    rotation:RTCVideoRotation_0
//                                                                 timeStampNs:timestampNs];
//
//                if (frame) {
//                    // 可以投喂给 WebRTC 了
//                }
//
//                // 释放 pixel buffer
//                CVPixelBufferRelease(pixelBuffer);
//            }
        };
        __block NSInteger retryCount = 0;
        // 服务启动回调
        [_receiver setServerStateChanged:^(SocketServerState state, NSError * _Nullable error) {
            if (state == SocketServerStateFailed) {
                
            }else{
                // 启动成功
            }
        }];
    }
    return _receiver;
}



@end
