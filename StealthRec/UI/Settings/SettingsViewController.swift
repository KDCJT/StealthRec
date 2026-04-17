// SettingsViewController.swift
// StealthRec — 设置界面

import UIKit
import LocalAuthentication

class SettingsViewController: UIViewController {

    private var settings: AppSettings { SettingsManager.shared.settings }

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = UIColor(hex: "#0D0D0F")
        tv.separatorColor = UIColor.white.withAlphaComponent(0.08)
        tv.delegate = self
        tv.dataSource = self
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let bgColor = UIColor(hex: "#0D0D0F")
    private let accentRed = UIColor(hex: "#FF3B30")

    // MARK: - Sections
    private enum Section: Int, CaseIterable {
        case recording = 0
        case trigger
        case security
        case storage
        case about

        var title: String {
            switch self {
            case .recording: return "录音设置"
            case .trigger:   return "触发方式"
            case .security:  return "安全与隐私"
            case .storage:   return "存储"
            case .about:     return "关于"
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        view.backgroundColor = bgColor
        setupTableView()
    }

    private func setupTableView() {
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Cell 构建助手
    private func makeToggleCell(title: String, isOn: Bool, tag: Int) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = UIColor(hex: "#1A1A1E")
        cell.textLabel?.text = title
        cell.textLabel?.textColor = .white
        cell.selectionStyle = .none

        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.onTintColor = accentRed
        toggle.tag = tag
        toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle
        return cell
    }

    private func makeDetailCell(title: String, detail: String) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = UIColor(hex: "#1A1A1E")
        cell.textLabel?.text = title
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.text = detail
        cell.detailTextLabel?.textColor = UIColor.white.withAlphaComponent(0.4)
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    private func makeActionCell(title: String, color: UIColor = .white) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = UIColor(hex: "#1A1A1E")
        cell.textLabel?.text = title
        cell.textLabel?.textColor = color
        cell.textLabel?.textAlignment = .center
        return cell
    }

    private func makeDatePickerCell(title: String, date: Date?, tag: Int) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = UIColor(hex: "#1A1A1E")
        cell.textLabel?.text = title
        cell.textLabel?.textColor = .white
        cell.selectionStyle = .none
        
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .inline
        picker.date = date ?? Date()
        picker.tintColor = accentRed
        picker.tag = tag
        picker.addTarget(self, action: #selector(datePickerChanged(_:)), for: .valueChanged)
        
        cell.accessoryView = picker
        return cell
    }

    // MARK: - Toggle 处理
    @objc private func toggleChanged(_ sender: UISwitch) {
        switch sender.tag {
        case 100: // 摇动触发
            SettingsManager.shared.update { $0.enableShakeTrigger = sender.isOn }
        case 101: // 音量键触发
            SettingsManager.shared.update { $0.enableVolumeKeyTrigger = sender.isOn }
        case 102: // 悬浮按钮
            SettingsManager.shared.update { $0.enableFloatButton = sender.isOn }
        case 104: // 定时触发
            SettingsManager.shared.update { $0.enableTimerTrigger = sender.isOn }
            tableView.reloadData()
        case 200: // 密码保护
            if sender.isOn {
                showSetPasswordAlert()
            } else {
                SettingsManager.shared.update {
                    $0.passwordEnabled = false
                    $0.passwordHash = ""
                }
                PasswordManager.shared.removePassword()
            }
        case 201: // 生物识别
            SettingsManager.shared.update { $0.useBiometrics = sender.isOn }
            PasswordManager.shared.setBiometricEnabled(sender.isOn)
        default:
            break
        }

        // 重启触发器
        TriggerManager.shared.startAll(settings: SettingsManager.shared.settings)
    }

    // MARK: - DatePicker 处理
    @objc private func datePickerChanged(_ sender: UIDatePicker) {
        if sender.tag == 300 {
            SettingsManager.shared.update { $0.timerStartTime = sender.date }
        } else if sender.tag == 301 {
            SettingsManager.shared.update { $0.timerStopTime = sender.date }
        }
        TriggerManager.shared.startAll(settings: SettingsManager.shared.settings)
    }

