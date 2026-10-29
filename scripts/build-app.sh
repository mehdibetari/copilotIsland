#!/bin/bash
# Builds build/CopilotIsland.app (menu-bar agent, no Dock icon).
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP=build/CopilotIsland.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/CopilotIsland" "$APP/Contents/MacOS/"
ICONSET="$(mktemp -d)/AppIcon.iconset"
swift scripts/make-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>dev.local.CopilotIsland</string>
  <key>CFBundleName</key><string>Copilot Island</string>
  <key>CFBundleExecutable</key><string>CopilotIsland</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Copilot Island doit contrôler iTerm2 pour revenir à l'onglet de votre session Copilot.</string>
</dict></plist>
EOF
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"
if [ "${1:-}" = "--install" ]; then
  pkill -x CopilotIsland || true
  rm -rf /Applications/CopilotIsland.app
  cp -R "$APP" /Applications/
  touch /Applications/CopilotIsland.app
  echo "Installed /Applications/CopilotIsland.app"
fi
