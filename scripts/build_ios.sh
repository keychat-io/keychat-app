#!/bin/sh
# Script Name: iOS build
cd packages/app/
dart fix --apply

flutter build ipa -t lib/main.dart --dart-define=dart.vm.product=true --release --analyze-size # --obfuscate --split-debug-info=./build/obfuscate/ios/

# open build/ios/archive/Runner.xcarchive/

xcrun altool --validate-app --type ios -f build/ios/ipa/*.ipa --apiKey 8Y6J352PMA --apiIssuer 31ce5c4a-e7c2-4a70-9155-51c83b639243

xcrun -v altool --upload-app --type ios -f build/ios/ipa/*.ipa --apiKey 8Y6J352PMA --apiIssuer 31ce5c4a-e7c2-4a70-9155-51c83b639243