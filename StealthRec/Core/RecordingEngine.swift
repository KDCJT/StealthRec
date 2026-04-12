// RecordingEngine.swift
// StealthRec — AVAudioRecorder 核心录音引擎

import Foundation
import AVFoundation

// MARK: - 录音引擎委托协议
protocol RecordingEngineDelegate: AnyObject {
    func recordingDidStart(metadata: RecordingMetadata)
    func recordingDidStop(metadata: RecordingMetadata)
    func recordingDidFail(error: Error)
    func recordingLevelDidUpdate(_ level: Float) // 音量电平 0.0-1.0
}

// MARK: - 录音状态
enum RecordingState {
    case idle
    case recording
    case paused
}

// MARK: - 核心录音引擎
final class RecordingEngine: NSObject {

    static let shared = RecordingEngine()

    weak var delegate: RecordingEngineDelegate?

    private(set) var state: RecordingState = .idle
    private(set) var currentMetadata: RecordingMetadata?

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var durationTimer: Timer?
    private var currentDuration: TimeInterval = 0
    private var autoStopTimer: Timer?

    private override init() {
        super.init()
        setupAudioSession()
        setupInterruptionObserver()
    }

    // MARK: - 音频会话配置
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker]
            )
            try session.setActive(true)
        } catch {
            print("[RecordingEngine] 音频会话配置失败: \(error)")
        }
    }

    // MARK: - 中断监听（来电等）
    private func setupInterruptionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            // 来电等中断：暂停但不停止录音
            audioRecorder?.pause()
            state = .paused

        case .ended:
            // 中断结束：恢复录音
            if let options = info[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                try? AVAudioSession.sharedInstance().setActive(true)
                audioRecorder?.record()
                state = .recording
            }

        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        switch reason {
        case .oldDeviceUnavailable:
            // 耳机拔出时继续用内置麦克风录音
            if state == .recording {
                try? AVAudioSession.sharedInstance().setActive(true)
                audioRecorder?.record()
            }
        default:
            break
        }
    }

    // MARK: - 开始录音
    func startRecording(
        quality: RecordingQuality,
        triggerMethod: TriggerMethod,
        locationAddress: String? = nil,
        autoStopMinutes: Int = 0
    ) {
        guard state == .idle else {
            // 如果正在录音，停止当前录音
            if state == .recording {
                stopRecording()
            }
            return
        }

        let filename = RecordingMetadata.generateFilename(quality: quality, location: locationAddress)
        var metadata = RecordingMetadata(
            filename: filename,
            quality: quality,
            triggerMethod: triggerMethod
        )

        let fileURL = RecordingStore.shared.recordingFileURL(for: filename)

        let settings = buildAudioSettings(for: quality)

        do {
            try AVAudioSession.sharedInstance().setActive(true)
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            recorder.record()

            self.audioRecorder = recorder
            self.currentMetadata = metadata
            self.currentDuration = 0
            self.state = .recording

            startTimers()

            // 自动停止计时器
            if autoStopMinutes > 0 {
                autoStopTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(autoStopMinutes * 60), repeats: false) { [weak self] _ in
                    self?.stopRecording()
                }
            }

            delegate?.recordingDidStart(metadata: metadata)

        } catch {
            delegate?.recordingDidFail(error: error)
        }
    }

    // MARK: - 停止录音
    @discardableResult
    func stopRecording() -> RecordingMetadata? {
        guard state == .recording || state == .paused,
              var metadata = currentMetadata else { return nil }

        autoStopTimer?.invalidate()
        autoStopTimer = nil
        stopTimers()

        audioRecorder?.stop()

        metadata.endTime = Date()
        metadata.duration = currentDuration

        // 获取文件大小
        let fileURL = RecordingStore.shared.recordingFileURL(for: metadata.filename)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
            metadata.fileSize = attrs[.size] as? Int64 ?? 0
        }

        currentMetadata = nil
        audioRecorder = nil
        state = .idle

        // 保存元数据
        RecordingStore.shared.save(metadata: metadata)

        delegate?.recordingDidStop(metadata: metadata)
        return metadata
    }

    // MARK: - 切换录音（开始或停止）
    func toggleRecording(quality: RecordingQuality, triggerMethod: TriggerMethod, autoStopMinutes: Int = 0) {
        if state == .recording {
            stopRecording()
        } else {
            let address = LocationManager.shared.currentAddress
            startRecording(
                quality: quality,
                triggerMethod: triggerMethod,
                locationAddress: address,
                autoStopMinutes: autoStopMinutes
            )
        }
    }

    // MARK: - 计时器
    private func startTimers() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            let level = recorder.averagePower(forChannel: 0)
            // 将 dB 值（-160 到 0）转换为 0.0-1.0
            let normalized = max(0, (level + 80) / 80)
            self.delegate?.recordingLevelDidUpdate(normalized)
        }

        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentDuration += 1
        }
    }

    private func stopTimers() {
        levelTimer?.invalidate()
        levelTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
    }

    // MARK: - 录音设置构建
    private func buildAudioSettings(for quality: RecordingQuality) -> [String: Any] {
        switch quality {
        case .lossless:
            return [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: quality.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
        default:
            return [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: quality.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey: quality.bitRate
            ]
        }
    }

    // MARK: - 状态查询
    var isRecording: Bool { state == .recording }

    var currentRecordingDuration: TimeInterval { currentDuration }

    func updateCurrentLocation(_ location: RecordingLocation) {
        currentMetadata?.location = location
    }
}

// MARK: - AVAudioRecorderDelegate
extension RecordingEngine: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            state = .idle
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            stopRecording()
            delegate?.recordingDidFail(error: error)
        }
    }
}
