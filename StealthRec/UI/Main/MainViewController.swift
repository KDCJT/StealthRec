// MainViewController.swift
// StealthRec — 主界面：录音列表 + 实时录音指示

import UIKit
import AVFoundation

class MainViewController: UIViewController {

    // MARK: - 数据
    private var groupedRecordings: [(String, [RecordingMetadata])] = []
    private var filteredRecordings: [RecordingMetadata] = []
    private var isSearching = false

    // MARK: - UI 组件
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = UIColor(hex: "#0D0D0F")
        tv.separatorColor = UIColor.white.withAlphaComponent(0.08)
        tv.register(RecordingCell.self, forCellReuseIdentifier: RecordingCell.reuseID)
        tv.delegate = self
        tv.dataSource = self
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private lazy var searchController: UISearchController = {
        let sc = UISearchController(searchResultsController: nil)
        sc.searchResultsUpdater = self
        sc.obscuresBackgroundDuringPresentation = false
        sc.searchBar.placeholder = "搜索录音..."
        sc.searchBar.tintColor = UIColor(hex: "#FF3B30")
        return sc
    }()

    // 录音中横幅
    private let recordingBanner = RecordingBannerView()

    // 空状态视图
    private let emptyView = EmptyStateView()

    // 底部工具栏（编辑模式）
    private let editToolbar = UIToolbar()

