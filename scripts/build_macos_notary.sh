#!/bin/sh
# Script Name: MacOS build

# Submission ID received
#   id: f1142a30-7cbf-48e5-b602-8b8c2d820f03

submissionid="f1142a30-7cbf-48e5-b602-8b8c2d820f03"
xcrun notarytool info "${submissionid}" --keychain-profile "NotaryProfile"
# xcrun notarytool history --keychain-profile "NotaryProfile"
# xcrun notarytool log <submission-id> --keychain-profile "NotaryProfile"

## staple
output="packages/app/build/macos/Build/Products/Release/keychat-desktop.dmg"
# xcrun stapler staple $output
spctl --assess --type open --verbose=4 $output




