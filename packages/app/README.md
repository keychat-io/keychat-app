# app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# keychat

```
flutter doctor
```

- run app

```
flutter packages get
flutter run

open -a simulator
flutter run -d divce_name

```

## relays

curl -H "Accept: application/nostr+json" <https://relay.keychat.io>

## build db

flutter pub run build_runner build

flutter build macos -t lib/main_prod.dart --obfuscate --split-debug-info=./obfuscate/mascos/

## ios

```
cd ios
pod repo update && pod install
flutter build ipa -t lib/main_prod.dart --obfuscate --split-debug-info=./obfuscate/ios/

open build/ios/archive/Runner.xcarchive/
```

## test

flutter test test/test_test.dart

The sandbox is not in sync with the Podfile.lock. Run 'pod install' or update your CocoaPods installation.

## Linux

install protoc 29.0
<https://github.com/protocolbuffers/protobuf/releases/>

```sh
sudo apt-get install -y libsecret-1-dev libjsoncpp-dev libsecret-1-0
sudo apt install libstdc++-13-dev cmake ninja-build

cargo install flutter_rust_bridge_codegen
cargo build --target x86_64-unknown-linux-gnu --release --target-dir target
```

## deb

<https://medium.com/@fluttergems/packaging-and-distributing-flutter-desktop-apps-the-missing-guide-part-3-linux-24ef8d30a5b4>

```sh
sudo apt install -y rpm patchelf locate
dart pub global activate flutter_distributor

chmod +x ./app-1.27.2+6327-linux.deb
sudo dpkg -i ./app-1.27.2+6327-linux.deb
```

```sh
dart pub global activate fastforge
flutter_distributor release --name=dev --jobs=release-dev-linux-deb
sudo apt --fix-broken  install keychat.deb
```

### appimage

```sh
wget -O appimagetool "https://ghfast.top/https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"

chmod +x appimagetool 
sudo mv appimagetool /usr/local/bin/

flutter_distributor package --platform linux --targets appimage

```
