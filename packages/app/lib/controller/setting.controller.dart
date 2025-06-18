import 'dart:io' show Directory;

import 'package:app/global.dart';
import 'package:app/utils.dart';
import 'package:flutter/foundation.dart'
    show FlutterError, FlutterErrorDetails, PlatformDispatcher;

import 'package:get/get.dart';
import '../service/storage.dart';

enum MediaServerType {
  blossom,
  keychatS3,
  nip94,
}

class SettingController extends GetxController with StateMixin<Type> {
  RxString displayName = ''.obs;

  RxBool viewKeychatFutures = false.obs;
  RxInt autoCleanMessageDays = 0.obs;
  RxString themeMode = 'system'.obs;
  RxString defaultFileServer = KeychatGlobal.defaultFileServer.obs;
  RxString defaultFileMediaType = MediaServerType.blossom.name.obs;

  Directory appFolder = Directory('/');
  late String avatarsFolder;
  late String browserCacheFolder;
  late String browserUserDataFolder;

  List<String> builtInMedias = [
    "https://void.cat",
    "https://cdn.nostrcheck.me",
    "https://nostr.download",
    "https://nostrmedia.com",
    "https://cdn.satellite.earth",
  ];

  @override
  void onInit() async {
    appFolder = await Utils.getAppFolder();

    // viewKeychatFutures.value = await getViewKeychatFutures();
    autoCleanMessageDays.value =
        await Storage.getIntOrZero(StorageKeyString.autoDeleteMessageDays);

    // avatar folder
    avatarsFolder = '${appFolder.path}/avatars';
    browserCacheFolder = '${appFolder.path}/browserCache';
    browserUserDataFolder = '${appFolder.path}/browserUserData';
    String errorsFolder = '${appFolder.path}/errors';

    for (var folder in [
      avatarsFolder,
      browserCacheFolder,
      browserUserDataFolder,
      errorsFolder
    ]) {
      Directory(folder).exists().then((res) {
        if (res) return;
        Directory(folder).createSync(recursive: true);
      });
    }
    // Catch uncaught Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);

      final error = StringBuffer()
        ..writeln('Time: ${DateTime.now()}')
        ..writeln('Error: ${details.exceptionAsString()}')
        ..writeln('Stack Trace: ${details.stack}')
        ..writeln('Library: ${details.library}')
        ..writeln('Context: ${details.context}');

      Utils.logErrorToFile(error.toString());
    };

    // Catch errors not handled by Flutter
    PlatformDispatcher.instance.onError = (error, stack) {
      final errorDetails = StringBuffer()
        ..writeln('Time: ${DateTime.now()}')
        ..writeln('Error: $error')
        ..writeln('Stack Trace: $stack');

      Utils.logErrorToFile(errorDetails.toString());
      return true; // Return true to prevent the error from propagating
    };
    super.onInit();

    // file server
    initRelayFileServerConfig();
  }

  getViewKeychatFutures() async {
    int res =
        await Storage.getIntOrZero(StorageKeyString.getViewKeychatFutures);
    return res == 1;
  }

  setViewKeychatFutures() async {
    await Storage.setInt(StorageKeyString.getViewKeychatFutures, 1);
    viewKeychatFutures.value = true;
  }

  Future<void> initRelayFileServerConfig() async {
    String? res = await Storage.getString(StorageKeyString.defaultFileServer);
    if (res != null) {
      defaultFileServer.value = res;
      return;
    }
    await Storage.setString(
        StorageKeyString.defaultFileServer, KeychatGlobal.defaultFileServer);
    defaultFileServer.value = KeychatGlobal.defaultFileServer;
  }

  Future setDefaultRelayFileServer(String value) async {
    await Storage.setString(StorageKeyString.defaultFileServer, value);
    defaultFileServer.value = value;
  }

  Future<void> initMediaServerConfig() async {
    String? res =
        await Storage.getString(StorageKeyString.defaultFileMediaType);
    if (res != null) {
      defaultFileMediaType.value = res;
    }
  }

  Future<void> seteFileMediaType(String value) async {
    await Storage.setString(StorageKeyString.defaultFileMediaType, value);
    defaultFileMediaType.value = value;
  }

  String getHttpDefaultFileApi() {
    String fileUploadUrl = '${defaultFileServer.value}/api/v1/object';
    if (fileUploadUrl.startsWith('wss://')) {
      fileUploadUrl = fileUploadUrl.replaceFirst('wss://', 'https://');
    }
    if (fileUploadUrl.startsWith('ws://')) {
      fileUploadUrl = fileUploadUrl.replaceFirst('ws://', 'http://');
    }
    return fileUploadUrl;
  }
}
