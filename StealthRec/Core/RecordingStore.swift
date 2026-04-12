// RecordingStore.swift
// StealthRec — 录音文件 + 元数据持久化管理

import Foundation

final class RecordingStore {

    static let shared = RecordingStore()

    // MARK: - 路径配置
    private let fileManager = FileManager.default

    var recordingsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var metadataDirectory: URL {
        let dir = recordingsDirectory.appendingPathComponent("Metadata", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - 文件路径
    func recordingFileURL(for filename: String) -> URL {
        return recordingsDirectory.appendingPathComponent(filename)
    }

    private func metadataFileURL(for id: String) -> URL {
        return metadataDirectory.appendingPathComponent("\(id).json")
    }

    // MARK: - 保存元数据
    func save(metadata: RecordingMetadata) {
        do {
            let data = try encoder.encode(metadata)
            let url = metadataFileURL(for: metadata.id)
            try data.write(to: url, options: .atomicWrite)
        } catch {
            print("[RecordingStore] 保存元数据失败: \(error)")
        }
    }

    // MARK: - 加载所有录音（按时间降序）
    func loadAll() -> [RecordingMetadata] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: metadataDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }

        var recordings: [RecordingMetadata] = []

        for fileURL in files where fileURL.pathExtension == "json" {
            if let data = try? Data(contentsOf: fileURL),
               let metadata = try? decoder.decode(RecordingMetadata.self, from: data) {
                // 确认音频文件存在
                let audioURL = recordingFileURL(for: metadata.filename)
                if fileManager.fileExists(atPath: audioURL.path) {
                    recordings.append(metadata)
                } else {
                    // 孤立的元数据，清理掉
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        }

        return recordings.sorted { $0.startTime > $1.startTime }
    }

    // MARK: - 删除录音
    func delete(metadata: RecordingMetadata) {
        let audioURL = recordingFileURL(for: metadata.filename)
        let metaURL = metadataFileURL(for: metadata.id)
        try? fileManager.removeItem(at: audioURL)
        try? fileManager.removeItem(at: metaURL)
    }

    func delete(ids: [String]) {
        let all = loadAll()
        for metadata in all where ids.contains(metadata.id) {
            delete(metadata: metadata)
        }
    }

    // MARK: - 更新元数据
    func update(metadata: RecordingMetadata) {
        save(metadata: metadata)
    }

    // MARK: - 导出到 Files App（复制到 Documents 根目录）
    func exportToFiles(metadata: RecordingMetadata, completion: @escaping (Bool, URL?) -> Void) {
        let sourceURL = recordingFileURL(for: metadata.filename)
        let docsRoot = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destURL = docsRoot.appendingPathComponent(metadata.filename)

        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destURL)
            completion(true, destURL)
        } catch {
            print("[RecordingStore] 导出失败: \(error)")
            completion(false, nil)
        }
    }

    // MARK: - 统计信息
    func totalStorageUsed() -> Int64 {
        var total: Int64 = 0
        let all = loadAll()
        for metadata in all {
            total += metadata.fileSize
        }
        return total
    }

    // MARK: - 搜索
    func search(query: String) -> [RecordingMetadata] {
        let all = loadAll()
        if query.isEmpty { return all }

        return all.filter { metadata in
            metadata.title.localizedCaseInsensitiveContains(query) ||
            metadata.location?.address.localizedCaseInsensitiveContains(query) == true ||
            metadata.notes.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - 分组（按日期）
    func groupedByDate() -> [(String, [RecordingMetadata])] {
        let all = loadAll()
        var groups: [String: [RecordingMetadata]] = [:]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"

        for metadata in all {
            let key = formatter.string(from: metadata.startTime)
            groups[key, default: []].append(metadata)
        }

        return groups.sorted { a, b in
            let df = DateFormatter()
            df.locale = Locale(identifier: "zh_CN")
            df.dateFormat = "yyyy年M月d日"
            let dateA = df.date(from: a.key) ?? Date.distantPast
            let dateB = df.date(from: b.key) ?? Date.distantPast
            return dateA > dateB
        }
    }
}
