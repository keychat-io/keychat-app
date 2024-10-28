import 'dart:async' show StreamSubscription, Timer;
import 'dart:convert' show jsonDecode;

import 'package:app/controller/setting.controller.dart';
import 'package:app/global.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:app/service/notify.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart';

import '../constants.dart';
import 'package:app/models/models.dart';
import '../service/identity.service.dart';
import '../service/room.service.dart';

class TabData {
  int unReadCount = 0;
  int anonymousUnReadCount = 0;
  int requestingUnReadCount = 0;
  List<dynamic> rooms = [];
  late Identity identity;
  TabData(this.identity);
}

class HomeController extends GetxController
    with GetTickerProviderStateMixin, WidgetsBindingObserver {
  IdentityService identityService = IdentityService();
  RxMap<int, Identity> identities = <int, Identity>{}.obs;
  RxInt allUnReadCount = 0.obs;
  bool isAppBadgeSupported = false;

  RxMap<int, TabData> tabBodyDatas = <int, TabData>{}.obs;

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
    // Future.delayed(const Duration(seconds: 1), () async {
    //   await createAIIdentity(mys, KeychatGlobal.bot);
    //   fetchBots();
    // });
  }

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

    await IdentityService().createIdentity(
        name: idName,
        account: secp256k1Accounts[0],
        index: unusedIndex,
        isFirstAccount: false);
    await Storage.setInt(key, 1);
    logger.i('CreateAIIdentity Success');
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
            RelayService().initRelayFeeInfo();
          }
        });
      }
      isConnectedNetwork.value = true;
    }
  }

  void _stopConnectHeartbeat() {
    _checkWebsocketTimer?.cancel();
    _checkWebsocketTimer = null;
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

  Future<List<Identity>> loadIdentity(
      [List<Identity> list = const <Identity>[]]) async {
    if (list.isEmpty) {
      list = await IdentityService().getIdentityList();
    }
    identities.clear();
    for (var i = 0; i < list.length; i++) {
      identities[list[i].id] = list[i];
    }
    return identities.values.toList();
  }

  Identity getSelectedIdentity() {
    return identities.values.toList()[tabController.index];
  }

  Future<int> getDefaultSelectedTab() async {
    return await Storage.getIntOrZero(StorageKeyString.homeSelectedTabIndex);
  }

  setTitle({String? title}) {
    title ??= appDefaultTitle;

    this.title.value = title;
  }

  Future<List<Identity>> loadRoomList({bool init = false}) async {
    List<Identity> mys = await IdentityService().getIdentityList();
    loadIdentity(mys);

    int firstUnreadIndex = -1;
    int unReadSum = 0;
    Map<int, TabData> thisTabBodyDatas = {};
    for (var i = 0; i < mys.length; i++) {
      int id = mys[i].id;

      Map<String, List<Room>> res =
          await RoomService().getRoomList(indetityId: id);
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

  loadIdentityRoomList(int identityId) {
    EasyDebounce.debounce(
        'loadIdentityRoomList:$identityId', const Duration(milliseconds: 200),
        () async {
      logger.d('Loading rooms: $identityId');
      Map<String, List<Room>> res =
          await RoomService().getRoomList(indetityId: identityId);
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

  setUnreadCount(int count) async {
    if (count == allUnReadCount.value) return;
    allUnReadCount.value = count;
    allUnReadCount.refresh();
    if (!isAppBadgeSupported) return;
    if (count == 0) return await AppBadgePlus.updateBadge(0);
    AppBadgePlus.updateBadge(count);
  }

  DateTime? pausedTime;
  List<AppLifecycleState> appstates = [];
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

  Future updateIdentityName(Identity identity, String name) async {
    identity.name = name;
    await IdentityService().updateIdentity(identity);
    TabData? item = tabBodyDatas[identity.id];
    if (item == null) return;
    item.identity = identity;
    tabBodyDatas[identity.id] = item;
    tabBodyDatas.refresh();
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

  updateLatestMessage(Message model) {
    int identityId = model.identityId;
    TabData? item = tabBodyDatas[identityId];
    if (item == null) return;
    List<dynamic> rooms = item.rooms;
    for (var i = 0; i < rooms.length; i++) {
      if (rooms[i] is Room) {
        Room room = rooms[i];
        if (room.id == model.roomId) {
          room.lastMessageModel = model;
          rooms[i] = room;
          List<Room> firendsRooms = [];
          for (var e in rooms) {
            if (e is Room) {
              firendsRooms.add(e);
            }
          }

          item.rooms = [
            rooms[0],
            rooms[1],
            rooms[2],
            rooms[3],
            ...RoomUtil.sortRoomList(firendsRooms)
          ];
          tabBodyDatas[identityId] = item;
          return;
        }
      }
    }
  }

  Future initTips(String name, RxBool toSetValue) async {
    var res = await Storage.getIntOrZero(name);
    toSetValue.value = res == 0 ? true : false;
  }

  Future setTipsViewed(String name, RxBool toSetValue) async {
    toSetValue.value = false;
    await Storage.setInt(name, 1);
  }

  Future fetchBots() async {
    String fileName =
        kReleaseMode ? 'bots-release.json' : 'bots-development.json';
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
}
