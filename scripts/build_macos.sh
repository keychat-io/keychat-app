#!/bin/sh
# Script Name: MacOS build

# submissionid="9e6a195d-c400-4727-8702-552ec6e2bf6b"
# output="packages/app/build/macos/Build/Products/Release/keychat.dmg"
# xcrun notarytool history --keychain-profile "NotaryProfile"
# xcrun notarytool info "${submissionid}" --keychain-profile "NotaryProfile"
# ## staple
# xcrun stapler staple -v $output

current_path=$(pwd)
cd packages/app/
rm -rf build/macos && flutter build macos --release -v

dart run dmg --sign-certificate "xxx" --verbose --no-build --notary-profile "NotaryProfile2"

output="$current_path/packages/app/build/macos/Build/Products/Release"
echo "dmg path: $output"
open $output

# output: build/macos/Build/Products/Release/<name>.dmg

## or export *.app from xcode and create dmg by create-dmg
# click widown-> Organizer -> Archives -> Notary app -> Export  -> keychat.app

# https://github.com/sindresorhus/create-dmg
# npm install --global create-dmg
# copy file path: alt+cmd+c
# create-dmg '~/Desktop/Keychat.app' --overwrite --dmg-title='Keychat' './Keychat.dmg'