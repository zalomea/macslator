#!/bin/zsh
set -e

# Build script for macslator.app
# Usage: ./scripts/build_app.sh

APP_NAME="macslator"
BUNDLE_ID="com.zalomea.macslator"
VERSION="1.0.0"
BUILD_NUMBER="1"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/.build/release"
APP_PATH="${ROOT_DIR}/${APP_NAME}.app"
ICONSET_DIR="${ROOT_DIR}/Resources/Assets.xcassets/AppIcon.appiconset"
VENV_DIR="${ROOT_DIR}/.venv"

echo "Generating app icon..."
swift "${ROOT_DIR}/scripts/generate_icon.swift" "${ICONSET_DIR}"

echo "Building ${APP_NAME}..."
swift build -c release

echo "Preparing MLX Metal shaders..."
if [ ! -d "${VENV_DIR}" ]; then
    echo "Creating Python virtual environment for MLX shaders..."
    python3 -m venv "${VENV_DIR}"
fi

if ! "${VENV_DIR}/bin/python3" -c "import mlx" 2>/dev/null; then
    echo "Installing mlx Python package..."
    "${VENV_DIR}/bin/pip" install mlx
fi

METALLIB_PATH=$("${VENV_DIR}/bin/python3" - <<'PY'
import pathlib
import sysconfig
paths = [sysconfig.get_paths().get("purelib"), sysconfig.get_paths().get("platlib")]
for base in paths:
    if not base:
        continue
    candidate = pathlib.Path(base) / "mlx" / "lib" / "mlx.metallib"
    if candidate.exists():
        print(candidate)
        break
PY
)

if [ ! -f "${METALLIB_PATH}" ]; then
    echo "ERROR: Could not find mlx.metallib" >&2
    exit 1
fi

echo "Creating app bundle..."
rm -rf "${APP_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS"
mkdir -p "${APP_PATH}/Contents/Resources"

# Copy executable.
cp "${BUILD_DIR}/${APP_NAME}" "${APP_PATH}/Contents/MacOS/${APP_NAME}"

# Copy resources (excluding raw Assets.xcassets; we compile the icon below).
cp -R "${ROOT_DIR}/Resources/"* "${APP_PATH}/Contents/Resources/"
rm -rf "${APP_PATH}/Contents/Resources/Assets.xcassets"

# Compile iconset to icns.
if command -v iconutil &> /dev/null; then
    TMP_ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "${TMP_ICONSET}"
    cp "${ICONSET_DIR}"/*.png "${TMP_ICONSET}/"
    iconutil --convert icns --output "${APP_PATH}/Contents/Resources/AppIcon.icns" "${TMP_ICONSET}"
    echo "Compiled AppIcon.icns"
fi

# Copy MLX Metal library into the SwiftPM resource bundle expected at runtime.
MLX_BUNDLE_DIR="${APP_PATH}/Contents/Resources/mlx-swift_Cmlx.bundle"
mkdir -p "${MLX_BUNDLE_DIR}"
cp "${METALLIB_PATH}" "${MLX_BUNDLE_DIR}/default.metallib"
cp "${METALLIB_PATH}" "${MLX_BUNDLE_DIR}/mlx.metallib"
echo "Copied MLX metallib"

# Write Info.plist.
cat > "${APP_PATH}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 zalomea. All rights reserved.</string>
</dict>
</plist>
EOF

# Ad-hoc sign the bundle.
codesign --force --deep --sign - "${APP_PATH}"

echo "Built ${APP_PATH}"

echo "Creating disk image..."
DMG_PATH="${ROOT_DIR}/${APP_NAME}-${VERSION}.dmg"
STAGING_DIR="$(mktemp -d)/${APP_NAME}"
mkdir -p "${STAGING_DIR}"
cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# Remove any stale DMG before rebuilding.
rm -f "${DMG_PATH}"

hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_PATH}"

echo "Built ${DMG_PATH}"
echo "To install: open ${DMG_PATH}"
