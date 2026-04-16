// AppDelegate.swift
// StealthRec — 应用程序入口与生命周期管理
// 使用传统 AppDelegate+UIWindow 方式（不使用 Scene-based lifecycle）
// 这是巨魔侧载 App 的正确方式，避免 SceneDelegate 与 AMFI 的冲突

import UIKit
import AVFoundation
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // 步骤0: 启动日志系统（必须最早执行）
        CrashLogger.shared.startLogging()
        CrashLogger.log("[AppDelegate] Step 0: CrashLogger started")

        // 步骤1: 创建主窗口（传统 UIWindow 方式，不依赖 Scene）
        CrashLogger.log("[AppDelegate] Step 1: Creating UIWindow...")
        setupWindow()
        CrashLogger.log("[AppDelegate] Step 1: UIWindow created")

        // 步骤2: 配置音频会话
        CrashLogger.log("[AppDelegate] Step 2: Configuring audio session...")
        configureAudioSession()
        CrashLogger.log("[AppDelegate] Step 2: Audio session configured")

        // 步骤3: 启动位置追踪
        CrashLogger.log("[AppDelegate] Step 3: Starting location tracking...")
        LocationManager.shared.startTracking()
        CrashLogger.log("[AppDelegate] Step 3: Location tracking started")

        // 步骤4: 启动触发器系统
        CrashLogger.log("[AppDelegate] Step 4: Setting up triggers...")
        setupTriggers()
        CrashLogger.log("[AppDelegate] Step 4: Triggers configured")

        // 步骤5: 监听定时停录通知
        CrashLogger.log("[AppDelegate] Step 5: Registering observers...")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTimerStop),
            name: .timerRecordingStop,
            object: nil
        )
        CrashLogger.log("[AppDelegate] Step 5: Observers registered")

        // 步骤6: 设置录音引擎委托
        CrashLogger.log("[AppDelegate] Step 6: Setting recording engine delegate...")
        RecordingEngine.shared.delegate = self
        CrashLogger.log("[AppDelegate] Step 6: Done")

        CrashLogger.log("[AppDelegate] *** App launch COMPLETE ***")
        return true
    }

    // MARK: - 主窗口创建（传统方式）
    private func setupWindow() {
        let settings = SettingsManager.shared.settings

        let mainVC = MainViewController()
        let nav = UINavigationController(rootViewController: mainVC)
        nav.navigationBar.prefersLargeTitles = true
        applyDarkTheme(to: nav)

        window = UIWindow(frame: UIScreen.main.bounds)

        if settings.passwordEnabled {
            let authVC = AuthViewController()
            authVC.onAuthenticated = { [weak self] in
                self?.window?.rootViewController = nav
            }
            window?.rootViewController = authVC
        } else {
            window?.rootViewController = nav
        }

        window?.makeKeyAndVisible()
    }

    private func applyDarkTheme(to nav: UINavigationController) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(hex: "#0D0D0F")
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        nav.navigationBar.standardAppearance = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance
        nav.navigationBar.compactAppearance = appearance
        nav.navigationBar.tintColor = UIColor(hex: "#FF3B30")
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
            CrashLogger.log("[AppDelegate] 音频会话配置失败: \(error)")
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

    // MARK: - 后台任务注册（按需开启）
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
        if RecordingEngine.shared.isRecording {
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        scheduleBackgroundRefresh()
        task.setTaskCompleted(success: true)
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.ghostrec.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - 进入后台
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleBackgroundRefresh()
        if RecordingEngine.shared.isRecording {
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }

    // MARK: - 重新进入前台
    func applicationWillEnterForeground(_ application: UIApplication) {
        setupTriggers()
    }
}

// MARK: - RecordingEngineDelegate
extension AppDelegate: RecordingEngineDelegate {

    func recordingDidStart(metadata: RecordingMetadata) {
        CrashLogger.log("[AppDelegate] 录音开始: \(metadata.filename)")
        LocationManager.shared.captureCurrentLocation { location in
            guard let location = location else { return }
            RecordingEngine.shared.updateCurrentLocation(location)
        }
        DispatchQueue.main.async {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func recordingDidStop(metadata: RecordingMetadata) {
        CrashLogger.log("[AppDelegate] 录音结束: \(metadata.filename)")
        DispatchQueue.main.async {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    func recordingDidFail(error: Error) {
        CrashLogger.log("[AppDelegate] 录音失败: \(error.localizedDescription)")
        DispatchQueue.main.async {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    func recordingLevelDidUpdate(_ level: Float) {
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
