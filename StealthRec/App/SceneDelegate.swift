// SceneDelegate.swift
// StealthRec — 场景生命周期

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)

        let settings = SettingsManager.shared.settings

        if settings.passwordEnabled {
            // 显示认证界面
            let authVC = AuthViewController()
            authVC.onAuthenticated = {
                self.showMainInterface(window: window)
            }
            window.rootViewController = authVC
        } else {
            showMainInterface(window: window)
        }

        self.window = window
        window.makeKeyAndVisible()
    }

    private func showMainInterface(window: UIWindow) {
        let mainVC = MainViewController()
        let nav = UINavigationController(rootViewController: mainVC)
        nav.navigationBar.prefersLargeTitles = true
        applyDarkTheme(to: nav)
        window.rootViewController = nav
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

    func sceneWillResignActive(_ scene: UIScene) {}

    func sceneDidEnterBackground(_ scene: UIScene) {
        // 进入后台时，若需要密码，锁定界面状态（但不实际修改 window，避免中断录音）
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // 如果设置了密码，从后台回来需要重新认证
        let settings = SettingsManager.shared.settings
        if settings.passwordEnabled,
           let window = window,
           !(window.rootViewController is AuthViewController) {
            let authVC = AuthViewController()
            authVC.onAuthenticated = {
                self.showMainInterface(window: window)
            }
            // 淡入遮罩，不打断后台录音
            window.rootViewController = authVC
        }
    }
}

// MARK: - UIColor 十六进制扩展
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
