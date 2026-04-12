// RecordingMetadata.swift
// StealthRec — 录音元数据模型

import Foundation
import CoreLocation

// MARK: - 录音质量枚举
enum RecordingQuality: String, Codable, CaseIterable {
    case low      = "low"
    case standard = "standard"
    case high     = "high"
    case lossless = "lossless"

    var displayName: String {
        switch self {
        case .low:      return "低质量（省空间）"
        case .standard: return "标准质量"
        case .high:     return "高质量"
        case .lossless: return "无损质量"
        }
    }

    var sampleRate: Double {
        switch self {
        case .low:      return 8000
        case .standard: return 22050
        case .high:     return 44100
        case .lossless: return 44100
        }
    }

    var bitRate: Int {
        switch self {
        case .low:      return 16000
        case .standard: return 64000
        case .high:     return 128000
        case .lossless: return 0 // LPCM 无压缩
        }
    }

    var fileExtension: String {
        switch self {
        case .lossless: return "caf"
        default:        return "m4a"
        }
    }

    var estimatedBytesPerSecond: Int {
        switch self {
        case .low:      return 2000
        case .standard: return 8000
        case .high:     return 16000
        case .lossless: return 88200
        }
    }
}

// MARK: - 触发方式枚举
enum TriggerMethod: String, Codable {
    case shake       = "shake"
    case volumeKey   = "volume_key"
    case floatButton = "float_button"
    case timer       = "timer"
    case manual      = "manual"

    var displayName: String {
        switch self {
        case .shake:       return "摇动手机"
        case .volumeKey:   return "音量键触发"
        case .floatButton: return "悬浮按钮"
        case .timer:       return "定时录音"
        case .manual:      return "手动启动"
        }
    }
}

// MARK: - 位置信息模型
struct RecordingLocation: Codable {
    let latitude: Double
    let longitude: Double
    let address: String
    let city: String
    let accuracy: Double

    init(coordinate: CLLocationCoordinate2D, address: String, city: String, accuracy: Double) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.address = address
        self.city = city
        self.accuracy = accuracy
    }

    var displayString: String {
        if address.isEmpty { return "位置未知" }
        return address
    }
}

// MARK: - 录音元数据主模型
struct RecordingMetadata: Codable, Identifiable {
    let id: String
    let filename: String
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval
    let quality: RecordingQuality
    var location: RecordingLocation?
    let triggerMethod: TriggerMethod
    var fileSize: Int64
    var title: String
    var notes: String

    init(
        filename: String,
        quality: RecordingQuality,
        triggerMethod: TriggerMethod
    ) {
        self.id = UUID().uuidString
        self.filename = filename
        self.startTime = Date()
        self.endTime = nil
        self.duration = 0
        self.quality = quality
        self.location = nil
        self.triggerMethod = triggerMethod
        self.fileSize = 0
        self.title = Self.generateTitle(from: Date())
        self.notes = ""
    }

    static func generateTitle(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return "录音 " + formatter.string(from: date)
    }

    // 生成带日期的文件名
    static func generateFilename(quality: RecordingQuality, location: String? = nil) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateStr = formatter.string(from: Date())

        var name = "录音_\(dateStr)"
        if let loc = location, !loc.isEmpty {
            let safeLocation = loc.components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: "\u{4e00}-\u{9fff}")).inverted).joined()
            if !safeLocation.isEmpty {
                name += "_\(safeLocation.prefix(10))"
            }
        }
        return "\(name).\(quality.fileExtension)"
    }

    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm:ss"
        return formatter.string(from: startTime)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedFileSize: String {
        if fileSize < 1024 {
            return "\(fileSize) B"
        } else if fileSize < 1024 * 1024 {
            return String(format: "%.1f KB", Double(fileSize) / 1024)
        } else {
            return String(format: "%.1f MB", Double(fileSize) / (1024 * 1024))
        }
    }
}

// MARK: - 应用设置模型
struct AppSettings: Codable {
    var defaultQuality: RecordingQuality
    var enableShakeTrigger: Bool
    var shakeThreshold: Double
    var enableVolumeKeyTrigger: Bool
    var volumeKeyTapCount: Int
    var enableFloatButton: Bool
    var floatButtonX: Float
    var floatButtonY: Float
    var enableTimerTrigger: Bool
    var timerStartTime: Date?
    var timerStopTime: Date?
    var autoStopAfterMinutes: Int
    var saveToFilesApp: Bool
    var passwordEnabled: Bool
    var useBiometrics: Bool
    var passwordHash: String

    static var `default`: AppSettings {
        AppSettings(
            defaultQuality: .high,
            enableShakeTrigger: true,
            shakeThreshold: 2.5,
            enableVolumeKeyTrigger: true,
            volumeKeyTapCount: 2,
            enableFloatButton: false,
            floatButtonX: 0.9,
            floatButtonY: 0.3,
            enableTimerTrigger: false,
            timerStartTime: nil,
            timerStopTime: nil,
            autoStopAfterMinutes: 0,
            saveToFilesApp: false,
            passwordEnabled: false,
            useBiometrics: true,
            passwordHash: ""
        )
    }
}