    // MARK: - 设置密码
    private func showSetPasswordAlert() {
        let vc = SetPasswordViewController()
        vc.onPasswordSet = { [weak self] in
            SettingsManager.shared.update { $0.passwordEnabled = true }
            self?.tableView.reloadData()
        }
        vc.onCancel = { [weak self] in
            SettingsManager.shared.update { $0.passwordEnabled = false }
            self?.tableView.reloadData()
        }
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    // MARK: - 录音质量选择
    private func showQualityPicker() {
        let alert = UIAlertController(title: "录音质量", message: nil, preferredStyle: .actionSheet)
        for quality in RecordingQuality.allCases {
            let action = UIAlertAction(title: quality.displayName, style: .default) { [weak self] _ in
                SettingsManager.shared.update { $0.defaultQuality = quality }
                self?.tableView.reloadData()
            }
            if quality == settings.defaultQuality {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - 自动停录设置
    private func showAutoStopPicker() {
        let options = [0, 5, 10, 15, 30, 60, 120]
        let alert = UIAlertController(title: "自动停录", message: "设置最长录音时间（分钟）", preferredStyle: .actionSheet)
        for minutes in options {
            let title = minutes == 0 ? "不限制" : "\(minutes) 分钟"
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                SettingsManager.shared.update { $0.autoStopAfterMinutes = minutes }
                self?.tableView.reloadData()
            }
            if minutes == settings.autoStopAfterMinutes {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - 存储信息
    private func showStorageInfo() {
        let total = RecordingStore.shared.totalStorageUsed()
        let count = RecordingStore.shared.loadAll().count
        let message = "共 \(count) 条录音\n占用空间：\(formatBytes(total))"
        let alert = UIAlertController(title: "存储信息", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        else if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        else { return String(format: "%.1f MB", Double(bytes) / (1024 * 1024)) }
    }
}

// MARK: - UITableViewDataSource / Delegate
extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .recording: return 2
        case .trigger:   return settings.enableTimerTrigger ? 6 : 4  // 摇动、音量键、悬浮按钮、定时 (+2 开始结束时间)
        case .security:  return 2
        case .storage:   return 1
        case .about:     return 1
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = UIColor.white.withAlphaComponent(0.5)
            header.textLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {

        case .recording:
            if indexPath.row == 0 {
                return makeDetailCell(title: "默认录音质量", detail: settings.defaultQuality.displayName)
            } else {
                let mins = settings.autoStopAfterMinutes
                let detail = mins == 0 ? "不限制" : "\(mins) 分钟"
                return makeDetailCell(title: "自动停录", detail: detail)
            }

        case .trigger:
            switch indexPath.row {
            case 0: return makeToggleCell(title: "摇动手机", isOn: settings.enableShakeTrigger, tag: 100)
            case 1: return makeToggleCell(title: "音量键快速连按", isOn: settings.enableVolumeKeyTrigger, tag: 101)
            case 2: return makeToggleCell(title: "悬浮快捷按钮", isOn: settings.enableFloatButton, tag: 102)
            case 3: return makeToggleCell(title: "定时录音", isOn: settings.enableTimerTrigger, tag: 104)
            case 4: return makeDatePickerCell(title: "开始时间", date: settings.timerStartTime, tag: 300)
            case 5: return makeDatePickerCell(title: "结束时间", date: settings.timerStopTime, tag: 301)
            default: return UITableViewCell()
            }

        case .security:
            if indexPath.row == 0 {
                return makeToggleCell(title: "密码保护", isOn: settings.passwordEnabled, tag: 200)
            } else {
                let biometricName = PasswordManager.shared.biometricTypeName
                return makeToggleCell(
                    title: "使用 \(biometricName)",
                    isOn: settings.useBiometrics && PasswordManager.shared.biometricType != .none,
                    tag: 201
                )
            }

        case .storage:
            return makeDetailCell(title: "存储信息", detail: "查看")

        case .about:
            return makeDetailCell(title: "StealthRec v1.0", detail: "iOS 15 · 巨魔侧载")
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section(rawValue: indexPath.section)! {
        case .recording:
            if indexPath.row == 0 { showQualityPicker() }
            else { showAutoStopPicker() }
        case .storage:
            showStorageInfo()
        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .trigger:
            return "多种触发方式可同时开启。音量键连按检测时，音量会自动恢复到50%避免影响系统音量。"
        case .security:
            return "密码用于保护录音管理界面。录音触发不受密码影响，可在锁屏下正常工作。"
        default:
            return nil
        }
    }
}

// MARK: - 设置密码界面
class SetPasswordViewController: UIViewController {

    var onPasswordSet: (() -> Void)?
    var onCancel: (() -> Void)?

    private var firstPIN = ""
    private var isConfirming = false

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let pinStack = UIStackView()
    private var pinDots: [UIView] = []
    private var enteredPIN = "" {
        didSet { updateDots() }
    }

    private let bgColor = UIColor(hex: "#0D0D0F")
    private let accentRed = UIColor(hex: "#FF3B30")

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置密码"
        view.backgroundColor = bgColor
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消", style: .plain, target: self, action: #selector(cancelTapped)
        )
        setupUI()
    }

    private func setupUI() {
        titleLabel.text = "设置 6 位 PIN 码"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textAlignment = .center

        subtitleLabel.text = "输入密码"
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        subtitleLabel.font = UIFont.systemFont(ofSize: 15)
        subtitleLabel.textAlignment = .center

        // PIN 点
        for i in 0..<6 {
            let dot = UIView()
            dot.layer.cornerRadius = 10
            dot.backgroundColor = UIColor(hex: "#2C2C2E")
            dot.widthAnchor.constraint(equalToConstant: 20).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 20).isActive = true
            dot.tag = i
            pinStack.addArrangedSubview(dot)
            pinDots.append(dot)
        }
        pinStack.axis = .horizontal
        pinStack.spacing = 16

        // 数字键盘（复用 AuthViewController 的逻辑）
        let digits = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"]
        let padView = UIView()
        let btnSize: CGFloat = 72
        let spacing: CGFloat = 16

        for (idx, digit) in digits.enumerated() {
            if digit.isEmpty { continue }
            let row = idx / 3, col = idx % 3
            let btn = UIButton(type: .custom)
            btn.setTitle(digit, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: digit == "⌫" ? 20 : 24, weight: .medium)
            btn.setTitleColor(.white, for: .normal)
            btn.backgroundColor = digit == "⌫" ? .clear : UIColor(hex: "#1C1C1E")
            btn.layer.cornerRadius = btnSize / 2
            btn.tag = idx
            btn.addTarget(self, action: #selector(digitTapped(_:)), for: .touchUpInside)
            btn.translatesAutoresizingMaskIntoConstraints = false
            padView.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.widthAnchor.constraint(equalToConstant: btnSize),
                btn.heightAnchor.constraint(equalToConstant: btnSize),
                btn.leftAnchor.constraint(equalTo: padView.leftAnchor, constant: CGFloat(col) * (btnSize + spacing)),
                btn.topAnchor.constraint(equalTo: padView.topAnchor, constant: CGFloat(row) * (btnSize + spacing))
            ])
        }
        padView.translatesAutoresizingMaskIntoConstraints = false
        let padW = 3 * (btnSize + spacing) - spacing
        let padH = 4 * (btnSize + spacing) - spacing

        let mainStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, pinStack, padView])
        mainStack.axis = .vertical
        mainStack.spacing = 32
        mainStack.alignment = .center
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            padView.widthAnchor.constraint(equalToConstant: padW),
            padView.heightAnchor.constraint(equalToConstant: padH),
            mainStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainStack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20)
        ])
    }

    @objc private func digitTapped(_ sender: UIButton) {
        let title = sender.title(for: .normal) ?? ""
        if title == "⌫" {
            if !enteredPIN.isEmpty { enteredPIN.removeLast() }
        } else if enteredPIN.count < 6 {
            enteredPIN += title
            if enteredPIN.count == 6 { processInput() }
        }
    }

    private func processInput() {
        if !isConfirming {
            firstPIN = enteredPIN
            enteredPIN = ""
            isConfirming = true
            (view.viewWithTag(999) as? UILabel)?.text = "再次输入确认"
            subtitleLabel.text = "再次输入以确认"
        } else {
            if enteredPIN == firstPIN {
                PasswordManager.shared.setPassword(enteredPIN)
                onPasswordSet?()
                dismiss(animated: true)
            } else {
                enteredPIN = ""
                isConfirming = false
                firstPIN = ""
                subtitleLabel.text = "两次输入不一致，请重新设置"
                subtitleLabel.textColor = accentRed
                let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
                shake.timingFunction = CAMediaTimingFunction(name: .linear)
                shake.duration = 0.4
                shake.values = [-10, 10, -8, 8, -4, 4, 0]
                pinStack.layer.add(shake, forKey: "shake")
            }
        }
    }

    private func updateDots() {
        for (idx, dot) in pinDots.enumerated() {
            let filled = idx < enteredPIN.count
            UIView.animate(withDuration: 0.1) {
                dot.backgroundColor = filled ? self.accentRed : UIColor(hex: "#2C2C2E")
            }
        }
    }

    @objc private func cancelTapped() {
        onCancel?()
        dismiss(animated: true)
    }
}
