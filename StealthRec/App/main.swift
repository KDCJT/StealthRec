// main.swift
// 极简诊断版本 — 替代 @main AppDelegate
// 在这里我们完全不使用任何自定义类型，只用纯 UIKit 来证明是代码问题还是环境问题

import UIKit
import Foundation

// 必须在 main 之前写日志（Objective-C +load 相当于最早能运行的用户代码）
// 我们用 C 级别的函数确保不依赖任何框架初始化
func writeBootLog() {
    let docsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "/tmp"
    let logPath = docsPath + "/BOOT_DEBUG.log"
    let msg = "BOOT: main() called at \(Date())\n"
    try? msg.write(toFile: logPath, atomically: true, encoding: .utf8)
}

writeBootLog()

// 极简 AppDelegate — 不初始化任何复杂的单例
class MinimalAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 立即写日志
        let docsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "/tmp"
        let logPath = docsPath + "/BOOT_DEBUG.log"
        let existing = (try? String(contentsOfFile: logPath, encoding: .utf8)) ?? ""
        let msg = existing + "APP_DELEGATE: didFinishLaunching called\n"
        try? msg.write(toFile: logPath, atomically: true, encoding: .utf8)
        
        // 创建最简单的 Window + ViewController
        window = UIWindow(frame: UIScreen.main.bounds)
        
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        
        let label = UILabel()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        label.text = "GhostRec\nv\(version) (Build \(build))\n\n✅ App is running!\n\nLog: \(logPath)"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
            label.widthAnchor.constraint(equalTo: vc.view.widthAnchor, multiplier: 0.8)
        ])
        
        let appendMsg = (try? String(contentsOfFile: logPath, encoding: .utf8)) ?? ""
        try? (appendMsg + "APP_DELEGATE: Window created successfully\n").write(toFile: logPath, atomically: true, encoding: .utf8)
        
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        return true
    }
}

// 启动
UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    nil,
    NSStringFromClass(MinimalAppDelegate.self)
)
