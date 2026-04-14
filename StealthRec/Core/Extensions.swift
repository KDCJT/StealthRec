// Extensions.swift
// StealthRec — 全局扩展工具集
// 注意：UIColor(hex:) 已在 SceneDelegate.swift 末尾定义，此处不重复

import UIKit

// MARK: - UIView 快速阴影
extension UIView {
    func addShadow(color: UIColor = .black, opacity: Float = 0.25,
                   radius: CGFloat = 8, offset: CGSize = CGSize(width: 0, height: 2)) {
        layer.shadowColor   = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowRadius  = radius
        layer.shadowOffset  = offset
        layer.masksToBounds = false
    }
}

// MARK: - Date 格式化工具
extension Date {
    /// "yyyy-MM-dd HH:mm:ss"
    var fullString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: self)
    }

    /// "M月d日 HH:mm"
    var shortString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: self)
    }
}

// MARK: - TimeInterval 格式化
extension TimeInterval {
    /// 转为 "mm:ss" 或 "h:mm:ss"
    var durationString: String {
        let h = Int(self) / 3600
        let m = Int(self) / 60 % 60
        let s = Int(self) % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}
