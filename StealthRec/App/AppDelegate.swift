// AppDelegate.swift
// StealthRec — 应用程序入口与生命周期管理

import UIKit
import AVFoundation
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // 步骤0: 启动日志系统（必须最早执行）
        CrashLogger.shared.startLogging()
        CrashLogger.log("[AppDelegate] Step 0: CrashLogger started")

        // 步骤1: 配置音频会话
        CrashLogger.log("[AppDelegate] Step 1: Configuring audio session...")
        configureAudioSession()
        CrashLogger.log("[AppDelegate] Step 1: Audio session configured")

        // 步骤2: 启动位置追踪
        CrashLogger.log("[AppDelegate] Step 2: Starting location tracking...")
        LocationManager.shared.startTracking()
        CrashLogger.log("[AppDelegate] Step 2: Location tracking started")

        // 步骤3: 启动触发器系统
        CrashLogger.log("[AppDelegate] Step 3: Setting up triggers...")
        setupTriggers()
        CrashLogger.log("[AppDelegate] Step 3: Triggers configured")

        // 步骤4: 监听定时停录通知
        CrashLogger.log("[AppDelegate] Step 4: Registering observers...")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTimerStop),
            name: .timerRecordingStop,
            object: nil
        )
        CrashLogger.log("[AppDelegate] Step 4: Observers registered")

        // 步骤5: 设置录音引擎委托
        CrashLogger.log("[AppDelegate] Step 5: Setting recording engine delegate...")
        RecordingEngine.shared.delegate = self
        CrashLogger.log("[AppDelegate] Step 5: Done")

        CrashLogger.log("[AppDelegate] *** App launch COMPLETE ***")
        return true
    }

    // MARK: - 音频会话配置
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker]
            )
            try session.setActive(true)
        } catch {
            print("[AppDelegate] 音频会话配置失败: \(error)")
        }
    }

    // MARK: - 触发器设置
    private func setupTriggers() {
        let settings = SettingsManager.shared.settings
        TriggerManager.shared.startAll(settings: settings)

        TriggerManager.shared.onTrigger = { [weak self] method in
            self?.handleTrigger(method: method)
        }
    }

    private func handleTrigger(method: TriggerMethod) {
        let settings = SettingsManager.shared.settings
        RecordingEngine.shared.toggleRecording(
            quality: settings.defaultQuality,
            triggerMethod: method,
            autoStopMinutes: settings.autoStopAfterMinutes
        )
    }

    @objc private func handleTimerStop() {
        if RecordingEngine.shared.isRecording {
            RecordingEngine.shared.stopRecording()
        }
    }

    // MARK: - 后台任务注册
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.ghostrec.refresh",
            using: nil
        ) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // 如果正在录音，确保音频会话活跃
        if RecordingEngine.shared.isRecording {
            try? AVAudioSession.sharedInstance().setActive(true)
        }

        // 重新调度下一次后台刷新
        scheduleBackgroundRefresh()
        task.setTaskCompleted(success: true)
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.ghostrec.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - UISceneSession Lifecycle
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    // MARK: - 进入后台
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleBackgroundRefresh()

        // 如果正在录音，保持音频会话活跃
        if RecordingEngine.shared.isRecording {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("[AppDelegate] 后台音频会话激活失败: \(error)")
            }
        }
    }

    // MARK: - 重新进入前台
    func applicationWillEnterForeground(_ application: UIApplication) {
        // 重新激活触发器
        setupTriggers()
    }
}

// MARK: - RecordingEngineDelegate
extension AppDelegate: RecordingEngineDelegate {

    func recordingDidStart(metadata: RecordingMetadata) {
        print("[AppDelegate] 录音开始: \(metadata.filename)")

        // 更新位置信息
        LocationManager.shared.captureCurrentLocation { location in
            guard let location = location else { return }
            RecordingEngine.shared.updateCurrentLocation(location)
        }

        // 触发触感反馈（让用户知道录音已开始）
        DispatchQueue.main.async {
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
        }
    }

    func recordingDidStop(metadata: RecordingMetadata) {
        print("[AppDelegate] 录音结束: \(metadata.filename), 时长: \(metadata.formattedDuration)")

        DispatchQueue.main.async {
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.warning)
        }
    }

    func recordingDidFail(error: Error) {
        print("[AppDelegate] 录音失败: \(error.localizedDescription)")

        DispatchQueue.main.async {
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.error)
        }
    }

    func recordingLevelDidUpdate(_ level: Float) {
        // 发送到 UI 层
        NotificationCenter.default.post(
            name: .recordingLevelUpdated,
            object: nil,
            userInfo: ["level": level]
        )
    }
}

// MARK: - Notification 名称
extension Notification.Name {
    static let recordingLevelUpdated = Notification.Name("StealthRec.RecordingLevelUpdated")
    static let recordingStateChanged = Notification.Name("StealthRec.RecordingStateChanged")
}
