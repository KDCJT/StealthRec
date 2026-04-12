// SettingsManager.swift
// StealthRec — 设置持久化管理

import Foundation

final class SettingsManager {

    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard
    private let settingsKey = "StealthRec.AppSettings"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private(set) var settings: AppSettings = .default

    private init() {
        load()
    }

    func load() {
        if let data = defaults.data(forKey: settingsKey),
           let loaded = try? decoder.decode(AppSettings.self, from: data) {
            settings = loaded
        }
    }

    func save() {
        if let data = try? encoder.encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }

    func update(_ block: (inout AppSettings) -> Void) {
        block(&settings)
        save()
    }

    func updateFloatButtonPosition(x: Float, y: Float) {
        settings.floatButtonX = x
        settings.floatButtonY = y
        save()
    }
}
