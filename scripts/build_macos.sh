#!/bin/bash
set -euo pipefail

# ============================================================
# Keychat macOS Archive + Notarize Script
# Run from repo root:
#   ./scripts/build_macos.sh            (build only)
#   ./scripts/build_macos.sh --upload   (build + upload to Google Drive)
# ============================================================

UPLOAD=false
if [[ "${1:-}" == "--upload" ]]; then
  UPLOAD=true
fi

APP_DIR="packages/app"
WORKSPACE="${APP_DIR}/macos/Runner.xcworkspace"
SCHEME="Runner"
CONFIGURATION="Release"
ARCHIVE_DIR="${APP_DIR}/build/macos/archive"
EXPORT_DIR="${APP_DIR}/build/macos/export"
ARCHIVE_PATH="${ARCHIVE_DIR}/Keychat.xcarchive"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPORT_OPTIONS_PLIST="${SCRIPT_DIR}/ExportOptions.plist"
KEYCHAIN_PROFILE="keychat-notary"
RCLONE_REMOTE="gdrive"
RCLONE_FOLDER="keychat-dmg"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ----------------------------------------------------------
# Pre-flight checks
# ----------------------------------------------------------
log "Running pre-flight checks..."

command -v xcodebuild >/dev/null 2>&1  || error "xcodebuild not found. Install Xcode."
command -v flutter >/dev/null 2>&1     || error "flutter not found. Check your PATH."
command -v create-dmg >/dev/null 2>&1  || error "create-dmg not found. Run: npm install -g create-dmg"
command -v yq >/dev/null 2>&1          || error "yq not found. Run: brew install yq"
if [[ "$UPLOAD" == true ]]; then
  command -v rclone >/dev/null 2>&1    || error "rclone not found. Run: brew install rclone"
fi
[[ -f "$EXPORT_OPTIONS_PLIST" ]]       || error "Missing ${EXPORT_OPTIONS_PLIST}"

# ----------------------------------------------------------
# Step 1: Clean previous build
# ----------------------------------------------------------
log "Cleaning previous build artifacts..."
rm -rf "$ARCHIVE_DIR" "$EXPORT_DIR"
mkdir -p "$ARCHIVE_DIR" "$EXPORT_DIR"

# ----------------------------------------------------------
# Step 2: Flutter build
# ----------------------------------------------------------
log "Running flutter build macos --release ..."
cd "$APP_DIR"
flutter build macos --release
cd - > /dev/null

# ----------------------------------------------------------
# Step 3: Archive
# ----------------------------------------------------------
log "Archiving..."
xcodebuild archive \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -quiet

[[ -d "$ARCHIVE_PATH" ]] || error "Archive failed — .xcarchive not found."
log "Archive succeeded: ${ARCHIVE_PATH}"

# ----------------------------------------------------------
# Step 4: Export (signing only)
# ----------------------------------------------------------
log "Exporting signed app..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -allowProvisioningUpdates

APP_PATH="${EXPORT_DIR}/Keychat.app"
[[ -d "$APP_PATH" ]] || error "Export failed — .app not found in ${EXPORT_DIR}"
log "Export succeeded: ${APP_PATH}"

# ----------------------------------------------------------
# Step 5: Zip for notarization
# ----------------------------------------------------------
ZIP_PATH="${EXPORT_DIR}/Keychat.zip"
log "Creating zip for notarization..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

# ----------------------------------------------------------
# Step 6: Submit to Apple notary service
# ----------------------------------------------------------
# First-time setup (run once manually):
#   xcrun notarytool store-credentials "keychat-notary" \
#     --apple-id "your@email.com" \
#     --team-id "xxx" \
#     --password "<app-specific-password>"
# ----------------------------------------------------------
log "Submitting to Apple notary service (this may take a few minutes)..."
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait \
  || error "Notarization failed. Run: xcrun notarytool log <submission-id> --keychain-profile ${KEYCHAIN_PROFILE}"

# ----------------------------------------------------------
# Step 7: Staple notarization ticket
# ----------------------------------------------------------
log "Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"

# ----------------------------------------------------------
# Verify
# ----------------------------------------------------------
log "Verifying notarization..."
spctl --assess --type execute --verbose "$APP_PATH" 2>&1 | tee /dev/stderr | grep -q "accepted" \
  || error "Verification failed — app not properly notarized."

# ----------------------------------------------------------
# Step 8: Create DMG
# ----------------------------------------------------------
VERSION=$(yq '.version' "${APP_DIR}/pubspec.yaml")
VERSION_SHORT=$(echo "$VERSION" | sed -e "s/+.*//")
DMG_NAME="Keychat-${VERSION}-macos-arm64.dmg"

log "Creating DMG (version: ${VERSION})..."
create-dmg "$APP_PATH" --overwrite --dmg-title='Keychat'

# create-dmg outputs "Keychat <version_short>.dmg" in cwd
DMG_SRC="Keychat ${VERSION_SHORT}.dmg"
[[ -f "$DMG_SRC" ]] || error "DMG creation failed — ${DMG_SRC} not found."

mv "$DMG_SRC" "${EXPORT_DIR}/${DMG_NAME}"

DMG_PATH="${EXPORT_DIR}/${DMG_NAME}"

log "=========================================="
log "Build complete!"
log "  App: ${APP_PATH}"
log "  DMG: ${DMG_PATH}"
log "=========================================="
open "$EXPORT_DIR"

# ----------------------------------------------------------
# Step 9 (optional): Upload to Google Drive & get share link
# ----------------------------------------------------------
if [[ "$UPLOAD" == true ]]; then
  log "Uploading DMG to Google Drive (${RCLONE_REMOTE}:${RCLONE_FOLDER})..."
  rclone copy "$DMG_PATH" "${RCLONE_REMOTE}:${RCLONE_FOLDER}" --progress

  # Get the file ID of the uploaded file
  FILE_ID=$(rclone lsf "${RCLONE_REMOTE}:${RCLONE_FOLDER}/${DMG_NAME}" --format "i" | head -1)
  [[ -n "$FILE_ID" ]] || error "Failed to get file ID from Google Drive."

  # Set file to "anyone with the link can view"
  rclone backend set "${RCLONE_REMOTE}:${RCLONE_FOLDER}/${DMG_NAME}" \
    --opt role=reader --opt type=anyone 2>/dev/null \
    || warn "Could not set share permission automatically. Share manually in Google Drive."

  SHARE_LINK="https://drive.google.com/file/d/${FILE_ID}/view?usp=sharing"

  log "=========================================="
  log "Google Drive: ${SHARE_LINK}"
  log "=========================================="
fi
