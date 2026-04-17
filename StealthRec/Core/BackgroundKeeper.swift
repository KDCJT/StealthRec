// BackgroundKeeper.swift
// StealthRec — 隐形后台守护者 (mixWithOthers 机制)
// 通过在后台播放极短的混音静音，保持 App 一直处于“Running”状态，
// 从而能够实现全局的按键与摇晃监听，并且不会中断用户的其他音乐。

import Foundation
import AVFoundation
import UIKit

final class BackgroundKeeper {
    
    static let shared = BackgroundKeeper()
    
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
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
        engine?.stop()
        playerNode?.stop()
        engine = nil
        playerNode = nil
        isPlaying = false
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {}
        
        CrashLogger.log("[BackgroundKeeper] Stopped silent mix audio loop.")
    }
    
    // MARK: - 引擎
    
    private func startSilentEngine() {
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = engine, let playerNode = playerNode else { return }
        
        engine.attach(playerNode)
        
        // 创建一个无声缓冲
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
            playSilentBuffer(on: playerNode, format: format)
        } catch {
            CrashLogger.log("[BackgroundKeeper] Engine start failed: \(error)")
        }
    }
    
    private func playSilentBuffer(on player: AVAudioPlayerNode, format: AVAudioFormat) {
        let frameCapacity = AVAudioFrameCount(format.sampleRate * 0.1) // 0.1 秒
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return }
        buffer.frameLength = frameCapacity
        
        // 填充静音
        if let data = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCapacity) {
                data[i] = 0.0
            }
        }
        
        // 无限循环
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
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
                        try engine?.start()
                        playerNode?.play()
                    } catch {
                        CrashLogger.log("[BackgroundKeeper] Failed to resume after interruption: \(error)")
                    }
                }
            }
        }
    }
}
