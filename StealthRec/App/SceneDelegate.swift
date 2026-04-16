// SceneDelegate.swift
// StealthRec — 保留文件以防编译引用，但不再被 Info.plist 激活
// 注意：本 App 使用传统 AppDelegate+UIWindow 方式，不使用 Scene-based lifecycle
// Info.plist 中不包含 UIApplicationSceneManifest，此文件在运行时不会被调用

import UIKit

// 保留类定义以通过编译，但此类不会被 iOS 实例化
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
}

// MARK: - UIColor 十六进制扩展（全局共享）
extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexStr.hasPrefix("#") { hexStr.removeFirst() }

        var rgb: UInt64 = 0
        Scanner(string: hexStr).scanHexInt64(&rgb)

        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >> 8) & 0xFF) / 255
        let b = CGFloat(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
