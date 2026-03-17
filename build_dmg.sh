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

echo "✍️  Подписание приложения (ad-hoc)..."
# Strip existing signature and re-sign without sandbox entitlement
codesign --remove-signature "$APP_PATH" 2>/dev/null || true
find "$APP_PATH" -name "*.dylib" -o -name "*.so" -o -name "*.framework" | while read f; do
  codesign --force --sign - "$f" 2>/dev/null || true
done
codesign --deep --force --sign - "$APP_PATH"

echo "🔓 Снятие карантина с приложения..."
xattr -cr "$APP_PATH" 2>/dev/null || true

echo "📦 Подготовка DMG..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

# Copy app bundle
cp -R "$APP_PATH" "$DMG_STAGING/${APP_NAME}.app"

# Symlink to Applications folder
ln -sf /Applications "$DMG_STAGING/Applications"

# Create instruction file
cat > "$DMG_STAGING/КАК ОТКРЫТЬ.txt" << 'EOF'
Как открыть UZTEXPRO на macOS
==============================

При первом запуске macOS может заблокировать приложение.

Способ 1 (простой):
  1. Перетащите UZTEXPRO в папку Applications
  2. Щёлкните ПРАВОЙ кнопкой на UZTEXPRO.app
  3. Выберите "Открыть" (Open)
  4. В появившемся окне нажмите "Открыть"

Способ 2 (через Терминал):
  Скопируйте приложение в папку Программы, затем выполните:
  sudo xattr -cr /Applications/UZTEXPRO.app

После первого запуска приложение будет открываться как обычно.
EOF

# Remove old DMG if exists
rm -f "$DMG_OUTPUT"

echo "💿 Создание DMG..."
hdiutil create \
  -volname "UZTEXPRO Payment" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  -o "$DMG_OUTPUT"

# Remove quarantine from the DMG itself
xattr -d com.apple.quarantine "$DMG_OUTPUT" 2>/dev/null || true

# Cleanup staging
rm -rf "$DMG_STAGING"

echo ""
echo "✅ Готово! DMG файл:"
echo "   $DMG_OUTPUT"
echo "   Размер: $(du -sh "$DMG_OUTPUT" | cut -f1)"
