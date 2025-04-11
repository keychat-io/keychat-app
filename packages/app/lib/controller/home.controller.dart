import 'dart:async' show StreamSubscription;
import 'dart:convert' show jsonDecode;

import 'package:app/controller/setting.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app/service/storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:flutter_new_badger/flutter_new_badger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:dio/dio.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart';
import 'package:package_info_plus/package_info_plus.dart';

class HomeController extends GetxController
    with GetTickerProviderStateMixin, WidgetsBindingObserver {
  IdentityService identityService = IdentityService.instance;
  RxMap<int, Identity> chatIdentities = <int, Identity>{}.obs;
  RxMap<int, Identity> allIdentities = <int, Identity>{}.obs;
  RxInt allUnReadCount = 0.obs;
  bool isAppBadgeSupported = false;

  RxMap<int, TabData> tabBodyDatas = <int, TabData>{}.obs;
  RxMap<int, Message?> roomLastMessage = <int, Message?>{}.obs;

  RxInt defaultSelectedTab = 0.obs;
  RxInt selectedIndex = 0.obs; // main bottom tab index

  RxString displayName = ''.obs;
  late TabController tabController;
  late StreamSubscription<List<ConnectivityResult>> subscription;
  RxBool notificationStatus = false.obs;
  RxBool checkRunStatus = true.obs;
  bool resumed = true; // is app in front
  RxBool isConnectedNetwork = true.obs;
  RxBool addFriendTips = false.obs;

  //debug mode
  RxBool debugModel = false.obs;
  RxBool debugSendMessageRunning = false.obs;
  int debugModelClickCount = 0;

  RxList recommendBots = [].obs;
  RxMap recommendWebstore = {}.obs;
  RxMap remoteAppConfig = {}.obs;

  DateTime? pausedTime;

  List<AppLifecycleState> appstates = [];

  // add identity AI and add AI contacts
  Future createAIIdentity(List<Identity> existsIdentity, String idName) async {
    String key = '${StorageKeyString.taskCreateIdentity}:$idName';
    if (existsIdentity.isEmpty) return;
    int res = await Storage.getIntOrZero(key);
    if (res == 1) return;
    for (var identity in existsIdentity) {
      if (identity.name == idName) return;
    }
    String? mnemonic = await SecureStorage.instance.getPhraseWords();
    if (mnemonic == null) return;
    List<int> phraseIndexes =
        existsIdentity.map((element) => element.index).toList();
    int unusedIndex = List.generate(10, (index) => index).firstWhere(
      (index) => !phraseIndexes.contains(index),
      orElse: () => -1,
    );
    if (unusedIndex == -1) return;
    List<Secp256k1Account> secp256k1Accounts = await rust_nostr
        .importFromPhraseWith(phrase: mnemonic, offset: unusedIndex, count: 1);

    await IdentityService.instance.createIdentity(
        name: idName,
        account: secp256k1Accounts[0],
        index: unusedIndex,
        isFirstAccount: false);
    await Storage.setInt(key, 1);
    logger.i('CreateAIIdentity Success');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    loggerNoLine.i('didChangeAppLifecycleState: ${state.toString()}');
    // ios: 2 options
    // apprun-> inactive -> resumed
    // apprun->inactive -> hidden-> paused ->hidden->inactive->resumed
    // macos:  apprun->inactive -> resumed
    appstates.add(state);
    switch (state) {
      case AppLifecycleState.resumed:
        resumed = true;

        // if app running background > 20s, then reconnect. Otherwise check status first
        bool isPaused = false;
        if (GetPlatform.isMobile &&
            appstates.contains(AppLifecycleState.paused)) {
          if (pausedTime != null) {
            isPaused = DateTime.now()
                .subtract(const Duration(seconds: 10))
                .isAfter(pausedTime!);
          }
        }
        appstates.clear();
        if (GetPlatform.isMobile) {
          removeBadge();
        }
        EasyThrottle.throttle(
            'AppLifecycleState.resumed', const Duration(seconds: 3), () {
          Get.find<WebsocketService>().checkOnlineAndConnect();
          if (isPaused) {
            NostrAPI.instance.okCallback.clear();
            Utils.initLoggger(Get.find<SettingController>().appFolder);
            NotifyService.syncPubkeysToServer(checkUpload: true);
            return;
          }
        });

        return;
      case AppLifecycleState.paused:
        resumed = false;
        pausedTime = DateTime.now();
        break;
      case AppLifecycleState.detached:
        // app been killed
        break;
      default:
        break;
    }
  }

  Future loadAppRemoteConfig() async {
    String url =
        'https://raw.githubusercontent.com/keychat-io/bot-service-ai/refs/heads/main/config/app.json';
    // load app version
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    remoteAppConfig['appVersion'] =
        "${packageInfo.version}+${packageInfo.buildNumber}";
    logger.d('remoteAppConfig: $remoteAppConfig');

    try {
      var response = await Dio().get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      if (response.statusCode == 200) {
        Map config = jsonDecode(response.data);
        recommendBots.value = config['bots'];

        var recommendUrls = config['browserRecommend'] as List;
        recommendWebstore.value = recommendUrls
            .fold<Map<String, List<Map<String, dynamic>>>>({}, (acc, item) {
          List<String> categories = List<String>.from(item['categories']);
          for (var type in categories) {
            if (acc[type] == null) {
              acc[type] = [];
            }
            acc[type]!.add(item);
          }
          return acc;
        });

        // app version
        for (var key in config.keys) {
          if (key != 'bots' && key != 'browserRecommend') {
            remoteAppConfig[key] = config[key];
          }
        }
        return;
      }
    } catch (e, s) {
      logger.e('Failed to config $url: $e', stackTrace: s);
    }
  }

  Identity getSelectedIdentity() {
    return chatIdentities.values.toList()[tabController.index];
  }

  initTabController([int initialIndex = 0]) {
    tabController.dispose();
    if (initialIndex >= chatIdentities.length) {
      initialIndex = 0;
    }
    tabController = TabController(
        vsync: this, initialIndex: initialIndex, length: tabBodyDatas.length);

    tabController.addListener(() {
      Storage.setInt(
          StorageKeyString.homeSelectedTabIndex, tabController.index);
    });
    // update();
  }

  Future initTips(String name, RxBool toSetValue) async {
    var res = await Storage.getIntOrZero(name);
    toSetValue.value = res == 0 ? true : false;
  }

  Future<List<Identity>> loadIdentity() async {
    var list = await IdentityService.instance.getIdentityList();
    chatIdentities.clear();
    allIdentities.clear();
    for (var i = 0; i < list.length; i++) {
      allIdentities[list[i].id] = list[i];
      if (list[i].enableChat) {
        chatIdentities[list[i].id] = list[i];
      }
    }
    return chatIdentities.values.toList();
  }

  loadIdentityRoomList(int identityId) {
    EasyDebounce.debounce(
        'loadIdentityRoomList:$identityId', const Duration(milliseconds: 200),
        () async {
      Map<String, List<Room>> res =
          await RoomService.instance.getRoomList(identityId);
      List<dynamic> rooms = res['friends'] ?? [];
      List<Room> approving = res['approving'] ?? [];
      List<Room> requesting = res['requesting'] ?? [];

      int unReadCount = 0;
      int anonymousUnReadCount = 0;
      int requestingUnReadCount = 0;
      for (var element in rooms) {
        if (element is Room) {
          if (element.isMute) continue;
          unReadCount += element.unReadCount;
        }
      }
      for (Room element in approving) {
        if (element.isMute) continue;
        anonymousUnReadCount += element.unReadCount;
      }
      for (Room element in requesting) {
        requestingUnReadCount += element.unReadCount;
      }

      rooms = [
        KeychatGlobal.search,
        KeychatGlobal.recommendRooms,
        approving,
        requesting,
        ...rooms,
      ];
      if (tabBodyDatas[identityId] == null &&
          chatIdentities[identityId] == null) {
        return;
      }
      TabData tabBodyData =
          tabBodyDatas[identityId] ?? TabData(chatIdentities[identityId]!);
      tabBodyData.unReadCount = unReadCount;
      tabBodyData.anonymousUnReadCount = anonymousUnReadCount;
      tabBodyData.requestingUnReadCount = requestingUnReadCount;
      tabBodyData.rooms = rooms;
      tabBodyDatas.refresh();

      int unReadSum = 0;
      List keys = tabBodyDatas.keys.toList();
      for (var i = 0; i < keys.length; i++) {
        var e = keys[i];
        TabData item = tabBodyDatas[e]!;
        unReadSum = unReadSum + item.unReadCount + item.anonymousUnReadCount;
      }
      setUnreadCount(unReadSum.toInt());
    });
  }

  Future<List<Identity>> loadRoomList({bool init = false}) async {
    List<Identity> mys = await loadIdentity();

    int firstUnreadIndex = -1;
    int unReadSum = 0;
    Map<int, TabData> thisTabBodyDatas = {};
    for (var i = 0; i < mys.length; i++) {
      int id = mys[i].id;

      Map<String, List<Room>> res = await RoomService.instance.getRoomList(id);

      List<dynamic> rooms = res['friends'] ?? [];
      List<Room> approving = res['approving'] ?? [];
      List<Room> requesting = res['requesting'] ?? [];

      int unReadCount = 0;
      int anonymousUnReadCount = 0;
      int requestingUnReadCount = 0;
      for (dynamic element in rooms) {
        if (element is Room) {
          if (element.isMute) continue;
          unReadCount += element.unReadCount;
        }
      }
      for (Room element in approving) {
        if (element.isMute) continue;
        anonymousUnReadCount += element.unReadCount;
      }
      for (Room element in requesting) {
        requestingUnReadCount += element.unReadCount;
      }

      unReadSum = unReadSum +
          unReadCount +
          anonymousUnReadCount +
          requestingUnReadCount;
      if (firstUnreadIndex == -1) {
        firstUnreadIndex = unReadCount > 0 ? i : -1;
      }

      rooms = [
        KeychatGlobal.search,
        KeychatGlobal.recommendRooms,
        approving,
        requesting,
        ...rooms,
      ];

      thisTabBodyDatas[id] = TabData(mys[i])
        ..unReadCount = unReadCount
        ..anonymousUnReadCount = anonymousUnReadCount
        ..rooms = rooms;
    }

    tabBodyDatas.value = thisTabBodyDatas;
    setUnreadCount(unReadSum);

    int initialIndex = 0;
    if (firstUnreadIndex == -1) {
      var saved =
          await Storage.getIntOrZero(StorageKeyString.homeSelectedTabIndex);
      if (saved < mys.length) {
        initialIndex = saved;
      }
    } else {
      initialIndex = firstUnreadIndex;
    }

    if (!init) return mys;
    initTabController(initialIndex);
    return mys;
  }

  void networkListenHandle(List<ConnectivityResult> result) {
    if (result.contains(ConnectivityResult.none)) {
      isConnectedNetwork.value = false;
      Get.find<WebsocketService>().checkOnlineAndConnect();
    } else {
      // network from disconnected to connected
      if (!isConnectedNetwork.value) {
        Get.find<WebsocketService>().start();
      }
      isConnectedNetwork.value = true;
    }
  }

  @override
  onClose() async {
    tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    // scrollControllers.values.map((e) => e.dispose());
    rust_cashu.closeDb();
    subscription.cancel();
    Get.find<WebsocketService>().stopListening();
    if (Get.context != null) {
      Utils.hideKeyboard(Get.context!);
    }
    super.onClose();
  }

  @override
  void onInit() async {
    super.onInit();
    tabController = TabController(vsync: this, length: 0);

    List<Identity> mys = await loadRoomList(init: true);
    isAppBadgeSupported =
        GetPlatform.isAndroid || GetPlatform.isIOS || GetPlatform.isMacOS;
    // Ecash Init
    if (mys.isNotEmpty) {
      Get.find<EcashController>().initIdentity(mys[0]);
    } else {
      Get.find<EcashController>().initWithoutIdentity();
    }
    FlutterNativeSplash.remove(); // close splash page
    WidgetsBinding.instance.addObserver(this);

    // show dot on add friends menu
    initTips(StorageKeyString.tipsAddFriends, addFriendTips);

    NotifyService.init().catchError((e, s) {
      logger.e('initNotifycation error', error: e, stackTrace: s);
    });
    // listen network status https://pub.dev/packages/connectivity_plus
    subscription =
        Connectivity().onConnectivityChanged.listen(networkListenHandle);
    removeBadge();
    try {
      RoomUtil.executeAutoDelete();
    } catch (e, s) {
      logger.e(e.toString(), stackTrace: s);
    }

    // start to create ai identity
    Future.delayed(const Duration(seconds: 1), () async {
      loadAppRemoteConfig();
    });
  }

  List<Room> getRoomsByIdentity(int identityId) {
    List<dynamic> list =
        Get.find<HomeController>().tabBodyDatas[identityId]?.rooms ?? [];
    if (list.isEmpty) return [];

    List<Room> rooms = [];
    for (var i = 0; i < list.length; i++) {
      if (list[i] is String) continue;
      if (list[i] is List<Room>) {
        rooms.addAll(list[i] as List<Room>);
      }
      if (list[i] is Room) {
        rooms.add(list[i] as Room);
      }
    }
    return rooms;
  }

  Future<void> removeBadge() async {
    if (!isAppBadgeSupported) return;
    await FlutterNewBadger.removeBadge();
  }

  Future setTipsViewed(String name, RxBool toSetValue) async {
    toSetValue.value = false;
    await Storage.setInt(name, 1);
  }

  setUnreadCount(int count) async {
    if (count == allUnReadCount.value) return;
    allUnReadCount.value = count;
    allUnReadCount.refresh();
    if (!isAppBadgeSupported) return;
    if (count == 0) return await FlutterNewBadger.removeBadge();
    FlutterNewBadger.setBadge(count);
  }

  addUnreadCount() {
    allUnReadCount.value++;
    allUnReadCount.refresh();
    if (!isAppBadgeSupported) return;
    FlutterNewBadger.setBadge(allUnReadCount.value);
  }

  troggleDebugModel() {
    ++debugModelClickCount;
    if (debugModelClickCount % 5 == 0) {
      logger.i('enable debug model');
      debugModel.value = true;
      EasyLoading.showToast('Debug model enabled');
    }

    if (debugModelClickCount % 7 == 0) {
      logger.i('enable debug model');
      debugModel.value = false;
      debugModelClickCount = 0;
      EasyLoading.showToast('Debug model disabled');
    }
  }

  Future updateIdentityName(Identity identity, String name) async {
    identity.name = name;
    await IdentityService.instance.updateIdentity(identity);
    TabData? item = tabBodyDatas[identity.id];
    if (item == null) return;
    item.identity = identity;
    tabBodyDatas[identity.id] = item;
    tabBodyDatas.refresh();
  }

  void resortRoomList(int identityId) {
    TabData? item = tabBodyDatas[identityId];
    if (item == null) return;
    List<Room> friendsRooms =
        List.castFrom(item.rooms.whereType<Room>().toList());
    List<dynamic> nonRoomItems =
        item.rooms.where((element) => element is! Room).toList();
    item.rooms = [...nonRoomItems, ...RoomUtil.sortRoomList(friendsRooms)];
    tabBodyDatas[identityId] = item;
  }

  Room? getRoomByIdentity(int identityId, int roomId) {
    List<Room> list = getRoomsByIdentity(identityId);
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == roomId) {
        return list[i];
      }
    }
    return null;
  }
}

class TabData {
  int unReadCount = 0;
  int anonymousUnReadCount = 0;
  int requestingUnReadCount = 0;
  List<dynamic> rooms = [];
  late Identity identity;
  TabData(this.identity);
}
