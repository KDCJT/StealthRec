// TriggerManager.swift
// StealthRec — 多方式触发管理器

import Foundation
import AVFoundation
import CoreMotion
import UIKit

// MARK: - 触发管理器
final class TriggerManager: NSObject {

    static let shared = TriggerManager()

    // 触发回调（在任何触发条件满足时调用）
    var onTrigger: ((TriggerMethod) -> Void)?

    private let motionManager = CMMotionManager()
    private var audioSession = AVAudioSession.sharedInstance()
    private var lastVolume: Float = 0.5
    private var volumeTapTimes: [Date] = []
    private var isObservingVolume = false
    private var floatWindow: UIWindow?
    private var timerTrigger: Timer?
    private var shakeDebounceTimer: Timer?
    private var isShakeCoolingDown = false

    private override init() { super.init() }

    // MARK: - 启动所有启用的触发器
    func startAll(settings: AppSettings) {
        stopAll()

        if settings.enableShakeTrigger {
            startShakeTrigger(threshold: settings.shakeThreshold)
        }

        if settings.enableVolumeKeyTrigger {
            startVolumeKeyTrigger(tapCount: settings.volumeKeyTapCount)
        }

        if settings.enableFloatButton {
            startFloatButton(xRatio: settings.floatButtonX, yRatio: settings.floatButtonY)
        }

        if settings.enableTimerTrigger, let start = settings.timerStartTime {
            scheduleTimerTrigger(at: start, stop: settings.timerStopTime)
        }
        
        let needsBackground = settings.enableShakeTrigger || settings.enableVolumeKeyTrigger
        if needsBackground {
            BackgroundKeeper.shared.start()
        } else {
            BackgroundKeeper.shared.stop()
        }
    }

    func stopAll() {
        stopShakeTrigger()
        stopVolumeKeyTrigger()
        stopFloatButton()
        stopTimerTrigger()
        BackgroundKeeper.shared.stop()
    }

    // MARK: ─────────────────────────────────────────
    // MARK: 1. 摇动触发（CMMotionManager 加速度计）
    // ─────────────────────────────────────────────

    private func startShakeTrigger(threshold: Double) {
        guard motionManager.isAccelerometerAvailable else { return }

        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: OperationQueue.main) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            guard !self.isShakeCoolingDown else { return }

            let x = data.acceleration.x
            let y = data.acceleration.y
            let z = data.acceleration.z
            let magnitude = sqrt(x*x + y*y + z*z)

            // 减去重力（约1g），检测是否超过阈值
            if magnitude > threshold {
                self.isShakeCoolingDown = true
                self.onTrigger?(.shake)

                // 冷却时间防止重复触发
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.isShakeCoolingDown = false
                }
            }
        }
    }

    private func stopShakeTrigger() {
        motionManager.stopAccelerometerUpdates()
        isShakeCoolingDown = false
    }

    // MARK: ─────────────────────────────────────────
    // MARK: 2. 音量键触发（KVO + 快速连按检测）
    // ─────────────────────────────────────────────

    private func startVolumeKeyTrigger(tapCount: Int) {
        guard !isObservingVolume else { return }

        do {
            try audioSession.setActive(true)
        } catch {}

        lastVolume = audioSession.outputVolume
        audioSession.addObserver(
            self,
            forKeyPath: "outputVolume",
            options: [.new, .old],
            context: nil
        )
        isObservingVolume = true
    }

    private func stopVolumeKeyTrigger() {
        guard isObservingVolume else { return }
        audioSession.removeObserver(self, forKeyPath: "outputVolume")
        isObservingVolume = false
        volumeTapTimes.removeAll()
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == "outputVolume",
              let newVal = change?[.newKey] as? Float,
              let oldVal = change?[.oldKey] as? Float else { return }

        // 音量有变化时记录时间
        if abs(newVal - oldVal) > 0.01 {
            volumeTapTimes.append(Date())

            // 记录当前时间
            let now = Date()
            
            // 清理 1 秒前的记录
            volumeTapTimes = volumeTapTimes.filter { now.timeIntervalSince($0) < 1.0 }

            // 检测是否达到连按次数
            let settings = SettingsManager.shared.settings
            if volumeTapTimes.count >= settings.volumeKeyTapCount {
                volumeTapTimes.removeAll()
                onTrigger?(.volumeKey)
            }
        }
    }

    // MARK: ─────────────────────────────────────────
    // MARK: 3. 悬浮按钮触发（UIWindow 全局覆盖）
    // ─────────────────────────────────────────────

    private func startFloatButton(xRatio: Float, yRatio: Float) {
        guard floatWindow == nil else { return }

        DispatchQueue.main.async {
            let screen = UIScreen.main.bounds
            let size: CGFloat = 52
            let x = screen.width * CGFloat(xRatio) - size / 2
            let y = screen.height * CGFloat(yRatio) - size / 2

            let window = UIWindow(frame: CGRect(x: x, y: y, width: size, height: size))
            window.windowLevel = UIWindow.Level.alert + 1
            window.backgroundColor = .clear
            window.isHidden = false

            let vc = FloatButtonViewController()
            vc.onTap = { [weak self] in
                self?.onTrigger?(.floatButton)
            }
            window.rootViewController = vc
            self.floatWindow = window
        }
    }

    private func stopFloatButton() {
        DispatchQueue.main.async {
            self.floatWindow?.isHidden = true
            self.floatWindow = nil
        }
    }

    func updateFloatButtonPosition(xRatio: Float, yRatio: Float) {
        guard let window = floatWindow else { return }
        DispatchQueue.main.async {
            let screen = UIScreen.main.bounds
            let size: CGFloat = 52
            let x = screen.width * CGFloat(xRatio) - size / 2
            let y = screen.height * CGFloat(yRatio) - size / 2
            window.frame = CGRect(x: x, y: y, width: size, height: size)
        }
    }

    // MARK: ─────────────────────────────────────────
    // MARK: 4. 定时触发
    // ─────────────────────────────────────────────

    private func scheduleTimerTrigger(at startTime: Date, stop stopTime: Date?) {
        let delay = startTime.timeIntervalSinceNow
        if delay > 0 {
            timerTrigger = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.onTrigger?(.timer)

                // 如果设置了结束时间，安排自动停止
                if let stop = stopTime {
                    let stopDelay = stop.timeIntervalSince(startTime)
                    DispatchQueue.main.asyncAfter(deadline: .now() + stopDelay) {
                        // 通知停止
                        NotificationCenter.default.post(name: .timerRecordingStop, object: nil)
                    }
                }
            }
        }
    }

    private func stopTimerTrigger() {
        timerTrigger?.invalidate()
        timerTrigger = nil
    }
}

