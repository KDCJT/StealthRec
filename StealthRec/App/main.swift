// main.swift
// 诊断版入口文件 - 在任何其它 Swift 代码运行之前优先执行

import UIKit
import Foundation

// 在沙盒Documents目录下创建BOOT_DEBUG.log
let docsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "/tmp"
let logPath = docsPath + "/BOOT_DEBUG.log"

func logToBoot(_ msg: String) {
    let line = "[\(Date())] \(msg)\n"
    if let fd = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
        fd.seekToEndOfFile()
        if let data = line.data(using: .utf8) {
            fd.write(data)
        }
        fd.closeFile()
    } else {
        try? line.write(toFile: logPath, atomically: true, encoding: .utf8)
    }
}

// 第一条日志
logToBoot("--- APP BOOTSTRAPPING (main.swift) ---")

do {
    logToBoot("STEP 1: Registering AppDelegate...")
    
    // 启动 UIApplication，调用 AppDelegate
    UIApplicationMain(
        CommandLine.argc,
        CommandLine.unsafeArgv,
        nil,
        NSStringFromClass(AppDelegate.self)
    )
} catch {
    logToBoot("FATAL ERROR IN main.swift: \(error)")
}
