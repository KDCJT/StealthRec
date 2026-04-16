// CrashLogger.swift
// StealthRec — 全局运行日志记录与崩溃捕获
// 注意：使用 signal handler 捕获 Swift 崩溃，用 FileHandle 写文件（不用 freopen）

import Foundation
import UIKit

public class CrashLogger {
    public static let shared = CrashLogger()
    
    // 使用两个路径：沙盒 Documents（可通过文件App读）和 Shared Container（安全备用）
    public static var logFilePath: String = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("GhostRec_Debug.log").path
    }()
    
    private init() {}
    
    // MARK: - 核心日志写入（静态函数，可在 signal handler 中安全使用）
    // signal handler 内只能调用 async-signal-safe 函数，使用 write() 系统调用
    static func writeRaw(_ message: String) {
        let fd = open(logFilePath, O_WRONLY | O_CREAT | O_APPEND, 0o644)
        guard fd >= 0 else { return }
        let data = message.utf8.map { UInt8($0) }
        data.withUnsafeBufferPointer { ptr in
            _ = write(fd, ptr.baseAddress, ptr.count)
        }
        close(fd)
    }
    
    // MARK: - 普通日志（可在任意线程调用）
    public static func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let ts = formatter.string(from: Date())
        let line = "[\(ts)] \(message)\n"
        writeRaw(line)
    }
    
    // MARK: - 启动日志系统
    public func startLogging() {
        // 写入启动标记
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let ts = formatter.string(from: Date())
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        
        CrashLogger.writeRaw("\n========================================\n")
        CrashLogger.writeRaw("[App Launched] \(ts)\n")
        CrashLogger.writeRaw("[Version] \(version) (Build \(build))\n")
        CrashLogger.writeRaw("[LogPath] \(CrashLogger.logFilePath)\n")
        CrashLogger.writeRaw("========================================\n")
        
        // 捕获 ObjC 异常
        NSSetUncaughtExceptionHandler { exception in
            CrashLogger.writeRaw("\n!!! ObjC EXCEPTION !!!\n")
            CrashLogger.writeRaw("Name: \(exception.name.rawValue)\n")
            CrashLogger.writeRaw("Reason: \(exception.reason ?? "nil")\n")
            exception.callStackSymbols.forEach { CrashLogger.writeRaw("  \($0)\n") }
            CrashLogger.writeRaw("!!! END EXCEPTION !!!\n")
        }
        
        // 捕获 UNIX 信号（包括 Swift fatalError → SIGABRT、SIGSEGV 等）
        let signals = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGTRAP, SIGTERM]
        for sig in signals {
            signal(sig) { sigNum in
                // 只使用 async-signal-safe 操作
                let fd = open(CrashLogger.logFilePath, O_WRONLY | O_CREAT | O_APPEND, 0o644)
                if fd >= 0 {
                    let msg = "\n!!! SIGNAL CRASH: \(sigNum) !!!\n"
                    let bytes = Array(msg.utf8)
                    bytes.withUnsafeBufferPointer { ptr in
                        _ = write(fd, ptr.baseAddress, ptr.count)
                    }
                    close(fd)
                }
                // 恢复默认行为让系统产生崩溃报告
                signal(sigNum, SIG_DFL)
                raise(sigNum)
            }
        }
        
        CrashLogger.log("[CrashLogger] Signal handlers installed. Logging active.")
    }
}
