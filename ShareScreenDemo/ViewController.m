//
//  ViewController.m
//  ShareScreenDemo
//
//  Created by Mac on 2026/1/30.
//

#import "ViewController.h"
#import <ReplayKit/ReplayKit.h>
#import "ETScreenShareManager.h"


@interface ViewController ()

@property (nonatomic, strong) RPSystemBroadcastPickerView *broadcastPickerView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // 注册通知，在开启屏幕共享后自动启动socket服务，回调数据
    [[ETScreenShareManager sharedManager] regisNotification];
    
    
}

-(RPSystemBroadcastPickerView *)broadcastPickerView{
    if (!_broadcastPickerView) {
        _broadcastPickerView = [[RPSystemBroadcastPickerView alloc] initWithFrame:CGRectMake(100  , 100, 100, 100)];
        // 这里提换成你的 BroadcastExtension 的 Bundle Id
        _broadcastPickerView.preferredExtension = @"com.test.shareScreen.ShareScreenDemo.BroadcastExtension";
        _broadcastPickerView.showsMicrophoneButton = NO;
        _broadcastPickerView.hidden = YES;
    }
    return _broadcastPickerView;
}



@end