    // MARK: - 颜色
    private let bgColor = UIColor(hex: "#0D0D0F")
    private let accentRed = UIColor(hex: "#FF3B30")

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupTableView()
        setupRecordingBanner()
        setupEmptyView()
        setupNotifications()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
        updateRecordingBanner()
    }

    // MARK: - 导航栏配置
    private func setupNavigation() {
        title = "StealthRec"
        view.backgroundColor = bgColor

        navigationItem.searchController = searchController

        // 右侧：设置按钮
        let settingsBtn = UIBarButtonItem(
            image: UIImage(systemName: "gearshape.fill"),
            style: .plain,
            target: self,
            action: #selector(openSettings)
        )
        settingsBtn.tintColor = UIColor.white.withAlphaComponent(0.7)

        // 左侧：编辑按钮
        let editBtn = UIBarButtonItem(
            title: "编辑",
            style: .plain,
            target: self,
            action: #selector(toggleEdit)
        )
        editBtn.tintColor = accentRed

        navigationItem.rightBarButtonItem = settingsBtn
        navigationItem.leftBarButtonItem = editBtn
    }

    // MARK: - 表格视图配置
    private func setupTableView() {
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - 录音中横幅
    private func setupRecordingBanner() {
        recordingBanner.translatesAutoresizingMaskIntoConstraints = false
        recordingBanner.isHidden = true
        view.addSubview(recordingBanner)

        recordingBanner.onStop = { [weak self] in
            RecordingEngine.shared.stopRecording()
            self?.updateRecordingBanner()
            self?.loadData()
        }

        NSLayoutConstraint.activate([
            recordingBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            recordingBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            recordingBanner.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            recordingBanner.heightAnchor.constraint(equalToConstant: 72)
        ])
    }

    // MARK: - 空状态视图
    private func setupEmptyView() {
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.isHidden = true
        view.addSubview(emptyView)

        NSLayoutConstraint.activate([
            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
    }

    // MARK: - 通知监听
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(recordingStateChanged),
            name: .recordingStateChanged, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(recordingLevelChanged(_:)),
            name: .recordingLevelUpdated, object: nil
        )
    }

    @objc private func recordingStateChanged() {
        DispatchQueue.main.async {
            self.updateRecordingBanner()
            self.loadData()
        }
    }

    @objc private func recordingLevelChanged(_ notification: Notification) {
        if let level = notification.userInfo?["level"] as? Float {
            DispatchQueue.main.async {
                self.recordingBanner.updateLevel(level)
            }
        }
    }

    // MARK: - 数据加载
    private func loadData() {
        groupedRecordings = RecordingStore.shared.groupedByDate()
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        let isEmpty = groupedRecordings.isEmpty && !isSearching
        emptyView.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }

    private func updateRecordingBanner() {
        let isRecording = RecordingEngine.shared.isRecording
        UIView.animate(withDuration: 0.3) {
            self.recordingBanner.isHidden = !isRecording
        }
        if isRecording, let metadata = RecordingEngine.shared.currentMetadata {
            recordingBanner.configure(with: metadata)
        }
    }

    // MARK: - 操作
    @objc private func openSettings() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }

    @objc private func toggleEdit() {
        let editing = !tableView.isEditing
        tableView.setEditing(editing, animated: true)
        navigationItem.leftBarButtonItem?.title = editing ? "完成" : "编辑"

        if editing {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "全部删除",
                style: .plain,
                target: self,
                action: #selector(deleteAll)
            )
            navigationItem.rightBarButtonItem?.tintColor = accentRed
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "gearshape.fill"),
                style: .plain,
                target: self,
                action: #selector(openSettings)
            )
            navigationItem.rightBarButtonItem?.tintColor = UIColor.white.withAlphaComponent(0.7)
        }
    }

    @objc private func deleteAll() {
        let alert = UIAlertController(
            title: "删除全部录音",
            message: "即将删除所有录音文件，此操作不可撤销。",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "删除全部", style: .destructive) { [weak self] _ in
            let all = RecordingStore.shared.loadAll()
            RecordingStore.shared.delete(ids: all.map(\.id))
            self?.loadData()
            self?.toggleEdit()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension MainViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? 1 : groupedRecordings.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? filteredRecordings.count : groupedRecordings[section].1.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return isSearching ? "搜索结果" : groupedRecordings[section].0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RecordingCell.reuseID, for: indexPath) as! RecordingCell
        let metadata = isSearching ? filteredRecordings[indexPath.row] : groupedRecordings[indexPath.section].1[indexPath.row]
        cell.configure(with: metadata)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }

    // 滑动删除
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let metadata = isSearching ? filteredRecordings[indexPath.row] : groupedRecordings[indexPath.section].1[indexPath.row]

        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            RecordingStore.shared.delete(metadata: metadata)
            self?.loadData()
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")

        let exportAction = UIContextualAction(style: .normal, title: "导出") { [weak self] _, _, completion in
            self?.exportRecording(metadata: metadata)
            completion(true)
        }
        exportAction.image = UIImage(systemName: "square.and.arrow.up")
        exportAction.backgroundColor = UIColor(hex: "#0A84FF")

        return UISwipeActionsConfiguration(actions: [deleteAction, exportAction])
    }

    // 编辑模式删除
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let metadata = isSearching ? filteredRecordings[indexPath.row] : groupedRecordings[indexPath.section].1[indexPath.row]
            RecordingStore.shared.delete(metadata: metadata)
            loadData()
        }
    }

    private func exportRecording(metadata: RecordingMetadata) {
        RecordingStore.shared.exportToFiles(metadata: metadata) { [weak self] success, url in
            DispatchQueue.main.async {
                if success, let url = url {
                    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    self?.present(activityVC, animated: true)
                } else {
                    let alert = UIAlertController(title: "导出失败", message: "无法导出录音文件", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
}

// MARK: - UITableViewDelegate
extension MainViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let metadata = isSearching ? filteredRecordings[indexPath.row] : groupedRecordings[indexPath.section].1[indexPath.row]
        let detailVC = RecordingDetailViewController(metadata: metadata)
        navigationController?.pushViewController(detailVC, animated: true)
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = UIColor.white.withAlphaComponent(0.5)
            header.textLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        }
    }
}

// MARK: - UISearchResultsUpdating
extension MainViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text ?? ""
        isSearching = !query.isEmpty
        filteredRecordings = RecordingStore.shared.search(query: query)
        tableView.reloadData()
        updateEmptyState()
    }
}

// MARK: - 录音中横幅 View
class RecordingBannerView: UIView {

