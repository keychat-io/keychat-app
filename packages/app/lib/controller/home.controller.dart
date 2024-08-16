import 'dart:async' show StreamSubscription, Timer;

import 'package:app/controller/setting.controller.dart';
import 'package:app/global.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rustCashu;

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

  //debug mode
  RxBool debugModel = false.obs;
  RxBool debugSendMessageRunning = false.obs;
  int debugModelClickCount = 0;
  // final Map<int, ScrollController> scrollControllers = {};
  Timer? _checkWebsocketTimer;
  @override
  void onInit() async {
    super.onInit();
    tabController = TabController(vsync: this, length: 0);

    List<Identity> mys = await loadRoomList(init: true);

    // Ecash Init
    if (mys.isNotEmpty) {
      Get.find<EcashController>().initIdentity(mys[0]);
    } else {
      Get.find<EcashController>().initWithoutIdentity();
    }
    FlutterNativeSplash.remove(); // close splash page
    WidgetsBinding.instance.addObserver(this);

    // listen network status https://pub.dev/packages/connectivity_plus
    subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      if (result.contains(ConnectivityResult.none)) {
        isConnectedNetwork.value = false;
      } else {
        // network from disconnected to connected
        if (!isConnectedNetwork.value) {
          EasyDebounce.debounce(
              'isConnectedNetwork', const Duration(seconds: 1), () {
            WebsocketService ws = Get.find<WebsocketService>();
            ws.start();
            if (ws.relayFileFeeModels.entries.isEmpty) {
              RelayService().initRelayFeeInfo();
            }
          });
        }
        isConnectedNetwork.value = true;
      }
    });
    NotifyService.initOnesignal().catchError((e, s) {
      logger.e('initNotifycation error', error: e, stackTrace: s);
    });

    try {
      await RoomUtil.executeAutoDelete();
    } catch (e, s) {
      logger.e(e.toString(), stackTrace: s);
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
    rustCashu.closeDb();
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

  Future loadIdentityRoomList(int identityId) async {
    EasyDebounce.debounce(
        'loadIdentityRoomList:$identityId', const Duration(milliseconds: 200),
        () async {
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

        EasyThrottle.throttle(
            'AppLifecycleState.resumed', const Duration(seconds: 2), () {
          if (isPaused) {
            Get.find<WebsocketService>().start().then((c) async {
              if (kReleaseMode) {
                _startConnectHeartbeat();
              }
            });
            Utils.initLoggger(Get.find<SettingController>().appFolder);
            NotifyService.initNofityConfig(true);
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
}
