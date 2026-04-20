#!/bin/sh
start_ts=$(date +%s)
# flutter build apk -v -t lib/main_prod.dart --target-platform android-arm --split-per-abi
current_path=$(pwd)
cd packages/app/
flutter build apk --release -v -t lib/main.dart \
    --target-platform android-arm64,android-x64 \
    --split-per-abi

output="$current_path/packages/app/build/app/outputs/apk/release"
echo "Apk path: $output"
open $output

end_ts=$(date +%s)
elapsed=$(( end_ts - start_ts ))
echo "🚀🚀🚀🚀Success: ${elapsed} seconds🚀🚀🚀🚀"

