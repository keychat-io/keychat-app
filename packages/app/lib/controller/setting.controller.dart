import 'dart:io' show Directory;

import 'package:app/app.dart';
import 'package:flutter/foundation.dart'
    show FlutterError, FlutterErrorDetails, PlatformDispatcher;

import 'package:get/get.dart';

class SettingController extends GetxController with StateMixin<Type> {
  RxString displayName = ''.obs;

  RxBool viewKeychatFutures = false.obs;
  RxInt autoCleanMessageDays = 0.obs;
  RxString themeMode = 'system'.obs;
  RxString selectedMediaServer = KeychatGlobal.defaultFileServer.obs;
  RxList<String> mediaServers =
      [KeychatGlobal.defaultFileServer, 'https://nostr.download'].obs;

  Directory appFolder = Directory('/');
  late String avatarsFolder;
  late String browserCacheFolder;
  late String browserUserDataFolder;

  List<String> builtInMedias = [
    "https://void.cat",
    "https://nostr.download",
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
      return true;
    };
    super.onInit();
    initMediaServer();
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

  Future<void> initMediaServer() async {
    String? res = await Storage.getString(StorageKeyString.selectedMediaServer);
    if (res != null) {
      selectedMediaServer.value = res;
    }

    List<String> servers =
        await Storage.getStringList(StorageKeyString.mediaServers);
    if (servers.isNotEmpty) {
      mediaServers.value = servers;
    }
  }

  setSelectedMediaServer(String server) async {
    selectedMediaServer.value = server;
    await Storage.setString(StorageKeyString.selectedMediaServer, server);
  }

  setMediaServers(List<String> servers) async {
    mediaServers.value = servers;
    await Storage.setStringList(StorageKeyString.mediaServers, servers);
  }

  void removeMediaServer(String url) async {
    mediaServers.remove(url);
    if (url == selectedMediaServer.value) {
      selectedMediaServer.value = mediaServers.isNotEmpty
          ? mediaServers.first
          : KeychatGlobal.defaultFileServer;
    }
    await Storage.setStringList(
        StorageKeyString.mediaServers, List.from(mediaServers));
  }
}
