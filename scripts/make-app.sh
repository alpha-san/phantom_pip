#!/bin/bash
# Package PhantomPiP into a real .app bundle so it can register the
# phantompip:// URL scheme (a bare `swift run` binary cannot), gets a Finder
# icon, and launches on demand from the Chrome extension.
#
#   ./scripts/make-app.sh        # build + bundle + register
#
# Output: ./PhantomPiP.app  (gitignored). Move it to /Applications if you like.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

APP="${ROOT}/PhantomPiP.app"
BIN_NAME="PhantomPiP"
BUNDLE_ID="com.phantom-pip.app"

echo "[1/6] Building release binary"
swift build -c release
BIN="${ROOT}/.build/release/${BIN_NAME}"
[ -x "${BIN}" ] || { echo "  ERROR: release binary not found at ${BIN}"; exit 1; }

echo "[2/6] Assembling bundle: ${APP}"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN}" "${APP}/Contents/MacOS/${BIN_NAME}"

echo "[3/6] Generating app icon (.icns)"
WORK="$(mktemp -d)"
ICONSET="${WORK}/AppIcon.iconset"
SRC_PNG="${WORK}/icon-1024.png"
mkdir -p "${ICONSET}"
"${BIN}" --export-icon "${SRC_PNG}" >/dev/null
for size in 16 32 64 128 256 512; do
  sips -z "${size}" "${size}" "${SRC_PNG}" \
    --out "${ICONSET}/icon_${size}x${size}.png" >/dev/null
  d=$((size * 2))
  sips -z "${d}" "${d}" "${SRC_PNG}" \
    --out "${ICONSET}/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "${ICONSET}" -o "${APP}/Contents/Resources/AppIcon.icns"

echo "[4/6] Generating Chrome extension icons"
mkdir -p "${ROOT}/extension/icons"
for size in 16 32 48 128; do
  sips -z "${size}" "${size}" "${SRC_PNG}" \
    --out "${ROOT}/extension/icons/icon${size}.png" >/dev/null
done

echo "[5/6] Writing Info.plist"
cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>              <string>PhantomPiP</string>
  <key>CFBundleDisplayName</key>       <string>PhantomPiP</string>
  <key>CFBundleIdentifier</key>        <string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key>           <string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleExecutable</key>        <string>${BIN_NAME}</string>
  <key>CFBundlePackageType</key>       <string>APPL</string>
  <key>CFBundleIconFile</key>          <string>AppIcon</string>
  <key>NSPrincipalClass</key>          <string>NSApplication</string>
  <key>LSMinimumSystemVersion</key>    <string>13.0</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>    <string>PhantomPiP Deep Link</string>
      <key>CFBundleURLSchemes</key> <array><string>phantompip</string></array>
    </dict>
  </array>
</dict>
</plist>
PLIST
plutil -lint "${APP}/Contents/Info.plist" >/dev/null && echo "  Info.plist OK"

echo "[6/6] Registering with Launch Services"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
if [ -x "${LSREGISTER}" ]; then
  "${LSREGISTER}" -f "${APP}" && echo "  registered phantompip:// -> ${APP}"
else
  echo "  lsregister not found; launching the app once also registers it"
fi
rm -rf "${WORK}"

echo ""
echo "Done. Built ${APP}"
echo "  Launch:  open \"${APP}\"   (or move it to /Applications)"
echo "  Test:    open 'phantompip://play?u=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DdQw4w9WgXcQ'"
