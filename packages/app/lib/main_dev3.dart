import 'dart:io' show Directory;

import 'package:app/service/chatx.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/index.dart';
import 'controller/home.controller.dart';
import 'controller/setting.controller.dart';
import 'models/db_provider.dart';
import 'page/browser/Browser_controller.dart';
import 'page/app_theme.dart';
import 'page/pages.dart';
import 'service/identity.service.dart';
import 'utils/config.dart' as env_config;
import 'firebase_options.dart';

bool isProdEnv = true;

void main() async {
  SettingController sc = await initServices();

  bool isLogin = await IdentityService.instance.count() > 0;
  ThemeMode themeMode = await getThemeMode();
  sc.themeMode.value = themeMode.name;

  initEasyLoading();
  Get.config(
      enableLog: true,
      logWriterCallback: _logWriterCallback,
      defaultPopGesture: true,
      defaultTransition: Transition.cupertino);
  String initialRoute = await getInitRoute(isLogin);
  var getMaterialApp = GetMaterialApp(
    initialRoute: initialRoute,
    getPages: Pages.routes,
    builder: EasyLoading.init(),
    locale: Get.deviceLocale,
    debugShowCheckedModeBanner: false,
    themeMode: themeMode,
    theme: AppThemeCustom.light(),
    darkTheme: AppThemeCustom.dark(),
  );
  if (!kDebugMode) {
    try {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
    } catch (e, s) {
      logger.e(e.toString(), stackTrace: s);
    }
  }
  // fix https://github.com/flutter/flutter/issues/119465
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  runApp(getMaterialApp);
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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  if (dotenv.get('FCMapiKey', fallback: '') != '') {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
          name: GetPlatform.isAndroid ? 'keychat-bg' : null,
          options: DefaultFirebaseOptions.currentPlatform);
    }
    debugPrint("Handling a background message: ${message.messageId}");
  }
}

Future<SettingController> initServices() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  await dotenv.load(fileName: ".env");
  if (dotenv.get('FCMapiKey', fallback: '') != '') {
    Firebase.initializeApp(
            name: GetPlatform.isAndroid ? 'keychat' : null,
            options: DefaultFirebaseOptions.currentPlatform)
        .then((_) {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      logger.i('Firebase initialized');
    });
  }

  await RustLib.init();
  String env =
      'dev3'; //const String.fromEnvironment("MYENV", defaultValue: "prod");
  env_config.Config.instance.init(env);
  isProdEnv = env_config.Config.isProd();

  Directory appFolder = await Utils.getAppFolder();
  // init log file
  await Utils.initLoggger(appFolder);
  String dbPath = '${appFolder.path}/$env/database/';
  Directory dbDirectory = Directory(dbPath);
  dbDirectory.createSync(recursive: true);
  logger.i('APP Folder: $dbPath');
  await DBProvider.initDB(dbPath);
  SettingController sc = Get.put(SettingController(), permanent: true);
  Get.put(EcashController(dbPath), permanent: true);
  Get.put(BrowserController(), permanent: true);
  Get.putAsync(() => ChatxService().init(dbPath));
  Get.putAsync(() => WebsocketService().init());
  Get.put(HomeController(), permanent: true);
  return sc;
}

void _logWriterCallback(String text, {bool isError = false}) {
  isError ? debugPrint(text) : loggerNoLine.i(text);
}
