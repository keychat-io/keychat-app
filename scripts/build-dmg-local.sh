#!/bin/zsh

set -e

if [ ! -d ~/Desktop/Keychat.app ]; then
  echo "🟨 No build found"
  exit 1
fi

VERSION=$(yq '.version' packages/app/pubspec.yaml)
echo "VERSION: $VERSION."
VERSION_SHORT=$(echo "$VERSION" | sed -e "s/+.*//")
echo "VERSION_SHORT: $VERSION_SHORT."

create-dmg ~/Desktop/Keychat.app --overwrite --dmg-title='Keychat'

APP_FILE_NAME="Keychat-$VERSION-macos-arm64.dmg"

test -f "$APP_FILE_NAME" && rm -f "$APP_FILE_NAME"

mv "Keychat $VERSION_SHORT.dmg" "$APP_FILE_NAME"

# sha256sum "$APP_FILE_NAME" > "${APP_FILE_NAME}.sha256"

exit 0