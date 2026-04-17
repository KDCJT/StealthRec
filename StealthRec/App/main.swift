// main.swift
// 诊断版入口文件 - 在任何其它 Swift 代码运行之前优先执行

import UIKit
import Foundation

// 获取可写的路径，TrollStore App 有完全的 NSHomeDirectory 权限
let docsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()
let homePath = NSHomeDirectory()
let logPaths = [
    docsPath + "/BOOT_DEBUG.log",
    homePath + "/BOOT_DEBUG.log"
]

func logToBoot(_ msg: String) {
    let line = "[\(Date())] \(msg)\n"
    for path in logPaths {
        if let fd = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            fd.seekToEndOfFile()
            if let data = line.data(using: .utf8) {
                fd.write(data)
            }
            fd.closeFile()
        } else {
            try? line.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}

// 拦截所有标准错误输出到日志文件
freopen(logPaths[0].cString(using: .utf8), "a", stderr)
freopen(logPaths[0].cString(using: .utf8), "a", stdout)

// 第一条日志
logToBoot("=== GHOSTREC APP BOOTSTRAPPING (1.2.2) ===")

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
