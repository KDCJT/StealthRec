// AuthViewController.swift
// StealthRec — PIN 密码 + 生物识别认证界面

import UIKit
import LocalAuthentication

class AuthViewController: UIViewController {

    var onAuthenticated: (() -> Void)?

    // MARK: - UI 组件
    private let containerView = UIView()
    private let logoView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let pinStack = UIStackView()
    private var pinDots: [UIView] = []
    private let numberPad = UIView()
    private var numberButtons: [UIButton] = []
    private let biometricButton = UIButton(type: .system)
    private let errorLabel = UILabel()
    private let forgotButton = UIButton(type: .system)

    private var enteredPIN = "" {
        didSet { updateDots() }
    }
    private let maxPINLength = 6
    private var failCount = 0

    // MARK: - 颜色系统
    private let bgColor = UIColor(hex: "#0D0D0F")
    private let cardColor = UIColor(hex: "#1A1A1E")
    private let accentRed = UIColor(hex: "#FF3B30")
    private let dotActiveColor = UIColor(hex: "#FF3B30")
    private let dotInactiveColor = UIColor(hex: "#2C2C2E")
    private let buttonBgColor = UIColor(hex: "#1C1C1E")

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bgColor
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 如果开启了生物识别，自动触发
        if PasswordManager.shared.isBiometricEnabled {
            tryBiometricAuth()
        }
    }

    // MARK: - UI 搭建
    private func setupUI() {
        setupBackground()
        setupLogo()
        setupPINDots()
        setupErrorLabel()
        setupNumberPad()
        setupBiometricButton()
        setupForgotButton()
        animateIn()
    }

    private func setupBackground() {
        // 渐变背景
        let gradient = CAGradientLayer()
        gradient.frame = view.bounds
        gradient.colors = [
            UIColor(hex: "#0D0D0F").cgColor,
            UIColor(hex: "#141418").cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradient, at: 0)
    }

    private func setupLogo() {
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 44, weight: .bold)
        logoView.image = UIImage(systemName: "mic.fill", withConfiguration: iconConfig)
        logoView.tintColor = accentRed
        logoView.contentMode = .scaleAspectFit

        titleLabel.text = "StealthRec"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center

        subtitleLabel.text = "输入密码以继续"
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        subtitleLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textAlignment = .center

        [logoView, titleLabel, subtitleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            logoView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            logoView.widthAnchor.constraint(equalToConstant: 60),
            logoView.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: 16),

            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8)
        ])
    }

    private func setupPINDots() {
        pinStack.axis = .horizontal
        pinStack.spacing = 16
        pinStack.alignment = .center

        for i in 0..<maxPINLength {
            let dot = UIView()
            dot.layer.cornerRadius = 10
            dot.backgroundColor = dotInactiveColor
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 20),
                dot.heightAnchor.constraint(equalToConstant: 20)
            ])
            dot.tag = i
            pinStack.addArrangedSubview(dot)
            pinDots.append(dot)
        }

        pinStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pinStack)

        NSLayoutConstraint.activate([
            pinStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 48)
        ])
    }

    private func setupErrorLabel() {
        errorLabel.textColor = accentRed
        errorLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        errorLabel.textAlignment = .center
        errorLabel.alpha = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorLabel)

        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.topAnchor.constraint(equalTo: pinStack.bottomAnchor, constant: 16)
        ])
    }

    private func setupNumberPad() {
        let digits = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"]
        let cols = 3
        let btnSize: CGFloat = 76
        let spacing: CGFloat = 16

        numberPad.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(numberPad)

        NSLayoutConstraint.activate([
            numberPad.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            numberPad.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 32),
            numberPad.widthAnchor.constraint(equalToConstant: CGFloat(cols) * (btnSize + spacing) - spacing),
            numberPad.heightAnchor.constraint(equalToConstant: 4 * (btnSize + spacing) - spacing)
        ])

        for (idx, digit) in digits.enumerated() {
            let row = idx / cols
            let col = idx % cols

            if digit.isEmpty { continue }

            let btn = UIButton(type: .custom)
            btn.setTitle(digit, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: digit == "⌫" ? 22 : 26, weight: .medium)
            btn.setTitleColor(.white, for: .normal)
            btn.backgroundColor = digit == "⌫" ? UIColor.clear : buttonBgColor
            btn.layer.cornerRadius = btnSize / 2
            btn.layer.borderWidth = digit == "⌫" ? 0 : 0
            btn.tag = idx
            btn.addTarget(self, action: #selector(numberTapped(_:)), for: .touchUpInside)

            // 按下效果
            btn.addTarget(self, action: #selector(buttonHighlight(_:)), for: .touchDown)
            btn.addTarget(self, action: #selector(buttonUnhighlight(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

            btn.translatesAutoresizingMaskIntoConstraints = false
            numberPad.addSubview(btn)

            NSLayoutConstraint.activate([
                btn.widthAnchor.constraint(equalToConstant: btnSize),
                btn.heightAnchor.constraint(equalToConstant: btnSize),
                btn.leftAnchor.constraint(equalTo: numberPad.leftAnchor, constant: CGFloat(col) * (btnSize + spacing)),
                btn.topAnchor.constraint(equalTo: numberPad.topAnchor, constant: CGFloat(row) * (btnSize + spacing))
            ])

            numberButtons.append(btn)
        }
    }

    private func setupBiometricButton() {
        guard PasswordManager.shared.isBiometricEnabled else { return }
        guard PasswordManager.shared.biometricType != .none else { return }

        let iconName = PasswordManager.shared.biometricType == .faceID ? "faceid" : "touchid"
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        biometricButton.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
        biometricButton.tintColor = UIColor.white.withAlphaComponent(0.7)
        biometricButton.addTarget(self, action: #selector(biometricTapped), for: .touchUpInside)
        biometricButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(biometricButton)

        NSLayoutConstraint.activate([
            biometricButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            biometricButton.topAnchor.constraint(equalTo: numberPad.bottomAnchor, constant: 24)
        ])
    }

    private func setupForgotButton() {
        forgotButton.setTitle("忘记密码？", for: .normal)
        forgotButton.setTitleColor(UIColor.white.withAlphaComponent(0.35), for: .normal)
        forgotButton.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        forgotButton.addTarget(self, action: #selector(forgotTapped), for: .touchUpInside)
        forgotButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(forgotButton)

        NSLayoutConstraint.activate([
            forgotButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            forgotButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - 动作
    @objc private func numberTapped(_ sender: UIButton) {
        let title = sender.title(for: .normal) ?? ""
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()

        if title == "⌫" {
            if !enteredPIN.isEmpty {
                enteredPIN.removeLast()
            }
        } else if enteredPIN.count < maxPINLength {
            enteredPIN += title
            if enteredPIN.count == maxPINLength {
                verify()
            }
        }
    }

    @objc private func buttonHighlight(_ sender: UIButton) {
        UIView.animate(withDuration: 0.08) {
            sender.backgroundColor = UIColor(hex: "#3A3A3C")
            sender.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        }
    }

    @objc private func buttonUnhighlight(_ sender: UIButton) {
        UIView.animate(withDuration: 0.12) {
            let title = sender.title(for: .normal) ?? ""
            sender.backgroundColor = title == "⌫" ? .clear : self.buttonBgColor
            sender.transform = .identity
        }
    }

    @objc private func biometricTapped() {
        tryBiometricAuth()
    }

    @objc private func forgotTapped() {
        let alert = UIAlertController(
            title: "忘记密码",
            message: "重置密码将清除所有设置。如需重置，请卸载并重新安装应用。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "明白了", style: .default))
        present(alert, animated: true)
    }

    // MARK: - 验证逻辑
    private func verify() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if PasswordManager.shared.verifyPassword(self.enteredPIN) {
                self.animateSuccess()
            } else {
                self.failCount += 1
                self.animateFailure()
                self.enteredPIN = ""
            }
        }
    }

    private func tryBiometricAuth() {
        PasswordManager.shared.authenticateWithBiometrics { [weak self] success, error in
            if success {
                self?.animateSuccess()
            }
        }
    }

    private func animateSuccess() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)

        // 所有小点变绿
        for dot in pinDots {
            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
                dot.backgroundColor = UIColor(hex: "#30D158")
                dot.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.onAuthenticated?()
        }
    }

    private func animateFailure() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.error)

        let errorMessages = ["密码错误", "密码错误，请重试", "密码错误", "再试一次"]
        errorLabel.text = failCount <= errorMessages.count ? errorMessages[failCount - 1] : "密码错误"

        UIView.animate(withDuration: 0.2) {
            self.errorLabel.alpha = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UIView.animate(withDuration: 0.2) { self.errorLabel.alpha = 0 }
        }

        // 震动动画
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.timingFunction = CAMediaTimingFunction(name: .linear)
        shake.duration = 0.5
        shake.values = [-14, 14, -10, 10, -6, 6, -3, 3, 0]
        pinStack.layer.add(shake, forKey: "shake")

        // 点变红
        for dot in pinDots {
            dot.backgroundColor = accentRed
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateDots()
        }
    }

    private func updateDots() {
        for (idx, dot) in pinDots.enumerated() {
            let filled = idx < enteredPIN.count
            UIView.animate(withDuration: 0.12) {
                dot.backgroundColor = filled ? self.dotActiveColor : self.dotInactiveColor
                dot.transform = filled ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
            }
        }
    }

    private func animateIn() {
        view.alpha = 0
        view.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5) {
            self.view.alpha = 1
            self.view.transform = .identity
        }
    }
}
