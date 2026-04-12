// RecordingCell.swift
// StealthRec — 录音列表 Cell

import UIKit

class RecordingCell: UITableViewCell {

    static let reuseID = "RecordingCell"

    // MARK: - UI 组件
    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let durationLabel = UILabel()
    private let dateLabel = UILabel()
    private let locationLabel = UILabel()
    private let qualityBadge = UILabel()
    private let triggerBadge = UILabel()

    // MARK: - 初始化
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = UIColor(hex: "#1A1A1E")
        selectionStyle = .none
        accessoryType = .disclosureIndicator

        // 选中效果
        let selectedBG = UIView()
        selectedBG.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        selectedBackgroundView = selectedBG

        // 图标容器
        iconContainer.backgroundColor = UIColor(hex: "#FF3B30").withAlphaComponent(0.15)
        iconContainer.layer.cornerRadius = 22
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        iconView.image = UIImage(systemName: "waveform")
        iconView.tintColor = UIColor(hex: "#FF3B30")
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)

        durationLabel.textColor = UIColor(hex: "#FF3B30")
        durationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)

        dateLabel.textColor = UIColor.white.withAlphaComponent(0.4)
        dateLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)

        locationLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        locationLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)

        qualityBadge.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
        qualityBadge.layer.cornerRadius = 4
        qualityBadge.clipsToBounds = true
        qualityBadge.textAlignment = .center

        triggerBadge.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        triggerBadge.textColor = UIColor.white.withAlphaComponent(0.35)

        [iconContainer, iconView, titleLabel, durationLabel, dateLabel, locationLabel, qualityBadge, triggerBadge]
            .forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview($0)
            }
        iconContainer.addSubview(iconView)

        NSLayoutConstraint.activate([
            // 图标
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            // 标题
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -8),

            // 时长
            durationLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            // 位置
            locationLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            locationLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            locationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            // 日期 + 徽章
            dateLabel.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: 3),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            triggerBadge.centerYAnchor.constraint(equalTo: dateLabel.centerYAnchor),
            triggerBadge.leadingAnchor.constraint(equalTo: dateLabel.trailingAnchor, constant: 8),

            qualityBadge.centerYAnchor.constraint(equalTo: dateLabel.centerYAnchor),
            qualityBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            qualityBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 30),
            qualityBadge.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    // MARK: - 配置
    func configure(with metadata: RecordingMetadata) {
        titleLabel.text = metadata.title.isEmpty ? metadata.filename : metadata.title

        durationLabel.text = metadata.formattedDuration

        // 位置
        if let loc = metadata.location {
            let icon = "📍"
            locationLabel.text = "\(icon) \(loc.address.isEmpty ? "位置未知" : loc.displayString)"
        } else {
            locationLabel.text = "📍 位置未记录"
        }

        // 日期
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        dateLabel.text = formatter.string(from: metadata.startTime)

        // 触发方式
        triggerBadge.text = "· \(metadata.triggerMethod.displayName)"

        // 质量徽章
        setupQualityBadge(for: metadata.quality)
    }

    private func setupQualityBadge(for quality: RecordingQuality) {
        switch quality {
        case .low:
            qualityBadge.text = " 低 "
            qualityBadge.textColor = UIColor(hex: "#FFD60A")
            qualityBadge.backgroundColor = UIColor(hex: "#FFD60A").withAlphaComponent(0.15)
        case .standard:
            qualityBadge.text = " 标准 "
            qualityBadge.textColor = UIColor(hex: "#30D158")
            qualityBadge.backgroundColor = UIColor(hex: "#30D158").withAlphaComponent(0.15)
        case .high:
            qualityBadge.text = " 高 "
            qualityBadge.textColor = UIColor(hex: "#0A84FF")
            qualityBadge.backgroundColor = UIColor(hex: "#0A84FF").withAlphaComponent(0.15)
        case .lossless:
            qualityBadge.text = " 无损 "
            qualityBadge.textColor = UIColor(hex: "#BF5AF2")
            qualityBadge.backgroundColor = UIColor(hex: "#BF5AF2").withAlphaComponent(0.15)
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.12) {
            self.contentView.alpha = highlighted ? 0.7 : 1.0
        }
    }
}
