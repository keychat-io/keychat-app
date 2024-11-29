import 'dart:async' show StreamSubscription, Timer;
import 'dart:convert' show jsonDecode;

import 'package:app/controller/setting.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app/service/storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
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

import '../constants.dart';
import '../service/identity.service.dart';
import '../service/room.service.dart';

class HomeController extends GetxController
    with GetTickerProviderStateMixin, WidgetsBindingObserver {
  IdentityService identityService = IdentityService.instance;
  RxMap<int, Identity> identities = <int, Identity>{}.obs;
  RxInt allUnReadCount = 0.obs;
  bool isAppBadgeSupported = false;

  RxMap<int, TabData> tabBodyDatas = <int, TabData>{}.obs;
  RxMap<int, Message?> roomLastMessage = <int, Message?>{}.obs;

  RxString title = appDefaultTitle.obs;

  RxInt defaultSelectedTab = 0.obs;
  RxInt selectedIndex = 0.obs; // main bottom tab index

  RxString displayName = ''.obs;
  late TabController tabController;
  late StreamSubscription<List<ConnectivityResult>> subscription;
  RxBool notificationStatus = false.obs;
  bool resumed = true; // is app in front
  RxBool isConnectedNetwork = true.obs;
  RxBool addFriendTips = false.obs;

  //debug mode
  RxBool debugModel = false.obs;
  RxBool debugSendMessageRunning = false.obs;
  int debugModelClickCount = 0;
  // final Map<int, ScrollController> scrollControllers = {};
  Timer? _checkWebsocketTimer;

  RxList recommendBots = [].obs;

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
        await removeBadge();
        EasyThrottle.throttle(
            'AppLifecycleState.resumed', const Duration(seconds: 2), () {
          if (isPaused) {
            Get.find<WebsocketService>().start().then((c) async {
              _startConnectHeartbeat();
            });
            Utils.initLoggger(Get.find<SettingController>().appFolder);
            NotifyService.syncPubkeysToServer(true);
            return;
          }
          Get.find<WebsocketService>().checkOnlineAndConnect();
        });

        return;
      case AppLifecycleState.paused:
        resumed = false;
        pausedTime = DateTime.now();
        _stopConnectHeartbeat();
        break;
      case AppLifecycleState.detached:
        // app been killed
        break;
      default:
        break;
    }
  }

  Future fetchBots() async {
    String fileName = 'bots-release.json'; //'bots-release.json';
    var list = [
      'https://raw.githubusercontent.com/keychat-io/bot-service-ai/refs/heads/main/$fileName',
      'https://mirror.ghproxy.com/https://raw.githubusercontent.com/keychat-io/bot-service-ai/refs/heads/main/$fileName'
    ];

    for (var url in list) {
      try {
        var response = await Dio().get(
          url,
          options: Options(
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        if (response.statusCode == 200) {
          recommendBots.value = jsonDecode(response.data);
          logger.d(recommendBots);
          return;
        }
      } catch (e) {
        logger.e('Failed to fetch bots from $url: $e');
      }
    }
  }

  Future<int> getDefaultSelectedTab() async {
    return await Storage.getIntOrZero(StorageKeyString.homeSelectedTabIndex);
  }

  Identity getSelectedIdentity() {
    return identities.values.toList()[tabController.index];
  }

  initTabController([int initialIndex = 0]) {
    tabController.dispose();
    if (initialIndex >= identities.length) {
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

  Future<List<Identity>> loadIdentity(
      [List<Identity> list = const <Identity>[]]) async {
    if (list.isEmpty) {
      list = await IdentityService.instance.getIdentityList();
    }
    identities.clear();
    for (var i = 0; i < list.length; i++) {
      identities[list[i].id] = list[i];
    }
    return identities.values.toList();
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

      TabData tabBodyData =
          tabBodyDatas[identityId] ?? TabData(identities[identityId]!);
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
    List<Identity> mys = await IdentityService.instance.getIdentityList();
    loadIdentity(mys);

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
      initialIndex = await getDefaultSelectedTab();
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
    } else {
      // network from disconnected to connected
      if (!isConnectedNetwork.value) {
        EasyDebounce.debounce('isConnectedNetwork', const Duration(seconds: 1),
            () {
          WebsocketService ws = Get.find<WebsocketService>();
          ws.start();
          if (ws.relayFileFeeModels.entries.isEmpty) {
            RelayService.instance.initRelayFeeInfo();
          }
        });
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

    // Ecash Init
    bool showNotificationDialog = false;
    if (mys.isNotEmpty) {
      showNotificationDialog = true;
      Get.find<EcashController>().initIdentity(mys[0]);
    } else {
      Get.find<EcashController>().initWithoutIdentity();
    }
    FlutterNativeSplash.remove(); // close splash page
    WidgetsBinding.instance.addObserver(this);

    // show dot on add friends menu
    initTips(StorageKeyString.tipsAddFriends, addFriendTips);

    NotifyService.init(showNotificationDialog).catchError((e, s) {
      logger.e('initNotifycation error', error: e, stackTrace: s);
    });
    // listen network status https://pub.dev/packages/connectivity_plus
    subscription =
        Connectivity().onConnectivityChanged.listen(networkListenHandle);
    await removeBadge();
    try {
      _startConnectHeartbeat();
      await RoomUtil.executeAutoDelete();
    } catch (e, s) {
      logger.e(e.toString(), stackTrace: s);
    }

    // start to create ai identity
    Future.delayed(const Duration(seconds: 1), () async {
      await createAIIdentity(mys, KeychatGlobal.bot);
      fetchBots();
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
    if (!GetPlatform.isMobile) return;
    try {
      bool supportBadge = await AppBadgePlus.isSupported();
      if (supportBadge) {
        AppBadgePlus.updateBadge(0);
      }
    } catch (e) {
      loggerNoLine.e('removeBadge: ${e.toString()}', error: e);
    }
  }

  Future setTipsViewed(String name, RxBool toSetValue) async {
    toSetValue.value = false;
    await Storage.setInt(name, 1);
  }

  setTitle({String? title}) {
    title ??= appDefaultTitle;

    this.title.value = title;
  }

  setUnreadCount(int count) async {
    if (count == allUnReadCount.value) return;
    allUnReadCount.value = count;
    allUnReadCount.refresh();
    if (!isAppBadgeSupported) return;
    if (count == 0) return await AppBadgePlus.updateBadge(0);
    AppBadgePlus.updateBadge(count);
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

  void _startConnectHeartbeat() async {
    _stopConnectHeartbeat();
    EasyDebounce.debounce('checkOnlineAndConnect', const Duration(seconds: 10),
        () async {
      if (!resumed) return;
      _checkWebsocketTimer =
          Timer.periodic(const Duration(minutes: 1), (timer) {
        loggerNoLine.i('checkOnlineAndConnect');
        Get.find<WebsocketService>().checkOnlineAndConnect();
      });
    });
  }

  void _stopConnectHeartbeat() {
    _checkWebsocketTimer?.cancel();
    _checkWebsocketTimer = null;
  }

  void resortRoomList(int identityId) {
    TabData? item = tabBodyDatas[identityId];
    if (item == null) return;
    List<Room> friendsRooms =
        List.castFrom(item.rooms.whereType<Room>().toList());
    // // is the first room. nothing changed
    // if (friendsRooms.isNotEmpty) {
    //   if (friendsRooms[0].id == model.roomId) return;
    // }
    List<dynamic> nonRoomItems =
        item.rooms.where((element) => element is! Room).toList();
    item.rooms = [...nonRoomItems, ...RoomUtil.sortRoomList(friendsRooms)];
    tabBodyDatas[identityId] = item;
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
