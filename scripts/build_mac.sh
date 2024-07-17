#!/bin/sh
# Script Name: MacOS build
# sudo ln -s ~/Library/Developer/Xcode/DerivedData/Runner-gkbkhjbjeyjuwbbzcftuvlbijsmr/Build/Products/Debug/rust.dylib /usr/local/lib/rust.dylib

flutter build macos -t lib/main.dart --obfuscate --split-debug-info=./docs/obfuscate/macos/
open macos/Runner.xcworkspace