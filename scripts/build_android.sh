#!/bin/sh
# flutter build apk -v -t lib/main_prod.dart --target-platform android-arm --split-per-abi
current_path=$(pwd)
cd packages/app/
flutter build apk --release -v -t lib/main.dart

output="$current_path/packages/app/build/app/outputs/apk/release"
echo "Apk path: $output"
open $output

