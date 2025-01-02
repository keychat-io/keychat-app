import 'dart:io' show Directory;

import 'package:app/global.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import '../service/storage.dart';

class SettingController extends GetxController with StateMixin<Type> {
  RxString displayName = ''.obs;

  RxBool viewKeychatFutures = false.obs;
  RxInt autoCleanMessageDays = 0.obs;
  RxString themeMode = 'system'.obs;
  RxString defaultFileServer = KeychatGlobal.defaultFileServer.obs;

  Directory appFolder = Directory('/');
  late String avatarsFolder;

  final TextEditingController relayTextController =
      TextEditingController(text: "wss://");

  @override
  void onInit() async {
    super.onInit();
    appFolder = await getApplicationDocumentsDirectory();
    viewKeychatFutures.value = await getViewKeychatFutures();
    autoCleanMessageDays.value =
        await Storage.getIntOrZero(StorageKeyString.autoDeleteMessageDays);

    // avatar folder
    avatarsFolder = '${appFolder.path}/avatars';
    Directory(avatarsFolder).exists().then((res) {
      if (res) return;
      Directory(avatarsFolder).createSync(recursive: true);
    });

    await initDefaultFileServerConfig();
  }

  @override
  void onClose() {
    relayTextController.dispose();
    super.onClose();
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

  Future initDefaultFileServerConfig() async {
    String? res = await Storage.getString(StorageKeyString.defaultFileServer);
    if (res != null) {
      defaultFileServer.value = res;
    } else {
      await Storage.setString(
          StorageKeyString.defaultFileServer, KeychatGlobal.defaultFileServer);
      defaultFileServer.value = KeychatGlobal.defaultFileServer;
    }
    return defaultFileServer.value;
  }

  Future setDefaultFileServer(String value) async {
    await Storage.setString(StorageKeyString.defaultFileServer, value);
    defaultFileServer.value = value;
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
