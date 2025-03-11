#!/bin/sh
current_path=$(pwd)
cd packages/app/
flutter build appbundle --release -v --dart-define=dart.vm.product=true --obfuscate --split-debug-info=./build/obfuscate/aab/

output="$current_path/packages/app/build/app/outputs/bundle/release"
echo "Apk path: $output"
open $output