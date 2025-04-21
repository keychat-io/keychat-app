#!/bin/sh
# flutter build apk -v -t lib/main_prod.dart --target-platform android-arm --split-per-abi
current_path=$(pwd)
cd packages/app/
flutter build apk --release -v -t lib/main.dart --dart-define=dart.vm.product=true --split-per-abi --obfuscate --split-debug-info=./build/obfuscate/apk/

output="$current_path/packages/app/build/app/outputs/apk/release"
echo "Apk path: $output"
open $output

# flutter symbolize -d build/obfuscate/apk/app.android-arm64.symbols -i ./2025-04-21-error.log