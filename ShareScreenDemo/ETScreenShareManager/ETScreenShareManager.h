//
//  ETScreenShareManager.h
//  MSIMSDK
//
//  Created by Mac on 2026/1/21.
//

#import <Foundation/Foundation.h>
#import <ReplayKit/ReplayKit.h>

typedef void(^DarwinNotificationHandler)(NSString * _Nullable notificationName);


NS_ASSUME_NONNULL_BEGIN

@interface ETScreenShareManager : NSObject

+ (instancetype)sharedManager;

-(void)startSocket;
-(void)stopSocket;
// 关闭屏幕共享
-(void)closeShareScreen;

// 注册屏幕共享
-(void)regisNotification;

@end

NS_ASSUME_NONNULL_END
