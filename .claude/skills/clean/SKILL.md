---
name: clean
description: Clean build artifacts and reset Flutter state
disable-model-invocation: true
allowed-tools: Bash(melos *), Bash(flutter clean), Bash(rm *)
---

Clean build artifacts and reset the project state.

## Commands

### Full clean with melos
```bash
melos run clean:flutter
```

This runs in all Flutter packages:
- `flutter clean`
- `flutter pub get`
- Removes `ios/Podfile.lock`
- Runs `pod repo update && pod install`

### Quick clean for app only
```bash
cd packages/app && flutter clean && flutter pub get
```

### Clean generated files
```bash
cd packages/app && rm -rf lib/**/*.g.dart lib/**/*.isar.dart
```

## When to use

- Build errors after updating Flutter
- Inconsistent state between packages
- After major dependency changes
- Xcode or Gradle cache issues

## After cleaning

Remember to:
1. Run `melos bootstrap` to restore dependencies
2. Run `melos run generate:all` to regenerate code
3. Run `melos run pod:install` for iOS/macOS
