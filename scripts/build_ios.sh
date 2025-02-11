#!/bin/sh
current_path=$(pwd)
# Script Name: iOS build
# echo "Update keychat_rust_ffi_plugin start..."
# cd packages/keychat_rust_ffi_plugin
# git pull origin 
# git log -n 2 --pretty=format:"%h - %s (%ci)"
# cargo build --target aarch64-apple-ios --release
# cd ../../
# echo "Update keychat_rust_ffi_plugin success"

# echo "Update ios starting..."
# git log -n 2 --pretty=format:"%h - %s (%ci)"
# cd packages/app/ios
# rm -rf Podfile.lock
# pod repo update && pod install
# cd ../../../


echo "Update app starting..."
# melos clean
# melos bs --ignore="*build_tool_runner*"
cd packages/app/
# dart fix --apply

flutter build ipa --dart-define=dart.vm.product=true --release --analyze-size # --obfuscate --split-debug-info=./build/obfuscate/ios/

# open build/ios/archive/Runner.xcarchive/

ipa="$current_path/packages/app/build/ios/ipa/keychat.ipa"
xcrun altool --validate-app --type ios -f "$ipa" --apiKey 8Y6J352PMA --apiIssuer 31ce5c4a-e7c2-4a70-9155-51c83b639243
xcrun -v altool --upload-app --type ios -f "$ipa" --apiKey 8Y6J352PMA --apiIssuer 31ce5c4a-e7c2-4a70-9155-51c83b639243