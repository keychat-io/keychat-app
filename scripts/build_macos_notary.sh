#!/bin/sh
# Script Name: MacOS build

# Submission ID received
#   id: f1142a30-7cbf-48e5-b602-8b8c2d820f03

submissionid="9e6a195d-c400-4727-8702-552ec6e2bf6b"
output="packages/app/build/macos/Build/Products/Release/keychat.dmg"

xcrun notarytool history --keychain-profile "NotaryProfile"
xcrun notarytool info "${submissionid}" --keychain-profile "NotaryProfile"

## staple
xcrun stapler staple -v $output
# spctl --assess --type open --verbose=4 $output




