// BackgroundKeeper.swift
// StealthRec — 隐形后台守护者 (mixWithOthers 机制)
// 通过在后台播放极短的混音静音，保持 App 一直处于“Running”状态，
// 从而能够实现全局的按键与摇晃监听，并且不会中断用户的其他音乐。

import Foundation
import AVFoundation
import UIKit

final class BackgroundKeeper {
    
    static let shared = BackgroundKeeper()
    
    private var audioPlayer: AVAudioPlayer?
    private var isPlaying = false
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
    }
    
    // MARK: - 控制
    
    func start() {
        guard !isPlaying else { return }
        
        do {
            let session = AVAudioSession.sharedInstance()
            
            // 关键：.mixWithOthers 允许与其他 App 的声音（音乐、视频）同时播放，并且不会中断它们。
            // 它是特工 App 隐身的真正底牌。
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
            
            startSilentEngine()
            isPlaying = true
            
            CrashLogger.log("[BackgroundKeeper] Started silent mix audio loop.")
            
        } catch {
            CrashLogger.log("[BackgroundKeeper] Failed to start audio session: \(error)")
        }
    }
    
    func stop() {
        guard isPlaying else { return }
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {}
        
        CrashLogger.log("[BackgroundKeeper] Stopped silent mix audio loop.")
    }
    
    // MARK: - 引擎
    
    private func createSilentWAV() -> Data {
        // A minimal valid 44-byte WAV header + 2 bytes of silence (16-bit PCM, 1 channel, 44.1kHz)
        let header: [UInt8] = [
            0x52, 0x49, 0x46, 0x46, // "RIFF"
            0x26, 0x00, 0x00, 0x00, // ChunkSize (38 bytes)
            0x57, 0x41, 0x56, 0x45, // "WAVE"
            0x66, 0x6D, 0x74, 0x20, // "fmt "
            0x10, 0x00, 0x00, 0x00, // Subchunk1Size (16)
            0x01, 0x00, 0x01, 0x00, // AudioFormat (1=PCM), NumChannels (1)
            0x44, 0xAC, 0x00, 0x00, // SampleRate (44100)
            0x88, 0x58, 0x01, 0x00, // ByteRate (44100 * 1 * 2 = 88200)
            0x02, 0x00, 0x10, 0x00, // BlockAlign (2), BitsPerSample (16)
            0x64, 0x61, 0x74, 0x61, // "data"
            0x02, 0x00, 0x00, 0x00, // Subchunk2Size (2 bytes of data)
            0x00, 0x00              // The actual silent sample
        ]
        return Data(header)
    }

    private func startSilentEngine() {
        do {
            let data = createSilentWAV()
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.numberOfLoops = -1 // 无限循环播放
            audioPlayer?.volume = 0.01 // 极小音量防止系统优化
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            CrashLogger.log("[BackgroundKeeper] Failed to start audio player: \(error)")
        }
    }
    
    // MARK: - 打断处理
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .ended {
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && isPlaying {
                    // 打断结束，恢复播放
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                        audioPlayer?.play()
                    } catch {
                        CrashLogger.log("[BackgroundKeeper] Failed to resume after interruption: \(error)")
                    }
                }
            }
        }
    }
}
