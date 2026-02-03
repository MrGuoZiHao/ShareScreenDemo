//
//  SocketReceiver.m
//

#import "SocketReceiver.h"
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#import <CoreImage/CoreImage.h>

@interface SocketReceiver ()

@property (nonatomic, assign) int serverSocket;
@property (nonatomic, assign) int clientSocket;
@property (nonatomic, strong) NSMutableData *buffer;
@property (nonatomic, strong) dispatch_queue_t bufferQueue; // buffer 串行操作
@property (atomic, assign) BOOL running;

@end

@implementation SocketReceiver

- (instancetype)initWithSocketPath:(NSString *)path {
    if (self = [super init]) {
        _socketPath = path;
        _bufferQueue = dispatch_queue_create("com.example.socketreceiver.bufferQueue", DISPATCH_QUEUE_SERIAL);
        _buffer = [NSMutableData data];
        _serverSocket = -1;
        _clientSocket = -1;
    }
    return self;
}

#pragma mark - Start / Stop

- (void)start {
    self.running = YES;
    
    // accept 循环在全局队列，buffer 操作串行
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self setupServer];
    });
}

- (void)stop {
    self.running = NO;

    // 先关闭 socket，确保 accept 返回
    if (self.clientSocket > 0) {
        close(self.clientSocket);
        self.clientSocket = -1;
    }
    if (self.serverSocket > 0) {
        close(self.serverSocket);
        self.serverSocket = -1;
    }
    unlink([self.socketPath UTF8String]);

    // 清理 buffer
    dispatch_async(self.bufferQueue, ^{
        [self.buffer setLength:0];
    });
}

#pragma mark - Server Setup

- (void)setupServer {
    unlink([_socketPath UTF8String]);

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        perror("socket");
        [self notifyFailed:@"socket failed"];
        return;
    }
    self.serverSocket = fd;

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, [_socketPath UTF8String], sizeof(addr.sun_path)-1);

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind");
        [self notifyFailed:@"bind failed"];
        close(fd);
        return;
    }

    if (listen(fd, 5) < 0) {
        perror("listen");
        [self notifyFailed:@"listen failed"];
        close(fd);
        return;
    }

    NSLog(@"Socket server listening at %@", self.socketPath);
    if (self.serverStateChanged) self.serverStateChanged(SocketServerStateListening, nil);

    while (self.running) {
        int clientFd = accept(fd, NULL, NULL);
        if (clientFd < 0) {
            if (!self.running) break;
            perror("accept");
            continue;
        }

        NSLog(@"Client connected");
        self.clientSocket = clientFd;
        [self receiveLoop:clientFd];
        close(clientFd);
        self.clientSocket = -1;
        NSLog(@"Client disconnected");
    }
}

- (void)notifyFailed:(NSString *)reason {
    if (self.serverStateChanged) {
        NSError *error = [NSError errorWithDomain:@"SocketReceiver"
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey: reason}];
        self.serverStateChanged(SocketServerStateFailed, error);
    }
}

#pragma mark - Receive Data

- (void)receiveLoop:(int)fd {
    uint8_t buf[8192];
    ssize_t n;
    while (self.running && (n = read(fd, buf, sizeof(buf))) > 0) {
        NSData *data = [NSData dataWithBytes:buf length:n];
        dispatch_async(self.bufferQueue, ^{
            [self.buffer appendData:data];
            [self processBuffer];
        });
    }
}

#pragma mark - Process Buffer

- (void)processBuffer {
    while (true) {
        if (self.buffer.length == 0) return;

        NSData *headerEndData = [@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
        NSRange headerEndRange = [self.buffer rangeOfData:headerEndData options:0 range:NSMakeRange(0, self.buffer.length)];
        if (headerEndRange.location == NSNotFound) return;

        NSInteger headerLength = headerEndRange.location + headerEndRange.length;
        NSData *headerData = [self.buffer subdataWithRange:NSMakeRange(0, headerLength)];
        NSString *headerString = [[NSString alloc] initWithData:headerData encoding:NSUTF8StringEncoding];

        NSInteger contentLength = 0;
        NSRange range = [headerString rangeOfString:@"Content-Length:" options:NSCaseInsensitiveSearch];
        if (range.location != NSNotFound) {
            NSString *substr = [headerString substringFromIndex:range.location + range.length];
            substr = [[substr componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] firstObject];
            contentLength = [substr integerValue];
        }

        if (self.buffer.length < headerLength + contentLength) return;

        NSData *jpegData = [self.buffer subdataWithRange:NSMakeRange(headerLength, contentLength)];
        CVPixelBufferRef pixelBuffer = [self pixelBufferFromJPEGData:jpegData];

        if (pixelBuffer && self.didReceivePixelBuffer) {
            self.didReceivePixelBuffer(pixelBuffer);
        }
        if (pixelBuffer) CFRelease(pixelBuffer);

        if (self.buffer.length >= headerLength + contentLength) {
            [self.buffer replaceBytesInRange:NSMakeRange(0, headerLength + contentLength) withBytes:NULL length:0];
        } else {
            [self.buffer setLength:0];
        }
    }
}

#pragma mark - JPEG -> CVPixelBuffer

- (CVPixelBufferRef)pixelBufferFromJPEGData:(NSData *)jpegData {
    CIImage *ciImage = [CIImage imageWithData:jpegData];
    if (!ciImage) return nil;

    CGSize size = ciImage.extent.size;

    NSDictionary *attrs = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (NSString *)kCVPixelBufferWidthKey: @(size.width),
        (NSString *)kCVPixelBufferHeightKey: @(size.height),
        (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
    };

    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          size.width,
                                          size.height,
                                          kCVPixelFormatType_32BGRA,
                                          (__bridge CFDictionaryRef)attrs,
                                          &pixelBuffer);
    if (status != kCVReturnSuccess || !pixelBuffer) {
        NSLog(@"Failed to create pixel buffer: %d", status);
        return NULL;
    }

    CIContext *context = [CIContext contextWithOptions:nil];
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    [context render:ciImage toCVPixelBuffer:pixelBuffer];
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    return pixelBuffer;
}

@end
