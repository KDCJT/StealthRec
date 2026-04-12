#!/bin/bash
# build_and_package.sh
# StealthRec — 构建、注入 Entitlements、打包 IPA
# 运行环境：macOS + Xcode 已安装
# 使用方法：chmod +x build_and_package.sh && ./build_and_package.sh

set -e

# ===== 配置 =====
PROJECT_NAME="StealthRec"
SCHEME="StealthRec"
BUNDLE_ID="com.stealthrec.app"
ENTITLEMENTS_FILE="StealthRec/App/StealthRec.entitlements"
BUILD_DIR="build"
IPA_NAME="StealthRec.ipa"

echo "╔══════════════════════════════════════╗"
echo "║       StealthRec 构建脚本            ║"
echo "║       TrollStore 侧载版本            ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ===== 步骤 1：编译 =====
echo "▶ [1/4] 编译项目..."
xcodebuild \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -derivedDataPath "${BUILD_DIR}" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=NO \
    clean build

echo "✓ 编译完成"

# ===== 步骤 2：定位 .app 文件 =====
echo "▶ [2/4] 定位 .app 包..."
APP_PATH=$(find "${BUILD_DIR}" -name "*.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "✗ 错误：找不到编译后的 .app 文件"
    exit 1
fi

echo "  ✓ 找到: ${APP_PATH}"

BINARY_PATH="${APP_PATH}/${PROJECT_NAME}"
echo "  ✓ 二进制: ${BINARY_PATH}"

# ===== 步骤 3：注入 Entitlements（使用 ldid）=====
echo "▶ [3/4] 注入 TrollStore 特权 Entitlements..."

# 检查 ldid 是否已安装
if ! command -v ldid &> /dev/null; then
    echo "  ! ldid 未安装，尝试通过 Homebrew 安装..."
    brew install ldid || {
        echo "  ✗ 请手动安装 ldid：brew install ldid 或 apt install ldid"
        exit 1
    }
fi

ldid -S"${ENTITLEMENTS_FILE}" "${BINARY_PATH}"
echo "  ✓ Entitlements 注入成功"

# ===== 步骤 4：打包为 IPA =====
echo "▶ [4/4] 打包为 IPA..."

PAYLOAD_DIR="${BUILD_DIR}/Payload"
mkdir -p "${PAYLOAD_DIR}"
cp -r "${APP_PATH}" "${PAYLOAD_DIR}/"

cd "${BUILD_DIR}"
zip -r "../${IPA_NAME}" "Payload" -x "*.DS_Store"
cd ..
rm -rf "${PAYLOAD_DIR}"

echo "  ✓ ${IPA_NAME} 打包完成"
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ 构建完成！                                               ║"
echo "║                                                              ║"
echo "║  安装步骤：                                                  ║"
echo "║  1. 将 StealthRec.ipa 传输到 iPhone（AirDrop / 文件 App）   ║"
echo "║  2. 在 iPhone 上用「巨魔商店」打开 IPA 文件                  ║"
echo "║  3. 点击「Install」安装                                      ║"
echo "║  4. 首次打开时授予麦克风和位置权限                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "生成的文件：$(pwd)/${IPA_NAME}"
