# StealthRec — iOS 隐蔽录音应用
**专为 iPhone 7 / iOS 15 设计，TrollStore 巨魔商店侧载**

---

## 📁 项目结构

```
StealthRec/
├── App/
│   ├── AppDelegate.swift           ← 生命周期 + 触发器初始化 + 后台维持
│   ├── SceneDelegate.swift         ← 场景管理 + 密码锁定逻辑
│   └── StealthRec.entitlements     ← ⭐ TrollStore 特权权限文件
├── Core/
│   ├── RecordingEngine.swift       ← AVAudioRecorder 核心录音引擎
│   ├── TriggerManager.swift        ← 所有触发方式的统一管理
│   ├── LocationManager.swift       ← GPS 定位 + 中文地理编码
│   ├── RecordingStore.swift        ← 文件管理 + 元数据 JSON 持久化
│   ├── SettingsManager.swift       ← 设置持久化
│   └── PasswordManager.swift       ← SHA-256 PIN + Face/Touch ID
├── Models/
│   └── RecordingMetadata.swift     ← 录音数据模型（含文件名生成规则）
├── UI/
│   ├── Auth/
│   │   └── AuthViewController.swift    ← 6位PIN解锁界面 + 生物识别
│   ├── Main/
│   │   ├── MainViewController.swift    ← 录音列表 + 实时录音横幅
│   │   └── RecordingCell.swift         ← 列表 Cell（含质量/触发/位置徽章）
│   ├── Detail/
│   │   └── RecordingDetailViewController.swift ← 播放器 + 地图 + 元数据
│   └── Settings/
│       └── SettingsViewController.swift ← 所有设置项 + 密码设置
└── Resources/
    └── Info.plist                  ← 后台模式 + 权限声明
```

---

## 🚀 快捷触发方式（全部可同时启用）

| # | 触发方式 | 技术实现 | 锁屏可用 | 推荐 |
|---|---------|---------|---------|------|
| 1 | **摇动手机** | CMMotionManager 加速度计（阈值2.5g）| ✅ | ✅ |
| 2 | **音量键快速连按2次** | AVAudioSession KVO + 音量静默恢复 | ✅ | ⭐ 最隐蔽 |
| 3 | **截图手势（Home+电源键同按）** | UIApplication.userDidTakeScreenshotNotification | ✅ | ✅ |
| 4 | **悬浮快捷按钮** | UIWindow(.alert+1) 全局覆盖层 | ❌ 需亮屏 | 可选 |
| 5 | **定时录音** | Timer 预约触发 | ✅ | 场景用 |

**所有触发均为切换式**：再次触发 = 停止录音

---

## 📂 录音文件格式

**文件名示例：**  
`录音_2024-12-25_14-30-00_上海市浦东新区.m4a`

**元数据 JSON 文件（同步生成）：**
```json
{
  "id": "UUID",
  "filename": "录音_2024-12-25_14-30-00.m4a",
  "startTime": "2024-12-25T14:30:00+08:00",
  "endTime": "2024-12-25T14:45:22+08:00",
  "duration": 922.4,
  "quality": "high",
  "location": {
    "latitude": 31.2304,
    "longitude": 121.4737,
    "address": "上海市浦东新区陆家嘴",
    "accuracy": 15.0
  },
  "triggerMethod": "volume_key",
  "fileSize": 14729216
}
```

---

## 🔒 安全特性

- PIN 密码（6位）使用 **SHA-256 + 盐值** 哈希存储
- 支持 **Touch ID**（iPhone 7 使用 Touch ID）
- 从后台切换回前台时**自动锁定**
- 录音文件仅存储在 App 内部沙盒（不可被其他 App 访问）
- 可通过 App 内导出或分享，输出到"文件"App

---

## 🔧 构建步骤（需要 macOS + Xcode）

### 方法一：脚本一键构建
```bash
# 1. 将 StealthRec 文件夹复制到 Mac
# 2. 在 Xcode 中创建项目并导入所有 .swift 文件
# 3. 运行构建脚本
chmod +x build_and_package.sh
./build_and_package.sh
```

### 方法二：手动构建
```bash
# 编译（不签名）
xcodebuild -scheme StealthRec -configuration Release \
    -destination "generic/platform=iOS" \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
    clean build

# 注入特权权限
ldid -SStealthRec/App/StealthRec.entitlements \
    build/Release-iphoneos/StealthRec.app/StealthRec

# 打包 IPA
mkdir -p Payload
cp -r build/Release-iphoneos/StealthRec.app Payload/
zip -r StealthRec.ipa Payload/
```

### 安装到手机
1. 将 `StealthRec.ipa` 传到 iPhone（AirDrop / VPN 或 USB 文件传输）
2. 在 iPhone 上用**巨魔商店（TrollStore）**打开 IPA
3. 点击 **Install** 安装
4. 首次打开，授予**麦克风**和**位置**权限

---

## ⚠️ 注意事项

| 事项 | 说明 |
|------|------|
| 橙色隐私圆点 | iOS 15 强制显示，无法屏蔽，属于正常现象 |
| 电源键双击 | 系统保留给 Apple Pay，无法拦截 |
| Force Quit | 强制结束 App 会停止录音（无法避免） |
| 锁屏状态 | 音量键和摇动触发在锁屏下均有效 |
| 巨魔版本 | iPhone 7 / iOS 15.x 推荐使用 TrollStore 2.x |

---

## 📋 Xcode 项目配置说明

在 Xcode 中创建项目时需设置：

1. **Project > Info > Deployment Target**：iOS 15.0
2. **Signing & Capabilities**：关闭自动签名（巨魔需要手动签名）
3. **Build Settings**：
   - `ENABLE_BITCODE` = NO
   - `CODE_SIGN_IDENTITY` = 空
4. **Capabilities 添加**：
   - Background Modes（Audio, Location, Fetch, Processing）
   - LocalAuthentication.framework
   - CoreMotion.framework
   - MapKit.framework
