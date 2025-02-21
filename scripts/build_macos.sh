#!/bin/sh
# Script Name: MacOS build

# submissionid="9e6a195d-c400-4727-8702-552ec6e2bf6b"
# output="packages/app/build/macos/Build/Products/Release/keychat.dmg"
# xcrun notarytool history --keychain-profile "NotaryProfile"
# xcrun notarytool info "${submissionid}" --keychain-profile "NotaryProfile"
# ## staple
# xcrun stapler staple -v $output

cd packages/app/
rm -rf build/macos && flutter build macos --release -v

dart run dmg --sign-certificate "Developer ID Application: kai mei (HDBNSZBLMN)" --verbose --no-build --notary-profile "NotaryProfile"

# output: build/macos/Build/Products/Release/<name>.dmg

## or export *.app from xcode and create dmg by create-dmg
# click widown-> Organizer -> Archives -> validate app -> Export  -> keychat.app
# create dmg by .app file
# https://github.com/sindresorhus/create-dmg
# npm install --global create-dmg
# create-dmg 'path/to/.app' --overwrite --dmg-title='keychat' 'path/to/output/.dmg'