#!/bin/bash
# =========================================
#  UZTEXPRO Payment - Build DMG Script
# =========================================

set -e

APP_NAME="UZTEXPRO"
VERSION="1.0.0"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_PATH="$BUILD_DIR/macos/Build/Products/Release/uztexpro_payment.app"
DMG_STAGING="$BUILD_DIR/dmg_staging"
DMG_OUTPUT="$BUILD_DIR/${APP_NAME}-${VERSION}.dmg"

echo "🚀 Сборка macOS приложения..."
flutter build macos --release

echo "📦 Подготовка DMG..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

# Copy app bundle
cp -R "$APP_PATH" "$DMG_STAGING/${APP_NAME}.app"

# Symlink to Applications folder
ln -sf /Applications "$DMG_STAGING/Applications"

# Remove old DMG if exists
rm -f "$DMG_OUTPUT"

echo "💿 Создание DMG..."
hdiutil create \
  -volname "UZTEXPRO Payment" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  -o "$DMG_OUTPUT"

# Cleanup staging
rm -rf "$DMG_STAGING"

echo ""
echo "✅ Готово! DMG файл:"
echo "   $DMG_OUTPUT"
echo "   Размер: $(du -sh "$DMG_OUTPUT" | cut -f1)"
