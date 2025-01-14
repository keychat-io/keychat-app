#!/bin/sh
# Script Name: MacOS build
 
# flutter build macos -t lib/main.dart --obfuscate --split-debug-info=./docs/obfuscate/macos/
# open macos/Runner.xcworkspace
# https://pub.dev/packages/dmg
# rm -rf build/macos && flutter build macos --release -v
# dart run dmg --sign-certificate "Developer ID Application: kai mei (HDBNSZBLMN)" --verbose --no-build

# output: build/macos/Build/Products/Release/<name>.dmg

# create dmg by .app file
# https://github.com/sindresorhus/create-dmg
# npm install --global create-dmg

flutter build macos --release -v
open packages/app/build/macos.xcworkspace
# click widown-> Organizer -> Archives -> validate app -> Export  -> keychat.app
# create-dmg "xx/keychat.app" --identity "Developer ID Application: xx (xx)" --overwrite --dmg-title "keychat" packages/app/build/macos/Build/Products/Release

create-dmg "/Users/liuxing/Desktop/Runner 2025-01-13 11-11-19/keychat.app" --overwrite --dmg-title "keychat" packages/app/build/macos/Build/Products/Release
