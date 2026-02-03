//
//  SocketReceiver.h
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

typedef NS_ENUM(NSInteger, SocketServerState) {
    SocketServerStateListening,
    SocketServerStateFailed
};

NS_ASSUME_NONNULL_BEGIN

@interface SocketReceiver : NSObject

@property (nonatomic, copy) void (^didReceivePixelBuffer)(CVPixelBufferRef pixelBuffer);
@property (nonatomic, copy) void (^serverStateChanged)(SocketServerState state, NSError * _Nullable error);

@property (nonatomic, strong, readonly) NSString *socketPath;

- (instancetype)initWithSocketPath:(NSString *)path;
- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
