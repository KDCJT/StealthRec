// PasswordManager.swift
// StealthRec — PIN 密码 + Face ID / Touch ID 认证管理

import Foundation
import LocalAuthentication
import CryptoKit

final class PasswordManager {

    static let shared = PasswordManager()

    private let defaults = UserDefaults.standard
    private let hashKey = "StealthRec.PasswordHash"

    // 强引用 LAContext，防止被自动释放导致 Face/Touch ID 的弹窗被悄悄取消
    private var authContext: LAContext?

    private init() {}

    // MARK: - 状态查询
    var isPasswordEnabled: Bool {
        return SettingsManager.shared.settings.passwordEnabled
    }

    var isBiometricEnabled: Bool {
        return SettingsManager.shared.settings.useBiometrics
    }

    var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return context.biometryType
        }
        return .none
    }

    var biometricTypeName: String {
        switch biometricType {
        case .faceID:   return "Face ID"
        case .touchID:  return "Touch ID"
        default:        return "生物识别"
        }
    }

    // MARK: - 设置密码
    func setPassword(_ pin: String) {
        let hash = hashPassword(pin)
        defaults.set(hash, forKey: hashKey)
        SettingsManager.shared.update { $0.passwordEnabled = true }
    }

    func removePassword() {
        defaults.removeObject(forKey: hashKey)
        SettingsManager.shared.update { $0.passwordEnabled = false }
    }

    func setBiometricEnabled(_ enabled: Bool) {
        SettingsManager.shared.update { $0.useBiometrics = enabled }
    }

    // MARK: - 验证 PIN 密码
    func verifyPassword(_ pin: String) -> Bool {
        guard let storedHash = defaults.string(forKey: hashKey) else { return false }
        return hashPassword(pin) == storedHash
    }

    // MARK: - 生物识别验证
    func authenticateWithBiometrics(reason: String = "验证身份以访问录音", completion: @escaping (Bool, Error?) -> Void) {
        authContext = LAContext()
        var error: NSError?

        guard let context = authContext, context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(false, error)
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        ) { [weak self] success, authError in
            DispatchQueue.main.async {
                completion(success, authError)
                self?.authContext = nil
            }
        }
    }

    // MARK: - 哈希函数（SHA-256）
    private func hashPassword(_ pin: String) -> String {
        let salt = "StealthRec_Salt_2024"
        let input = salt + pin
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