// MARK: - 悬浮按钮 ViewController
private class FloatButtonViewController: UIViewController {

    var onTap: (() -> Void)?
    private var button: UIButton!
    private var isDragging = false
    private var panGesture: UIPanGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupButton()
    }

    private func setupButton() {
        button = UIButton(type: .custom)
        button.frame = view.bounds
        button.layer.cornerRadius = view.bounds.width / 2
        button.backgroundColor = UIColor.black.withAlphaComponent(0.1) // 降低透明度使其更隐蔽
        button.layer.shadowOpacity = 0.0

        let micImage = UIImage(systemName: "mic.fill")?.withRenderingMode(.alwaysTemplate)
        button.setImage(micImage, for: .normal)
        button.tintColor = UIColor.white.withAlphaComponent(0.3) // 隐蔽的图标
        button.imageView?.contentMode = .scaleAspectFit

        // 双击手势（满足双击屏幕某区域要求）
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(buttonDoubleTapped))
        doubleTap.numberOfTapsRequired = 2
        button.addGestureRecognizer(doubleTap)
        
        view.addSubview(button)

        // 拖拽手势
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        button.addGestureRecognizer(panGesture)
    }

    @objc private func buttonDoubleTapped() {
        guard !isDragging else { return }

        // 触感反馈
        let feedback = UIImpactFeedbackGenerator(style: .heavy)
        feedback.impactOccurred()

        // 短暂动画
        UIView.animate(withDuration: 0.1, animations: {
            self.button.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.button.transform = .identity
            }
        }

        onTap?()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let parentWindow = view.window else { return }
        let translation = gesture.translation(in: parentWindow)

        switch gesture.state {
        case .began:
            isDragging = true
        case .changed:
            var newFrame = parentWindow.frame
            newFrame.origin.x += translation.x
            newFrame.origin.y += translation.y

            // 限制在屏幕内
            let screen = UIScreen.main.bounds
            newFrame.origin.x = max(0, min(newFrame.origin.x, screen.width - newFrame.width))
            newFrame.origin.y = max(44, min(newFrame.origin.y, screen.height - newFrame.height - 34))

            parentWindow.frame = newFrame
            gesture.setTranslation(.zero, in: parentWindow)

        case .ended, .cancelled:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isDragging = false
            }
            // 保存新位置到设置
            let screen = UIScreen.main.bounds
            let xRatio = Float((parentWindow.frame.midX) / screen.width)
            let yRatio = Float((parentWindow.frame.midY) / screen.height)
            SettingsManager.shared.updateFloatButtonPosition(x: xRatio, y: yRatio)
        default:
            break
        }
    }

    // 更新按钮外观（录音中/停止）
    func updateState(isRecording: Bool) {
        DispatchQueue.main.async {
            let imageName = isRecording ? "stop.fill" : "mic.fill"
            self.button.setImage(UIImage(systemName: imageName)?.withRenderingMode(.alwaysTemplate), for: .normal)
            self.button.backgroundColor = UIColor.black.withAlphaComponent(0.1)
            self.button.tintColor = isRecording 
                ? UIColor.red.withAlphaComponent(0.3)
                : UIColor.white.withAlphaComponent(0.3)

            if isRecording {
                // 脉冲动画
                let pulse = CABasicAnimation(keyPath: "transform.scale")
                pulse.fromValue = 1.0
                pulse.toValue = 1.12
                pulse.duration = 0.8
                pulse.autoreverses = true
                pulse.repeatCount = .infinity
                self.button.layer.add(pulse, forKey: "pulse")
            } else {
                self.button.layer.removeAllAnimations()
            }
        }
    }
}

// MARK: - Notification 扩展
extension Notification.Name {
    static let timerRecordingStop = Notification.Name("StealthRec.TimerRecordingStop")
}
