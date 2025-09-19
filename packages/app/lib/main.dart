import 'dart:io' show Directory;

import 'package:app/desktop/DesktopController.dart';
import 'package:app/global.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/page/routes.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:app/utils/MyCustomScrollBehavior.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/index.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/controller/setting.controller.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/page/app_theme.dart';
import 'package:app/page/pages.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/utils/config.dart' as env_config;

bool isProdEnv = true;

void main() async {
  final stopwatch = Stopwatch()..start();
  final sc = await initServices();

  final isLogin = await IdentityService.instance.count() > 0;
  final themeMode = await getThemeMode();
  sc.themeMode.value = themeMode.name;

  initEasyLoading();
  Get.config(
      enableLog: kDebugMode,
      logWriterCallback: _logWriterCallback,
      defaultPopGesture: true,
      defaultTransition:
          GetPlatform.isDesktop ? Transition.fadeIn : Transition.cupertino);
  final initialRoute = await getInitRoute(isLogin);
  final getMaterialApp = GetMaterialApp(
      initialRoute: initialRoute,
      getPages: Pages.routes,
      builder: EasyLoading.init(),
      locale: Get.deviceLocale,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppThemeCustom.light(),
      darkTheme: AppThemeCustom.dark(),
      scrollBehavior: MyCustomScrollBehavior());

  runApp(getMaterialApp);
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await WidgetsBinding.instance.endOfFrame;
    stopwatch.stop();
    logger.i('app launched: ${stopwatch.elapsedMilliseconds} ms');

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: true,
    ));
  });
}

Future<String> getInitRoute(bool isLogin) async {
  return isLogin ? Routes.root : Routes.login;
  // int onboarding = await Storage.getIntOrZero(StorageKeyString.onboarding);
  // // if (!isLogin && onboarding == 0) {
  // if (onboarding == 0) {
  //   initialRoute = '/onboarding';
  // }
  // return initialRoute;
}

void initEasyLoading() {
  EasyLoading.instance
    ..indicatorType = EasyLoadingIndicatorType.cubeGrid
    ..progressColor = KeychatGlobal.secondaryColor
    ..indicatorColor = KeychatGlobal.secondaryColor
    ..fontSize = 16;
}

Future<SettingController> initServices() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  final appFolder = await Utils.getAppFolder();
  await dotenv.load();
  await Storage.init();
  await RustLib.init();
  const env = String.fromEnvironment('MYENV', defaultValue: 'prod');
  env_config.Config.instance.init(env);
  isProdEnv = env_config.Config.isProd();

  // init log file
  await Utils.initLoggger(appFolder);
  final dbPath = '${appFolder.path}/$env/database/';
  Directory(dbPath).createSync(recursive: true);

  logger.i('App Folder: $dbPath');
  await DBProvider.initDB(dbPath);
  final sc = Get.put(SettingController(), permanent: true);
  Get.put(EcashController(dbPath), permanent: true);
  Get.put(MultiWebviewController(), permanent: true);
  Get.putAsync(() => ChatxService().init(dbPath));
  await Get.putAsync(() => WebsocketService().init());
  Get.put(HomeController(), permanent: true);
  Get.lazyPut(DesktopController.new, fenix: true);
  return sc;
}

void _logWriterCallback(String text, {bool isError = false}) {
  isError ? debugPrint(text) : loggerNoLine.i(text);
}
