// RecordingDetailViewController.swift
// StealthRec — 录音详情 + 播放界面

import UIKit
import AVFoundation
import MapKit

class RecordingDetailViewController: UIViewController {

    private var metadata: RecordingMetadata
    private var audioPlayer: AVAudioPlayer?
    private var playTimer: Timer?
    private var isPlaying = false

    // MARK: - UI 组件
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // 播放器
    private let playerCard = UIView()
    private let waveformBar = UIProgressView()
    private let currentTimeLabel = UILabel()
    private let totalTimeLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private let speedButton = UIButton(type: .system)
    private var playbackSpeed: Float = 1.0

    // 信息卡片
    private let infoCard = UIView()
    private let mapView = MKMapView()

    // MARK: - 颜色
    private let bgColor = UIColor(hex: "#0D0D0F")
    private let cardColor = UIColor(hex: "#1A1A1E")
    private let accentRed = UIColor(hex: "#FF3B30")

    // MARK: - 初始化
    init(metadata: RecordingMetadata) {
        self.metadata = metadata
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupScrollView()
        setupPlayerCard()
        setupInfoCard()
        if metadata.location != nil {
            setupMapCard()
        }
        setupActionsCard()
        preparePlayer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlayback()
    }

    // MARK: - 导航栏
    private func setupNavigation() {
        view.backgroundColor = bgColor
        title = metadata.title.isEmpty ? "录音详情" : metadata.title

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.pencil"),
            style: .plain,
            target: self,
            action: #selector(editTitle)
        )
        navigationItem.rightBarButtonItem?.tintColor = accentRed
    }

    // MARK: - 滚动视图
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    // MARK: - 播放器卡片
    private func setupPlayerCard() {
        playerCard.backgroundColor = cardColor
        playerCard.layer.cornerRadius = 16
        playerCard.translatesAutoresizingMaskIntoConstraints = false

        // 文件名标签
        let filenameLabel = UILabel()
        filenameLabel.text = metadata.filename
        filenameLabel.textColor = UIColor.white.withAlphaComponent(0.4)
        filenameLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        filenameLabel.numberOfLines = 1

        // 时长显示
        let durationLabel = UILabel()
        durationLabel.text = metadata.formattedDuration
        durationLabel.textColor = .white
        durationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 48, weight: .thin)
        durationLabel.textAlignment = .center

        // 进度条
        waveformBar.progressTintColor = accentRed
        waveformBar.trackTintColor = UIColor.white.withAlphaComponent(0.1)
        waveformBar.layer.cornerRadius = 3
        waveformBar.clipsToBounds = true
        waveformBar.progress = 0

        // 时间标签
        currentTimeLabel.text = "00:00"
        currentTimeLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        currentTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)

        totalTimeLabel.text = metadata.formattedDuration
        totalTimeLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        totalTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        totalTimeLabel.textAlignment = .right

        // 播放按钮
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)
        playButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
        playButton.tintColor = .white
        playButton.backgroundColor = accentRed
        playButton.layer.cornerRadius = 36
        playButton.addTarget(self, action: #selector(togglePlayback), for: .touchUpInside)

        // 速度按钮
        speedButton.setTitle("1×", for: .normal)
        speedButton.setTitleColor(UIColor.white.withAlphaComponent(0.6), for: .normal)
        speedButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        speedButton.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        speedButton.layer.cornerRadius = 14
        speedButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        speedButton.addTarget(self, action: #selector(toggleSpeed), for: .touchUpInside)

        // 快退/快进按钮
        let rewindConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let rewindBtn = UIButton(type: .system)
        rewindBtn.setImage(UIImage(systemName: "gobackward.15", withConfiguration: rewindConfig), for: .normal)
        rewindBtn.tintColor = UIColor.white.withAlphaComponent(0.7)
        rewindBtn.addTarget(self, action: #selector(rewind), for: .touchUpInside)

        let forwardBtn = UIButton(type: .system)
        forwardBtn.setImage(UIImage(systemName: "goforward.15", withConfiguration: rewindConfig), for: .normal)
        forwardBtn.tintColor = UIColor.white.withAlphaComponent(0.7)
        forwardBtn.addTarget(self, action: #selector(forward), for: .touchUpInside)

        [filenameLabel, durationLabel, waveformBar, currentTimeLabel, totalTimeLabel,
         playButton, speedButton, rewindBtn, forwardBtn].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            playerCard.addSubview($0)
        }

        NSLayoutConstraint.activate([
            playerCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),

            filenameLabel.topAnchor.constraint(equalTo: playerCard.topAnchor, constant: 16),
            filenameLabel.leadingAnchor.constraint(equalTo: playerCard.leadingAnchor, constant: 20),
            filenameLabel.trailingAnchor.constraint(equalTo: playerCard.trailingAnchor, constant: -20),

            durationLabel.topAnchor.constraint(equalTo: filenameLabel.bottomAnchor, constant: 8),
            durationLabel.centerXAnchor.constraint(equalTo: playerCard.centerXAnchor),

            waveformBar.topAnchor.constraint(equalTo: durationLabel.bottomAnchor, constant: 20),
            waveformBar.leadingAnchor.constraint(equalTo: playerCard.leadingAnchor, constant: 20),
            waveformBar.trailingAnchor.constraint(equalTo: playerCard.trailingAnchor, constant: -20),
            waveformBar.heightAnchor.constraint(equalToConstant: 6),

            currentTimeLabel.topAnchor.constraint(equalTo: waveformBar.bottomAnchor, constant: 6),
            currentTimeLabel.leadingAnchor.constraint(equalTo: waveformBar.leadingAnchor),
            totalTimeLabel.topAnchor.constraint(equalTo: waveformBar.bottomAnchor, constant: 6),
            totalTimeLabel.trailingAnchor.constraint(equalTo: waveformBar.trailingAnchor),

            rewindBtn.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            rewindBtn.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -28),
            rewindBtn.widthAnchor.constraint(equalToConstant: 44),
            rewindBtn.heightAnchor.constraint(equalToConstant: 44),

            playButton.centerXAnchor.constraint(equalTo: playerCard.centerXAnchor),
            playButton.topAnchor.constraint(equalTo: currentTimeLabel.bottomAnchor, constant: 20),
            playButton.widthAnchor.constraint(equalToConstant: 72),
            playButton.heightAnchor.constraint(equalToConstant: 72),
            playButton.bottomAnchor.constraint(equalTo: playerCard.bottomAnchor, constant: -24),

            forwardBtn.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            forwardBtn.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 28),
            forwardBtn.widthAnchor.constraint(equalToConstant: 44),
            forwardBtn.heightAnchor.constraint(equalToConstant: 44),

            speedButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            speedButton.trailingAnchor.constraint(equalTo: playerCard.trailingAnchor, constant: -20)
        ])

        contentStack.addArrangedSubview(playerCard)
    }

    // MARK: - 信息卡片
    private func setupInfoCard() {
        infoCard.backgroundColor = cardColor
        infoCard.layer.cornerRadius = 16
        infoCard.translatesAutoresizingMaskIntoConstraints = false

        let rows: [(String, String, String)] = [
            ("calendar", "录音时间", metadata.formattedStartTime),
            ("clock", "录音时长", metadata.formattedDuration),
            ("waveform", "录音质量", metadata.quality.displayName),
            ("location", "录音地点", metadata.location?.displayString ?? "未记录"),
            ("bolt", "触发方式", metadata.triggerMethod.displayName),
            ("doc", "文件大小", metadata.formattedFileSize)
        ]

        var lastView: UIView? = nil

        for (icon, key, value) in rows {
            let row = createInfoRow(icon: icon, key: key, value: value)
            row.translatesAutoresizingMaskIntoConstraints = false
            infoCard.addSubview(row)

            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor)
            ])

            if let last = lastView {
                row.topAnchor.constraint(equalTo: last.bottomAnchor).isActive = true

                // 分隔线（除最后一行）
                if icon != "doc" {
                    let sep = UIView()
                    sep.backgroundColor = UIColor.white.withAlphaComponent(0.06)
                    sep.translatesAutoresizingMaskIntoConstraints = false
                    infoCard.addSubview(sep)
                    NSLayoutConstraint.activate([
                        sep.heightAnchor.constraint(equalToConstant: 0.5),
                        sep.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 52),
                        sep.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor),
                        sep.topAnchor.constraint(equalTo: last.bottomAnchor)
                    ])
                }
            } else {
                row.topAnchor.constraint(equalTo: infoCard.topAnchor).isActive = true
            }
            lastView = row
        }

        if let last = lastView {
            last.bottomAnchor.constraint(equalTo: infoCard.bottomAnchor).isActive = true
        }

        contentStack.addArrangedSubview(infoCard)
    }

    private func createInfoRow(icon: String, key: String, value: String) -> UIView {
        let container = UIView()

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = accentRed
        iconView.contentMode = .scaleAspectFit

        let keyLabel = UILabel()
        keyLabel.text = key
        keyLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        keyLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.textColor = .white
        valueLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 2
        valueLabel.adjustsFontSizeToFitWidth = true

        [iconView, keyLabel, valueLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),

            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            keyLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            keyLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: keyLabel.trailingAnchor, constant: 8),
            valueLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 200)
        ])

        return container
    }

    // MARK: - 地图卡片
    private func setupMapCard() {
        guard let location = metadata.location else { return }

        let mapCard = UIView()
        mapCard.backgroundColor = cardColor
        mapCard.layer.cornerRadius = 16
        mapCard.clipsToBounds = true

        mapView.layer.cornerRadius = 16
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapCard.addSubview(mapView)

        let coord = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        let region = MKCoordinateRegion(center: coord, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.setRegion(region, animated: false)

        let pin = MKPointAnnotation()
        pin.coordinate = coord
        pin.title = location.address
        mapView.addAnnotation(pin)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: mapCard.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: mapCard.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: mapCard.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: mapCard.bottomAnchor),
            mapCard.heightAnchor.constraint(equalToConstant: 180)
        ])

        contentStack.addArrangedSubview(mapCard)
    }

    // MARK: - 操作卡片
    private func setupActionsCard() {
        let exportBtn = createActionButton(
            title: "导出录音",
            icon: "square.and.arrow.up",
            color: UIColor(hex: "#0A84FF")
        )
        exportBtn.addTarget(self, action: #selector(exportRecording), for: .touchUpInside)

        let shareBtn = createActionButton(
            title: "分享",
            icon: "square.and.arrow.up.on.square",
            color: UIColor(hex: "#30D158")
        )
        shareBtn.addTarget(self, action: #selector(shareRecording), for: .touchUpInside)

        let deleteBtn = createActionButton(
            title: "删除录音",
            icon: "trash",
            color: UIColor(hex: "#FF3B30")
        )
        deleteBtn.addTarget(self, action: #selector(deleteRecording), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [exportBtn, shareBtn, deleteBtn])
        stack.axis = .vertical
        stack.spacing = 1
        stack.backgroundColor = cardColor
        stack.layer.cornerRadius = 16
        stack.clipsToBounds = true

        contentStack.addArrangedSubview(stack)
    }

    private func createActionButton(title: String, icon: String, color: UIColor) -> UIButton {
        let btn = UIButton(type: .system)
        btn.backgroundColor = cardColor
        btn.contentHorizontalAlignment = .left
        btn.contentEdgeInsets = UIEdgeInsets(top: 14, left: 20, bottom: 14, right: 20)

        var config = UIButton.Configuration.plain()
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePadding = 12
        config.baseForegroundColor = color
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        btn.configuration = config

        btn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return btn
    }

    // MARK: - 播放器准备
    private func preparePlayer() {
        let url = RecordingStore.shared.recordingFileURL(for: metadata.filename)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.delegate = self
        } catch {
            print("[Detail] 播放器初始化失败: \(error)")
        }
    }

    // MARK: - 播放控制
    @objc private func togglePlayback() {
        guard let player = audioPlayer else { return }
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)

        if isPlaying {
            player.pause()
            isPlaying = false
            playButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
            playTimer?.invalidate()
        } else {
            player.rate = playbackSpeed
            player.play()
            isPlaying = true
            playButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: config), for: .normal)
            startProgressTimer()
        }
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        playTimer?.invalidate()
        isPlaying = false
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.mixWithOthers])
    }

    private func startProgressTimer() {
        playTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }

    private func updateProgress() {
        guard let player = audioPlayer else { return }
        let progress = Float(player.currentTime / player.duration)
        waveformBar.setProgress(progress, animated: true)

        let cur = Int(player.currentTime)
        currentTimeLabel.text = String(format: "%02d:%02d", cur / 60, cur % 60)
    }

    @objc private func rewind() {
        audioPlayer?.currentTime = max(0, (audioPlayer?.currentTime ?? 0) - 15)
        updateProgress()
    }

    @objc private func forward() {
        guard let player = audioPlayer else { return }
        audioPlayer?.currentTime = min(player.duration, player.currentTime + 15)
        updateProgress()
    }

    @objc private func toggleSpeed() {
        let speeds: [Float] = [1.0, 1.25, 1.5, 2.0, 0.75]
        let currentIndex = speeds.firstIndex(of: playbackSpeed) ?? 0
        playbackSpeed = speeds[(currentIndex + 1) % speeds.count]
        audioPlayer?.rate = playbackSpeed
        speedButton.setTitle("\(playbackSpeed)×", for: .normal)
    }

    // MARK: - 操作方法
    @objc private func editTitle() {
        let alert = UIAlertController(title: "修改标题", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = self.metadata.title
            tf.placeholder = "输入标题..."
            tf.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            guard let self = self, let title = alert.textFields?.first?.text, !title.isEmpty else { return }
            self.metadata.title = title
            RecordingStore.shared.update(metadata: self.metadata)
            self.title = title
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func exportRecording() {
        RecordingStore.shared.exportToFiles(metadata: metadata) { [weak self] success, url in
            DispatchQueue.main.async {
                if success {
                    let alert = UIAlertController(title: "导出成功", message: "文件已复制到「文件」App", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "好的", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }

    @objc private func shareRecording() {
        let url = RecordingStore.shared.recordingFileURL(for: metadata.filename)
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(activityVC, animated: true)
    }

    @objc private func deleteRecording() {
        let alert = UIAlertController(title: "删除录音", message: "此操作不可撤销", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            RecordingStore.shared.delete(metadata: self.metadata)
            self.navigationController?.popViewController(animated: true)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - AVAudioPlayerDelegate
extension RecordingDetailViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)
        playButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
        playTimer?.invalidate()
        waveformBar.setProgress(0, animated: true)
    }
}
