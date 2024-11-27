C:\AndroidStudio\jre\bin\keytool -genkey -v -keystore d:\flutter-app.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 36500 -alias nc65

C:\AndroidStudio\jre\bin\keytool -importkeystore -srckeystore d:\flutter-app.jks -destkeystore d:\flutter-app.jks -deststoretype pkcs12


  keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload


## adb
```
adb devices

adb push ./packages/app/build/app/outputs/apk/release/app-arm64-v8a-release.apk /sdcard/Download

adb install /storage/emulated/0/Download/app-arm64-v8a-release.apk

```
