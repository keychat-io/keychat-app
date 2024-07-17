import 'dart:io';

import 'package:app/service/chatx.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'controller/home.controller.dart';
import 'controller/setting.controller.dart';
import 'models/db_provider.dart';
import 'page/app_theme.dart';
import 'page/pages.dart';
import 'service/identity.service.dart';
import 'utils/config.dart' as env_config;

bool isProdEnv = true;

void main() async {
  SettingController sc = await initServices();
  Get.put(HomeController(), permanent: true);

  bool isLogin = await IdentityService().count() > 0;
  ThemeMode themeMode = await getThemeMode();
  sc.themeMode.value = themeMode.name;

  initEasyLoading();
  Get.config(
      enableLog: kDebugMode,
      defaultPopGesture: true,
      defaultTransition: Transition.cupertino);
  String initialRoute = await getInitRoute(isLogin);
  runApp(GetMaterialApp(
    enableLog: kDebugMode,
    initialRoute: initialRoute,
    getPages: Pages.routes,
    builder: EasyLoading.init(),
    locale: Get.deviceLocale,
    debugShowCheckedModeBanner: false,
    themeMode: themeMode,
    theme: AppThemeCustom.light(),
    darkTheme: AppThemeCustom.dark(),
  ));
}

Future<String> getInitRoute(bool isLogin) async {
  return isLogin ? '/' : '/login';
  // int onboarding = await Storage.getIntOrZero(StorageKeyString.onboarding);
  // // if (!isLogin && onboarding == 0) {
  // if (onboarding == 0) {
  //   initialRoute = '/onboarding';
  // }
  // return initialRoute;
}

void initEasyLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..backgroundColor = Get.isDarkMode ? Colors.black87 : Colors.grey
    ..textColor = Get.isDarkMode ? Colors.white70 : Colors.black87
    ..indicatorType = EasyLoadingIndicatorType.cubeGrid
    ..loadingStyle =
        Get.isDarkMode ? EasyLoadingStyle.dark : EasyLoadingStyle.light
    ..fontSize = 16;
}

Future initServices() async {
  FlutterNativeSplash.preserve(
      widgetsBinding: WidgetsFlutterBinding.ensureInitialized());
  await SystemChrome.setPreferredOrientations(
    [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
  );
  await dotenv.load(fileName: ".env");
  String env =
      'dev1'; //const String.fromEnvironment("MYENV", defaultValue: "prod");
  env_config.Config().init(env);
  isProdEnv = env_config.Config.isProd();

  var appFolder = await getApplicationDocumentsDirectory();
  // init log file
  await Utils.initLoggger(appFolder);
  String dbPath = '${appFolder.path}/$env/database/';
  Directory dbDirectory = Directory(dbPath);
  dbDirectory.createSync(recursive: true);
  logger.i('APP Folder: $dbPath');

  await DBProvider.initDB(dbPath);
  SettingController sc = Get.put(SettingController(), permanent: true);
  // RustAPI.initEcashDB(dbPath);
  Get.put(EcashController(dbPath), permanent: true);
  Get.putAsync(() => ChatxService().init(dbPath), permanent: true);
  Get.putAsync(() => WebsocketService().init(), permanent: true);

  return sc;
}
