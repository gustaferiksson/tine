#!/bin/bash
# Build + install the tine input method (TineInputMethod.app) to
# ~/Library/Input Methods/. After running, enable it in
# System Settings → Keyboard → Input Sources → + → search "tine".
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMEDIR="$ROOT/inputmethod"
BUNDLE="$HOME/Library/Input Methods/TineInputMethod.app"
SIGN_ID="${TINE_SIGN_ID:-Developer ID Application: Gustaf Eriksson (82K3YC8HVF)}"

echo "› building input method"
(cd "$IMEDIR" && swift build -c release)
BIN="$IMEDIR/.build/release/TineIME"

echo "› bundling → $BUNDLE"
pkill -x TineIME 2>/dev/null || true
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$BIN" "$BUNDLE/Contents/MacOS/TineIME"

cat > "$BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Tine</string>
  <key>CFBundleDisplayName</key><string>Tine</string>
  <key>CFBundleExecutable</key><string>TineIME</string>
  <key>CFBundleIdentifier</key><string>dev.gustaf.tine.inputmethod</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.0.1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSBackgroundOnly</key><true/>
  <key>InputMethodConnectionName</key><string>TineIME_1_Connection</string>
  <key>InputMethodServerControllerClass</key><string>TineInputController</string>
  <key>tsInputMethodCharacterRepertoire</key>
  <array><string>Latn</string></array>
  <key>ComponentInputModeDict</key>
  <dict>
    <key>tsVisibleInputModeOrderedArray</key>
    <array><string>dev.gustaf.tine.inputmethod.mode</string></array>
    <key>tsInputModeListKey</key>
    <dict>
      <key>dev.gustaf.tine.inputmethod.mode</key>
      <dict>
        <key>TISInputSourceID</key><string>dev.gustaf.tine.inputmethod.mode</string>
        <key>TISIntendedLanguage</key><string>en</string>
        <key>tsInputModeIsVisibleKey</key><true/>
        <key>tsInputModePrimaryInScriptKey</key><true/>
        <key>tsInputModeScriptKey</key><string>smRoman</string>
        <key>tsInputModeKeyEquivalentModifiersKey</key><integer>0</integer>
        <key>tsInputModeKeyEquivalentKey</key><string></string>
      </dict>
    </dict>
  </dict>
</dict>
</plist>
PLIST

# Developer ID (not ad-hoc): macOS is more reliable about indexing a stably-signed
# input method into the input-source list. Set TINE_SIGN_ID=- to force ad-hoc.
echo "› signing ($SIGN_ID)"
codesign --force --deep --sign "$SIGN_ID" "$BUNDLE"

echo ""
echo "Installed. Now:"
echo "  1) System Settings → Keyboard → Input Sources → +  → search 'tine' → Add"
echo "  2) Switch to it (or keep it active) so it can report the caret in Ghostty"
echo "  (You may need to log out/in once for it to appear.)"
