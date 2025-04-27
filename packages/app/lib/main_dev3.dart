import 'dart:io' show Directory;

import 'package:app/desktop/DesktopController.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/page/routes.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:app/utils/MyCustomScrollBehavior.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'page/app_theme.dart';
import 'page/pages.dart';
import 'service/identity.service.dart';
import 'utils/config.dart' as env_config;
import 'firebase_options.dart';

bool isProdEnv = true;

void main() async {
  final Stopwatch stopwatch = Stopwatch()..start();
  SettingController sc = await initServices();

  bool isLogin = await IdentityService.instance.count() > 0;
  ThemeMode themeMode = await getThemeMode();
  sc.themeMode.value = themeMode.name;

  initEasyLoading();
  Get.config(
      enableLog: kDebugMode,
      logWriterCallback: _logWriterCallback,
      defaultPopGesture: true,
      defaultTransition:
          GetPlatform.isDesktop ? Transition.fadeIn : Transition.cupertino);
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
      scrollBehavior: MyCustomScrollBehavior());

  // fix https://github.com/flutter/flutter/issues/119465
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  runApp(getMaterialApp);
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await WidgetsBinding.instance.endOfFrame;
    stopwatch.stop();
    logger.i("app launched: ${stopwatch.elapsedMilliseconds} ms");
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
      var app = await Firebase.initializeApp(
          name: GetPlatform.isAndroid ? 'keychat-bg' : null,
          options: DefaultFirebaseOptions.currentPlatform);
      logger.d('Firebase initialized in background: ${app.name}');
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
    await Firebase.initializeApp(
            name: GetPlatform.isAndroid ? 'keychat' : null,
            options: DefaultFirebaseOptions.currentPlatform)
        .then((_) {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      logger.i('Firebase initialized in main');
    }, onError: (error) {
      logger.e('Firebase initialize failed: $error');
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
  Get.put(MultiWebviewController(), permanent: true);
  Get.putAsync(() => ChatxService().init(dbPath));
  Get.putAsync(() => WebsocketService().init());
  Get.put(HomeController(), permanent: true);
  Get.lazyPut(() => DesktopController(), fenix: true);
  return sc;
}

void _logWriterCallback(String text, {bool isError = false}) {
  isError ? debugPrint(text) : loggerNoLine.i(text);
}
