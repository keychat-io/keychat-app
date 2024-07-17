#!/bin/sh
# flutter build apk -v -t lib/main_prod.dart --target-platform android-arm --split-per-abi
cd packages/app/
flutter build apk --release -v -t lib/main.dart --dart-define=dart.vm.product=true --split-per-abi --obfuscate --split-debug-info=./build/obfuscate/apk/