import 'dart:io' show Directory;

import 'package:app/global.dart';
import 'package:app/utils.dart';
import 'package:get/get.dart';
import '../service/storage.dart';

class SettingController extends GetxController with StateMixin<Type> {
  RxString displayName = ''.obs;

  RxBool viewKeychatFutures = false.obs;
  RxInt autoCleanMessageDays = 0.obs;
  RxString themeMode = 'system'.obs;
  RxString defaultFileServer = KeychatGlobal.defaultFileServer.obs;

  Directory appFolder = Directory('/');
  late String avatarsFolder;
  late String browserCacheFolder;

  @override
  void onInit() async {
    super.onInit();
    appFolder = await Utils.getAppFolder();

    // viewKeychatFutures.value = await getViewKeychatFutures();
    autoCleanMessageDays.value =
        await Storage.getIntOrZero(StorageKeyString.autoDeleteMessageDays);

    // avatar folder
    avatarsFolder = '${appFolder.path}/avatars';
    browserCacheFolder = '${appFolder.path}/browserCache';

    for (var folder in [avatarsFolder, browserCacheFolder]) {
      Directory(folder).exists().then((res) {
        if (res) return;
        Directory(folder).createSync(recursive: true);
      });
    }
    // file server
    initDefaultFileServerConfig();
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

  Future<void> initDefaultFileServerConfig() async {
    String? res = await Storage.getString(StorageKeyString.defaultFileServer);
    if (res != null) {
      defaultFileServer.value = res;
      return;
    }
    await Storage.setString(
        StorageKeyString.defaultFileServer, KeychatGlobal.defaultFileServer);
    defaultFileServer.value = KeychatGlobal.defaultFileServer;
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
