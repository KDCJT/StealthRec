// CrashLogger.swift
// StealthRec — 全局运行日志记录与奔溃捕获

import Foundation
import UIKit

public class CrashLogger {
    public static let shared = CrashLogger()
    
    private var logFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("StealthRec_Debug.log")
    }
    
    private init() {}
    
    public func startLogging() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        
        let header = "\n\n========================================\n[App Launched] \(timestamp)\n========================================\n"
        
        // 尝试写入文件头
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            try? header.write(to: logFileURL, atomically: true, encoding: .utf8)
        } else {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                handle.seekToEndOfFile()
                if let data = header.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            }
        }
        
        // 捕获严重级错误 (Objective-C Exceptions)
        NSSetUncaughtExceptionHandler { exception in
            let crashLog = """
            
            ！！！FATAL CRASH！！！
            Time: \(Date())
            Name: \(exception.name)
            Reason: \(exception.reason ?? "Unknown")
            Call Stack:
            \(exception.callStackSymbols.joined(separator: "\n"))
            ！！！=============！！！
            
            """
            
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = docs.appendingPathComponent("StealthRec_Debug.log")
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                if let data = crashLog.data(using: .utf8) { handle.write(data) }
                handle.closeFile()
            }
        }
        
        // Swift 断言保护和日志重定向
        if let path = logFileURL.path.cString(using: .utf8) {
            // "a+" 代表附加且允许读写
            freopen(path, "a+", stderr)
            freopen(path, "a+", stdout)
        }
        
        print("[CrashLogger] Init success - Writing to \(logFileURL.path)")
    }
}
