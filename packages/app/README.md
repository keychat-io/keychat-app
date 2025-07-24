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

### Universal link

```
adb shell am start -a android.intent.action.VIEW \
    -c android.intent.category.BROWSABLE \
    -d "https://www.keychat.io/u/npub10v2vdw8rulxj4s4h6ugh4ru7qlzqr7z2u8px5s4zlh2lsghs6lysyf69mf"
```

### deep link
```
# android
adb shell am start -W -a android.intent.action.VIEW -d "keychat://www.keychat.io/u/npub10v2vdw8rulxj4s4h6ugh4ru7qlzqr7z2u8px5s4zlh2lsghs6lysyf69mf" com.keychat.io

# iOS
/usr/bin/xcrun simctl openurl booted "keychat://www.keychat.io/u/npub10v2vdw8rulxj4s4h6ugh4ru7qlzqr7z2u8px5s4zlh2lsghs6lysyf69mf"

```

### cashu scheme
adb shell am start -W -a android.intent.action.VIEW -d "cashu:cashuBo2FteBtodHRwczovL3Rlc3RudXQuY2FzaHUuc3BhY2VhdWNzYXRhdIGiYWlIAJofKTJT5B5hcIKjYWEEYXN4QDgzMDE3ODY1ZGJmMjgxNzEwZmY5OTUwOTkxNmE2MDA4NDhkNGZmM2FlODE4YmYzNjgxMTk1M2Y1MzRiNTUwYjVhY1ghA7CM51SOmJDzwJEeStQoIeyTq8KG8RSyG62zFI4TLmclpGFhAWFzeEAzNGZiNTZhYWI1ZmEwZWYzMGU4MDM0ZjZkNjY1MDUxYjViODc4NWQ2Yjk5N2MzYjhiZjE5YjAxNTA4NzRiMDMwYWNYIQJZDQ_cIMo_lKQbPoe_OfAAYxmpUbszgMGDc7W1V7_EQmFko2FlWCA1N1gGVhkV7yL5o8BnqtosG9OKM0djhph9y1oQIKlRaWFzWCAiyuxYu0Ps4d8jL6NCRaJ88omV0I4eiO_gcId5Dd3i22FyWCD1JfnxXQUeFKidFcR38uHcPY2blflxX61RqnMb2kDgzQ"

### lightning scheme
adb shell am start -W -a android.intent.action.VIEW -d "lightning:lnbc50n1p58ws58pp552983df7uzcngsfplq3u4662uczgxgxk0qsmxxzcardc6az2s52qdqqcqzpuxqrwzqsp5srv8f7gg8hhw8qpcm0mm29cm7kztxgm48vmth3nz67ny6yj2xqhq9qxpqysgq2573fx9ej620yd7mpep4pqfkhhrtxchmnmpsnvzt8yjakmhgvkppyd48587uk90j6cu5e42sgt97a062gpgxh4aqzaszqe7lg9eet2gp69fsac"

### lnurlp scheme
adb shell am start -W -a android.intent.action.VIEW -d "lnurlp:LNURL1DP68GURN8GHJ7UM9WFMXJCM99E3K7MF0V9CXJ0M385EKVCENXC6R2C35XVUKXEFCV5MKVV34X5EKZD3EV56NYD3HXQURZEPEXEJXXEPNXSCRVWFNV9NXZCN9XQ6XYEFHVGCXXCMYXYMNSERXFQ5FNS"

### nostr scheme
adb shell am start -W -a android.intent.action.VIEW -d "nostr:npub10v2vdw8rulxj4s4h6ugh4ru7qlzqr7z2u8px5s4zlh2lsghs6lysyf69mf"





