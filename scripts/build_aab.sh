#!/bin/sh
current_path=$(pwd)
cd packages/app/
flutter build appbundle --release -v -t lib/main.dart \
    --target-platform android-arm64,android-x64 \
    --dart-define=dart.vm.product=true \
    --obfuscate --split-debug-info=./build/obfuscate/apk/

output="$current_path/packages/app/build/app/outputs/bundle/release/"
echo "Apk path: $output"
open $output