#!/bin/bash

echo "🧹 清理构建缓存..."
flutter clean

echo "📦 获取依赖..."
flutter pub get

echo "🔨 构建 ARM64 APK..."
flutter build apk --target-platform android-arm64 --release

echo "✅ 构建完成！"
echo "📱 APK 位置: build/app/outputs/flutter-apk/app-release.apk"

# 显示 APK 信息
echo "📊 APK 信息:"
aapt dump badging build/app/outputs/flutter-apk/app-release.apk | grep "native-code"