//
//  SampleHandler.swift
//  CallBroadcastExtension
//
//  Created by Mac on 2026/1/26.
//

import ReplayKit

private enum Constants {
    // the App Group ID value that the app and the broadcast extension targets are setup with. It differs for each app.
    static let appGroupIdentifier = "替换成你勾选的 App Groups Id"
}

class SampleHandler: RPBroadcastSampleHandler {
    
    
    func registerDarwinNotification() {
        let darwinCenter = CFNotificationCenterGetDarwinNotifyCenter()
        
        CFNotificationCenterAddObserver(
            darwinCenter,
            Unmanaged.passUnretained(self).toOpaque(), // observer 传入 self
            SampleHandler.darwinCallback,              // 静态回调
            "closeShareScreen" as CFString,            // 通知名
            nil,
            .deliverImmediately
        )
    }
    
    // 静态函数作为 C 函数指针
    static let darwinCallback: CFNotificationCallback = { (center, observer, name, object, userInfo) in
        guard let observer = observer else { return }
        let handler = Unmanaged<SampleHandler>.fromOpaque(observer).takeUnretainedValue()
        
        if let name = name {
            let notificationName = name.rawValue as String
            print("收到 Darwin 通知: \(notificationName)")
            
            if notificationName == "closeShareScreen" {
                let JMScreenSharingStopped = 10001
                let customError = NSError(
                    domain: RPRecordingErrorDomain,
                    code: JMScreenSharingStopped,
                    userInfo: [NSLocalizedDescriptionKey: "Call End"]
                )
                
                handler.finishBroadcastWithError(customError) // 调用实例方法
            }
        }
    }
    
    
    deinit {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
    }
    
    private var clientConnection: SocketConnection?
    private var uploader: SampleUploader?
    
    private var frameCount: Int = 0
    
    var socketFilePath: String {
        let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier)
        return sharedContainer?.appendingPathComponent("rtc_SSFD").path ?? ""
    }
    
    override init() {
        super.init()
        if let connection = SocketConnection(filePath: socketFilePath) {
            clientConnection = connection
            setupConnection()
            
            uploader = SampleUploader(connection: connection)
        }
        
        registerDarwinNotification()
        
    }
    
    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
        frameCount = 0
        
        DarwinNotificationCenter.shared.postNotification(.broadcastStarted)
        openConnection()
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast.
        DarwinNotificationCenter.shared.postNotification(.broadcastStopped)
        clientConnection?.close()
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            // very simple mechanism for adjusting frame rate by using every third frame
            frameCount += 1
            if frameCount % 3 == 0 {
                uploader?.send(sample: sampleBuffer)
            }
        default:
            break
        }
    }
}

private extension SampleHandler {
    
    func setupConnection() {
        clientConnection?.didClose = { [weak self] error in
            print("client connection did close \(String(describing: error))")
            
            if let error = error {
                self?.finishBroadcastWithError(error)
            } else {
                // the displayed failure message is more user friendly when using NSError instead of Error
                let JMScreenSharingStopped = 10001
                let customError = NSError(domain: RPRecordingErrorDomain, code: JMScreenSharingStopped, userInfo: [NSLocalizedDescriptionKey: "Screen sharing stopped"])
                self?.finishBroadcastWithError(customError)
            }
        }
    }
    
    func openConnection() {
        let queue = DispatchQueue(label: "broadcast.connectTimer")
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(500))
        timer.setEventHandler { [weak self] in
            guard self?.clientConnection?.open() == true else {
                return
            }
            
            timer.cancel()
        }
        
        timer.resume()
    }
}
