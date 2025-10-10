import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:convert' show jsonDecode;

import 'package:app/controller/setting.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/page/chat/ForwardSelectRoom.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/chat/create_contact_page.dart';
import 'package:app/page/setting/BiometricAuthScreen.dart';
import 'package:app/service/file.service.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/qrscan.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app/service/storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:app/utils/remote_config.dart' as remote_config;
import 'package:app_links/app_links.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart' show CupertinoTabController;
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_new_badger/flutter_new_badger.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:keychat_ecash/PayInvoice/PayInvoice_page.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart'
    show ReceiveSharingIntent, SharedMediaFile, SharedMediaType;

class HomeController extends GetxController
    with GetTickerProviderStateMixin, WidgetsBindingObserver {
  IdentityService identityService = IdentityService.instance;
  RxMap<int, Identity> chatIdentities = <int, Identity>{}.obs;
  RxMap<int, Identity> allIdentities = <int, Identity>{}.obs;
  RxInt allUnReadCount = 0.obs;
  bool isAppBadgeSupported = false;

  RxMap<int, TabData> tabBodyDatas = <int, TabData>{}.obs;
  RxMap<int, Message?> roomLastMessage = <int, Message?>{}.obs;

  RxString displayName = ''.obs;
  late TabController tabController;
  late StreamSubscription<List<ConnectivityResult>> subscription;
  late Timer _connectionCheckTimer;
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

  // Privacy protection blur effect
  RxBool isBlurred = false.obs;

  RxInt defaultSelectedTab =
      (-1).obs; // 0: chat, 1: browser, -1: last opened tab
  int selectedTabIndex = 0; // main bottom tab index
  Map defaultTabConfig = {'Chat': 0, 'Browser': 1, 'Last opened tab': -1};
  late CupertinoTabController cupertinoTabController;

  Future<void> setDefaultSelectedTab(int index) async {
    defaultSelectedTab.value = index;
    await Storage.setInt(StorageKeyString.defaultSelectedTabIndex, index);
  }

  Future<void> setSelectedTab(int index) async {
    if (index < 0) {
      index = 0;
    }
    selectedTabIndex = index;
    await Storage.setInt(StorageKeyString.selectedTabIndex, index);
  }

  // run when app start
  Future<void> loadSelectedTab() async {
    var res = Storage.getInt(StorageKeyString.defaultSelectedTabIndex);
    res ??= -1;
    defaultSelectedTab.value = res;
    if (res > -1) {
      selectedTabIndex = res;
      return;
    }
    // use the last opened tab
    final res2 = Storage.getInt(StorageKeyString.selectedTabIndex);
    if (res2 != null) {
      selectedTabIndex = res2;
      return;
    }
    if (GetPlatform.isMobile) {
      selectedTabIndex = KeychatGlobal.defaultOpenTabIndex;
    } else {
      // ecash tab only show on the desktop version
      selectedTabIndex = KeychatGlobal.defaultOpenTabIndex + 1;
    }
  }

  // add identity AI and add AI contacts
  Future<void> createAIIdentity(
    List<Identity> existsIdentity,
    String idName,
  ) async {
    final key = '${StorageKeyString.taskCreateIdentity}:$idName';
    if (existsIdentity.isEmpty) return;
    final res = Storage.getIntOrZero(key);
    if (res == 1) return;
    for (final identity in existsIdentity) {
      if (identity.name == idName) return;
    }
    final mnemonic = await SecureStorage.instance.getPhraseWords();
    if (mnemonic == null) return;
    final phraseIndexes =
        existsIdentity.map((element) => element.index).toList();
    final unusedIndex = List.generate(10, (index) => index).firstWhere(
      (index) => !phraseIndexes.contains(index),
      orElse: () => -1,
    );
    if (unusedIndex == -1) return;
    final secp256k1Accounts = await rust_nostr.importFromPhraseWith(
      phrase: mnemonic,
      offset: unusedIndex,
      count: 1,
    );

    await IdentityService.instance.createIdentity(
      name: idName,
      account: secp256k1Accounts[0],
      index: unusedIndex,
    );
    await Storage.setInt(key, 1);
    logger.i('CreateAIIdentity Success');
  }

  bool _pausedBefore = false;
  List<AppLifecycleState> statesForBlur = [];
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    loggerNoLine.i('didChangeAppLifecycleState: $state');
    // ios: 2 options
    // apprun-> inactive -> resumed
    // apprun-> inactive -> hidden-> paused ->hidden->inactive->resumed
    // macos:  apprun->inactive -> resumed
    statesForBlur.add(state);
    switch (state) {
      case AppLifecycleState.resumed:
        resumed = true;
        isBlurred.value = false;

        // if app running background > 10s
        var wasAppBackgroundedTooLong = false;
        if (pausedTime != null) {
          wasAppBackgroundedTooLong =
              DateTime.now().difference(pausedTime!).inSeconds > 10;
        }

        unawaited(removeBadge());

        // websocket status
        final shouldConnect =
            Get.find<WebsocketService>().relayConnectedCount.value == 0 ||
                GetPlatform.isDesktop ||
                wasAppBackgroundedTooLong;
        if (shouldConnect) {
          unawaited(Get.find<WebsocketService>().checkOnlineAndConnect());
        }

        // app status
        EasyThrottle.throttle(
            'AppLifecycleState.resumed', const Duration(seconds: 2), () {
          NostrAPI.instance.okCallback.clear();
          Utils.initLoggger(Utils.appFolder);
          NotifyService.syncPubkeysToServer(checkUpload: true);
          Get.find<MultiWebviewController>().checkCurrentControllerAlive();
        });

        // check biometrics
        if (_pausedBefore) {
          await biometricsAuth(auth: true);
        }
        _pausedBefore = false;
      case AppLifecycleState.inactive:
        if (GetPlatform.isMobile && statesForBlur.length >= 2) {
          if (statesForBlur[statesForBlur.length - 2] ==
              AppLifecycleState.resumed) {
            isBlurred.value = true;
          }
        }
        statesForBlur.clear();
      case AppLifecycleState.hidden:
        break;
      case AppLifecycleState.paused:
        resumed = false;
        _pausedBefore = true;
        pausedTime = DateTime.now();
      case AppLifecycleState.detached:
        // app been killed
        break;
    }
  }

  Future<void> biometricsAuth({required bool auth}) async {
    if (!(auth && GetPlatform.isMobile)) return;
    if (Get.currentRoute == '/BiometricAuthScreen') return;

    final isBiometricsEnable =
        await SecureStorage.instance.isBiometricsEnable();
    if (!isBiometricsEnable) return;

    final time = Get.find<SettingController>().biometricsAuthTime.value;
    if (time != 0 && pausedTime != null) {
      final isTimeToValid =
          DateTime.now().difference(pausedTime!).inSeconds > time * 60;

      if (!isTimeToValid) {
        loggerNoLine.d(
          'Paused: ${DateTime.now().difference(pausedTime!).inSeconds} seconds, skip now.',
        );
        return;
      }
    }

    await Get.to(
      () => const BiometricAuthScreen(autoAuth: true),
      fullscreenDialog: true,
      popGesture: false,
      transition: Transition.fadeIn,
    );
  }

  Future<void> loadAppRemoteConfig() async {
    const url =
        'https://raw.githubusercontent.com/keychat-io/bot-service-ai/refs/heads/main/config/app.json';
    // load app version
    final packageInfo = await PackageInfo.fromPlatform();
    remoteAppConfig['appVersion'] =
        '${packageInfo.version}+${packageInfo.buildNumber}';
    Map<String, dynamic> config = remote_config.data; // default config
    try {
      final response = await Dio().get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      if (response.statusCode == 200) {
        config = jsonDecode(response.data) as Map<String, dynamic>;
      } else {}
    } catch (e) {
      logger.e('Failed to get config: $url - ${(e as DioException).message}');
    }

    recommendBots.value = config['bots'] as List<dynamic>;

    final recommendUrls = config['browserRecommend'] as List;
    recommendWebstore.value = recommendUrls
        .fold<Map<String, List<Map<String, dynamic>>>>({}, (acc, item) {
      final categories = List<String>.from(item['categories']);
      for (final type in categories) {
        if (acc[type] == null) {
          acc[type] = [];
        }
        acc[type]!.add(item);
      }
      return acc;
    });

    // app version
    for (final key in config.keys) {
      if (key != 'bots' && key != 'browserRecommend') {
        remoteAppConfig[key] = config[key];
      }
    }
    return;
  }

  Identity getSelectedIdentity() {
    return chatIdentities.values.toList()[tabController.index];
  }

  void initTabController([int initialIndex = 0]) {
    tabController.dispose();
    if (initialIndex >= chatIdentities.length) {
      initialIndex = 0;
    }
    tabController = TabController(
      vsync: this,
      initialIndex: initialIndex,
      length: tabBodyDatas.length,
    );

    tabController.addListener(() {
      Storage.setInt(
        StorageKeyString.homeSelectedTabIndex,
        tabController.index,
      );
    });
  }

  Future<void> initTips(String name, RxBool toSetValue) async {
    final res = Storage.getIntOrZero(name);
    toSetValue.value = res == 0 ? true : false;
  }

  Future<List<Identity>> loadIdentity() async {
    final list = await IdentityService.instance.getIdentityList();
    chatIdentities.clear();
    allIdentities.clear();
    for (var i = 0; i < list.length; i++) {
      final id = list[i].id;
      allIdentities[id] = list[i];
      if (list[i].enableChat) {
        chatIdentities[id] = list[i];
      }
    }
    return chatIdentities.values.toList();
  }

  void loadIdentityRoomList(int identityId) {
    EasyDebounce.debounce(
        'loadIdentityRoomList:$identityId', const Duration(milliseconds: 200),
        () async {
      final res = await RoomService.instance.getRoomList(identityId);
      final rooms = res['friends'] ?? [];
      final approving = res['approving'] ?? [];
      final requesting = res['requesting'] ?? [];

      var unReadCount = 0;
      var anonymousUnReadCount = 0;
      var requestingUnReadCount = 0;
      for (final element in rooms) {
        if (element.isMute) continue;
        unReadCount += element.unReadCount;
      }
      for (final element in approving) {
        if (element.isMute) continue;
        anonymousUnReadCount += element.unReadCount;
      }
      for (final element in requesting) {
        requestingUnReadCount += element.unReadCount;
      }

      final datas = <dynamic>[
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
      final tabBodyData =
          tabBodyDatas[identityId] ?? TabData(chatIdentities[identityId]!)
            ..unReadCount = unReadCount
            ..anonymousUnReadCount = anonymousUnReadCount
            ..requestingUnReadCount = requestingUnReadCount
            ..rooms = datas;
      tabBodyDatas.value = Map.from(tabBodyDatas)..[identityId] = tabBodyData;

      var unReadSum = 0;
      final keys = tabBodyDatas.keys.toList();
      for (var i = 0; i < keys.length; i++) {
        final e = keys[i];
        final item = tabBodyDatas[e]!;
        unReadSum = unReadSum + item.unReadCount + item.anonymousUnReadCount;
      }
      await setUnreadCount(unReadSum);
    });
  }

  Future<List<Identity>> loadRoomList({bool init = false}) async {
    final mys = await loadIdentity();

    var firstUnreadIndex = -1;
    var unReadSum = 0;
    final thisTabBodyDatas = <int, TabData>{};
    for (var i = 0; i < mys.length; i++) {
      final id = mys[i].id;

      final res = await RoomService.instance.getRoomList(id);

      final rooms = res['friends'] ?? [];
      final approving = res['approving'] ?? [];
      final requesting = res['requesting'] ?? [];

      var unReadCount = 0;
      var anonymousUnReadCount = 0;
      var requestingUnReadCount = 0;
      for (final dynamic element in rooms) {
        if (element is Room) {
          if (element.isMute) continue;
          unReadCount += element.unReadCount;
        }
      }
      for (final element in approving) {
        if (element.isMute) continue;
        anonymousUnReadCount += element.unReadCount;
      }
      for (final element in requesting) {
        requestingUnReadCount += element.unReadCount;
      }

      unReadSum = unReadSum +
          unReadCount +
          anonymousUnReadCount +
          requestingUnReadCount;
      if (firstUnreadIndex == -1) {
        firstUnreadIndex = unReadCount > 0 ? i : -1;
      }

      final datas = [
        KeychatGlobal.search,
        KeychatGlobal.recommendRooms,
        approving,
        requesting,
        ...rooms,
      ];

      thisTabBodyDatas[id] = TabData(mys[i])
        ..unReadCount = unReadCount
        ..anonymousUnReadCount = anonymousUnReadCount
        ..rooms = datas;
    }

    tabBodyDatas.value = thisTabBodyDatas;
    setUnreadCount(unReadSum);

    var initialIndex = 0;
    if (firstUnreadIndex == -1) {
      final saved = Storage.getIntOrZero(StorageKeyString.homeSelectedTabIndex);
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
      Utils.getGetxController<WebsocketService>()?.checkOnlineAndConnect();
    } else {
      // network from disconnected to connected
      if (!isConnectedNetwork.value) {
        Utils.getGetxController<WebsocketService>()?.start();
      }
      isConnectedNetwork.value = true;
    }
  }

  @override
  Future<void> onClose() async {
    tabController.dispose();
    _intentSub.cancel();
    WidgetsBinding.instance.removeObserver(this);
    subscription.cancel();
    _connectionCheckTimer.cancel();
    Get.find<WebsocketService>().stopListening();
    if (Get.context != null) {
      Utils.hideKeyboard(Get.context!);
    }
    super.onClose();
  }

  @override
  Future<void> onInit() async {
    tabController = TabController(vsync: this, length: 0);
    await loadSelectedTab();
    cupertinoTabController =
        CupertinoTabController(initialIndex: selectedTabIndex);
    cupertinoTabController.addListener(() {
      setSelectedTab(cupertinoTabController.index);
    });
    super.onInit();

    final mys = await loadRoomList(init: true);
    isAppBadgeSupported =
        GetPlatform.isAndroid || GetPlatform.isIOS || GetPlatform.isMacOS;
    // Ecash Init
    if (mys.isNotEmpty) {
      Get.find<EcashController>().initIdentity(mys[0]);

      // init notify service when identity exists
      Future.delayed(const Duration(seconds: 3)).then((_) {
        NotifyService.init().catchError((e, s) {
          logger.e('initNotifycation error', error: e, stackTrace: s);
        });
      });
    }
    FlutterNativeSplash.remove(); // close splash page
    WidgetsBinding.instance.addObserver(this);

    // show dot on add friends menu
    initTips(StorageKeyString.tipsAddFriends, addFriendTips);

    // listen network status https://pub.dev/packages/connectivity_plus
    subscription =
        Connectivity().onConnectivityChanged.listen(networkListenHandle);

    // Start periodic connection check timer (every minute)
    if (GetPlatform.isDesktop) {
      _connectionCheckTimer =
          Timer.periodic(const Duration(minutes: 1), (timer) {
        if (isConnectedNetwork.value) {
          Get.find<WebsocketService>().checkOnlineAndConnect();
        }
      });
    }

    removeBadge();

    // start to create ai identity
    Future.delayed(const Duration(seconds: 1), () async {
      initAppLinks();
      _initShareIntent();
      RoomUtil.executeAutoDelete();
      loadAppRemoteConfig();
      // List<Room> rooms = await RoomService.instance.getMlsRooms();
      // MlsGroupService.instance.fixMlsOnetimeKey(rooms);
    });
  }

  List<Room> getRoomsByIdentity(int identityId) {
    final list =
        Get.find<HomeController>().tabBodyDatas[identityId]?.rooms ?? [];
    if (list.isEmpty) return [];

    final rooms = <Room>[];
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

  Future<void> setTipsViewed(String name, RxBool toSetValue) async {
    toSetValue.value = false;
    await Storage.setInt(name, 1);
  }

  Future<void> setUnreadCount(int count) async {
    if (count == allUnReadCount.value) return;
    allUnReadCount.value = count;
    if (!isAppBadgeSupported) return;
    if (count == 0) return FlutterNewBadger.removeBadge();
    FlutterNewBadger.setBadge(count);
  }

  void addUnreadCount() {
    allUnReadCount.value++;
    if (!isAppBadgeSupported) return;
    FlutterNewBadger.setBadge(allUnReadCount.value);
  }

  void troggleDebugModel() {
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

  Future<void> updateIdentityName(Identity identity, String name) async {
    identity.name = name;
    await IdentityService.instance.updateIdentity(identity);
    final item = tabBodyDatas[identity.id];
    if (item == null) return;
    item.identity = identity;
    tabBodyDatas[identity.id] = item;
    tabBodyDatas.value = Map.from(tabBodyDatas);
    if (Get.context != null) {
      Utils.hideKeyboard(Get.context!);
    }
  }

  void resortRoomList(int identityId) {
    final item = tabBodyDatas[identityId];
    if (item == null) return;
    final friendsRooms =
        List.castFrom<dynamic, Room>(item.rooms.whereType<Room>().toList());
    final nonRoomItems =
        item.rooms.where((element) => element is! Room).toList();
    item.rooms = [...nonRoomItems, ...RoomUtil.sortRoomList(friendsRooms)];
    tabBodyDatas[identityId] = item;
  }

  Room? getRoomByIdentity(int identityId, int roomId) {
    final list = getRoomsByIdentity(identityId);
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == roomId) {
        return list[i];
      }
    }
    return null;
  }

  Future<void> initAppLinks() async {
    final appLinks = AppLinks();
    // await for app inited
    Future.delayed(const Duration(seconds: 2)).then((value) async {
      try {
        final uri = await appLinks.getInitialLink();
        if (uri != null) {
          handleAppLink(uri);
        }
      } catch (e) {
        logger.e('Failed to get initial link: $e');
      }
    });

    appLinks.uriLinkStream.listen(
      handleAppLink,
      onError: (err) {
        logger.e('listen failed: $err');
      },
    );
  }

  Future<void> handleAppLink(Uri? uri) async {
    if (uri == null) return;
    if (uri.pathSegments.isEmpty) return;
    final List identities = await IdentityService.instance.getIdentityList();
    if (identities.isEmpty) {
      EasyLoading.showError('No identity found, please login first');
      return;
    }

    final Map params = uri.queryParametersAll;
    logger
        .i('App received new link: $uri  path: ${uri.path} , params: $params');
    final scheme = uri.scheme;
    switch (scheme) {
      case 'http':
      case 'https':
        // https://www.keychat.io/u/?k=npub10v2vdw8rulxj4s4h6ugh4ru7qlzqr7z2u8px5s4zlh2lsghs6lysyf69mf
        if (uri.queryParameters.containsKey('k')) {
          final input = Uri.decodeComponent(uri.queryParameters['k']!);
          return _handleAppLinkRoom(input, params);
        }
      case 'keychat':
        // keychat://www.keychat.io/u/?k=npub10v2vdw8rulxj4s4h6ugh4ru7qlzqr7z2u8px5s4zlh2lsghs6lysyf69mf
        if (uri.queryParameters.containsKey('k')) {
          final input = Uri.decodeComponent(uri.queryParameters['k']!);
          return _handleAppLinkRoom(input, params);
        }
        // keychat://npub10v2vdw8rulxj4s4h6ugh4ru7qlzqr7z2u8px5s4zlh2lsghs6lysyf69mf
        final input = _getDeeplinkData(uri);
        _handleAppLinkRoom(input, params);
      case 'nostr':
        // nostr:npub10v2vdw8rulxj4s4h6ugh4ru7qlzqr7z2u8px5s4zlh2lsghs6lysyf69mf
        final input = _getDeeplinkData(uri);
        _handleAppLinkRoom(input, params);
      case 'lightning':
      case 'lnurlp':
        final input = _getDeeplinkData(uri);
        _handleAppLinkLightning(input);
      case 'cashu':
        final input = _getDeeplinkData(uri);
        Get.find<EcashController>().proccessCashuString(input);
      case 'bitcoin':
        QrScanService.instance
            .handleBitcoinUri(uri.toString(), Get.find<EcashController>());

      default:
    }
  }

  String _getDeeplinkData(Uri uri) {
    final scheme = uri.scheme;
    final input = uri.toString().replaceFirst('$scheme:', '');
    return input.replaceFirst('$scheme://', '');
  }

  Future<void> _handleAppLinkRoom(String input, Map params) async {
    loggerNoLine.i('handleAppLinkRoom: $input, params: $params');

    final List identities = await IdentityService.instance.getIdentityList();
    if (identities.isEmpty) {
      EasyLoading.showError('No identity found, please login first');
      return;
    }

    // qr chatkey
    if (!(input.length == 64 || input.length == 63)) {
      await Get.bottomSheet(
        AddtoContactsPage(input),
        isScrollControlled: true,
        ignoreSafeArea: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      );
      return;
    }
    try {
      // bech32 or hex pubkey
      var hexPubkey = input;
      if (input.startsWith('npub') && input.length == 63) {
        hexPubkey = rust_nostr.getHexPubkeyByBech32(bech32: input);
      }
      final rooms = await RoomService.instance.getCommonRoomByPubkey(hexPubkey);
      if (rooms.isEmpty) {
        await Get.bottomSheet(
          AddtoContactsPage(input),
          isScrollControlled: true,
          ignoreSafeArea: false,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
        );
        return;
      }
      // Handle the found rooms
      if (rooms.length == 1) {
        return Utils.toNamedRoom(rooms[0]);
      }
      // dialog to select room
      await Get.dialog(
        SimpleDialog(
          title: const Text('Multi Rooms Found'),
          children: rooms.map((room) {
            return ListTile(
              title: Text(room.getRoomName()),
              subtitle: Text(allIdentities[room.identityId]?.name ?? ''),
              onTap: () {
                Get.back<void>();
                Utils.toNamedRoom(room);
              },
            );
          }).toList(),
        ),
      );
    } catch (e, s) {
      EasyLoading.showError('Failed to handle app link: $e');
      logger.e('handleAppLinkRoom error: $e', stackTrace: s);
    }
  }

  Future<void> _handleAppLinkLightning(String input) async {
    if (isEmail(input) || input.toUpperCase().startsWith('LNURL')) {
      await Get.bottomSheet(
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        ),
        PayInvoicePage(invoce: input, showScanButton: false),
      );
      return;
    }
    await Get.find<EcashController>()
        .proccessPayLightningBill(input, isPay: true);
  }

  late StreamSubscription _intentSub;

  void _initShareIntent() {
    if (!GetPlatform.isMobile) return;
    // Listen to media sharing coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedContent,
      onError: (err) {
        logger.e('getIntentDataStream error: $err');
      },
    );

    // Get the media sharing coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      _handleSharedContent(value);
      ReceiveSharingIntent.instance.reset();
    });
    logger.i('ShareIntent initialized');
  }

  Future<void> _handleSharedContent(List<SharedMediaFile> list) async {
    if (list.isEmpty) return;
    logger.i('Shared content received: ${list.map((f) => f.toMap())}');
    final file = list.first;
    if (file.path.startsWith('keychat://www.keychat.io/u/')) {
      logger.i('Shared content is a room link, handle by deeplink');
      return;
    }
    final identity = getSelectedIdentity();
    switch (file.type) {
      case SharedMediaType.image:
      case SharedMediaType.file:
      case SharedMediaType.video:
        var forwardRooms = await Get.to<List<Room>>(
          () => ForwardSelectRoom('', identity, showContent: false),
          fullscreenDialog: true,
          transition: Transition.downToUp,
        );
        if (forwardRooms == null || forwardRooms.isEmpty) return;
        final message = await FileService.instance
            .handleFileUpload(forwardRooms.first, XFile(file.path));
        if (forwardRooms.length > 1 && message != null) {
          forwardRooms = forwardRooms.skip(1).toList();
          await RoomUtil.forwardMediaMessageToRooms(forwardRooms, message);
        }
      case SharedMediaType.text:
      case SharedMediaType.url:
        var toSendText = file.path;
        if (file.message != null) {
          toSendText = '''
${file.path}
${file.message}
''';
        }
        await RoomUtil.forwardTextMessage(identity, toSendText);
    }
  }
}

class TabData {
  TabData(this.identity);
  int unReadCount = 0;
  int anonymousUnReadCount = 0;
  int requestingUnReadCount = 0;
  List<dynamic> rooms = [];
  late Identity identity;
}