    var onStop: (() -> Void)?

    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let waveView = WaveformView()
    private let stopButton = UIButton(type: .system)
    private var timer: Timer?
    private var elapsed: TimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = UIColor(hex: "#1C1C1E")
        layer.cornerRadius = 16
        layer.borderWidth = 1.5
        layer.borderColor = UIColor(hex: "#FF3B30").withAlphaComponent(0.6).cgColor

        // 脉冲红点
        let dot = UIView()
        dot.backgroundColor = UIColor(hex: "#FF3B30")
        dot.layer.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dot)

        titleLabel.text = "正在录音"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        timeLabel.text = "00:00"
        timeLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(timeLabel)

        stopButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        stopButton.tintColor = UIColor(hex: "#FF3B30")
        stopButton.backgroundColor = UIColor(hex: "#FF3B30").withAlphaComponent(0.15)
        stopButton.layer.cornerRadius = 22
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stopButton)

        waveView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(waveView)

        NSLayoutConstraint.activate([
            dot.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            dot.widthAnchor.constraint(equalToConstant: 10),
            dot.heightAnchor.constraint(equalToConstant: 10),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 10),

            timeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            waveView.leadingAnchor.constraint(equalTo: timeLabel.trailingAnchor, constant: 12),
            waveView.centerYAnchor.constraint(equalTo: timeLabel.centerYAnchor),
            waveView.widthAnchor.constraint(equalToConstant: 80),
            waveView.heightAnchor.constraint(equalToConstant: 20),

            stopButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            stopButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stopButton.widthAnchor.constraint(equalToConstant: 44),
            stopButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        // 红点脉冲动画
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.2
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        dot.layer.add(pulse, forKey: "pulse")
    }

    func configure(with metadata: RecordingMetadata) {
        elapsed = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsed += 1
            self?.updateTime()
        }
    }

    func updateLevel(_ level: Float) {
        waveView.pushLevel(level)
    }

    @objc private func stopTapped() {
        timer?.invalidate()
        onStop?()
    }

    private func updateTime() {
        let m = Int(elapsed) / 60
        let s = Int(elapsed) % 60
        timeLabel.text = String(format: "%02d:%02d", m, s)
    }
}

// MARK: - 实时波形视图
class WaveformView: UIView {

    private var levels: [Float] = Array(repeating: 0, count: 30)
    private let barWidth: CGFloat = 2
    private let barSpacing: CGFloat = 1.5

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    func pushLevel(_ level: Float) {
        levels.removeFirst()
        levels.append(level)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)

        let barColor = UIColor(hex: "#FF3B30")
        let totalBars = levels.count
        let totalWidth = CGFloat(totalBars) * (barWidth + barSpacing) - barSpacing
        let startX = (rect.width - totalWidth) / 2

        for (i, level) in levels.enumerated() {
            let barHeight = max(3, CGFloat(level) * rect.height)
            let x = startX + CGFloat(i) * (barWidth + barSpacing)
            let y = (rect.height - barHeight) / 2

            let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            let path = UIBezierPath(roundedRect: barRect, cornerRadius: 1)

            let alpha = 0.4 + CGFloat(i) / CGFloat(totalBars) * 0.6
            barColor.withAlphaComponent(alpha).setFill()
            path.fill()
        }
    }
}

// MARK: - 空状态视图
class EmptyStateView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        let config = UIImage.SymbolConfiguration(pointSize: 56, weight: .thin)
        let iconView = UIImageView(image: UIImage(systemName: "waveform", withConfiguration: config))
        iconView.tintColor = UIColor.white.withAlphaComponent(0.15)
        iconView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = "暂无录音"
        label.textColor = UIColor.white.withAlphaComponent(0.3)
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)

        let sublabel = UILabel()
        sublabel.text = "摇动手机或按音量键开始录音"
        sublabel.textColor = UIColor.white.withAlphaComponent(0.2)
        sublabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        sublabel.textAlignment = .center
        sublabel.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [iconView, label, sublabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.heightAnchor.constraint(equalToConstant: 80),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.8)
        ])
    }
}
