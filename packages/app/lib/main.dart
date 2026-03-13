import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/controller/setting.controller.dart';
import 'package:keychat/desktop/DesktopController.dart';
import 'package:keychat/global.dart';
import 'package:keychat/models/db_provider.dart';
import 'package:keychat/page/app_theme.dart';
import 'package:keychat/page/browser/MultiWebviewController.dart';
import 'package:keychat/page/pages.dart';
import 'package:keychat/page/routes.dart';
import 'package:keychat/page/startup_error_page.dart';
import 'package:keychat/service/chatx.service.dart';
import 'package:keychat/service/identity.service.dart';
import 'package:keychat/service/storage.dart';
import 'package:keychat/service/unifiedpush.service.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat/utils.dart';
import 'package:keychat/utils/MyCustomScrollBehavior.dart';
import 'package:keychat/utils/config.dart' as env_config;
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/unified_wallet/unified_wallet_controller.dart';
import 'package:keychat_rust_ffi_plugin/index.dart';

bool isProdEnv = true;

/// Store command line arguments for UnifiedPush Linux background support
List<String> appLaunchArgs = [];

void main(List<String> args) async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Store args for UnifiedPush Linux support
  appLaunchArgs = args;
  // Initialize UnifiedPush in background mode
  // Don't run the full app UI in background mode
  if (args.contains('--unifiedpush-bg')) {
    logger.i('Starting in UnifiedPush background mode');
    await Storage.init();
    await UnifiedPushService.instance.init(args: args);
    return;
  }

  // Set edge-to-edge mode early
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  try {
    await _startApp(widgetsBinding);
  } catch (e, s) {
    // Remove splash screen so user can see the error page
    FlutterNativeSplash.remove();
    _runErrorApp(e, s, widgetsBinding);
  }
}

/// Normal app startup flow
Future<void> _startApp(WidgetsBinding widgetsBinding) async {
  final stopwatch = Stopwatch()..start();
  final sc = await initServices(widgetsBinding);

  final isLogin = await IdentityService.instance.count() > 0;
  final themeMode = await getThemeMode();
  sc.themeMode.value = themeMode.name;

  initEasyLoading();
  Get.config(
    enableLog: kDebugMode,
    logWriterCallback: _logWriterCallback,
    defaultPopGesture: true,
    defaultTransition: GetPlatform.isMobile
        ? Transition.cupertino
        : Transition.fade,
  );
  final initialRoute = await getInitRoute(isLogin: isLogin);
  final getMaterialApp = GetMaterialApp(
    initialRoute: initialRoute,
    getPages: Pages.routes,
    builder: EasyLoading.init(),
    locale: Get.deviceLocale,
    debugShowCheckedModeBanner: false,
    themeMode: themeMode,
    theme: AppThemeCustom.light(),
    darkTheme: AppThemeCustom.dark(),
    scrollBehavior: MyCustomScrollBehavior(),
  );

  runApp(getMaterialApp);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    stopwatch.stop();
    logger.i('app launched: ${stopwatch.elapsedMilliseconds} ms');
    // Set system UI overlay once after app launch
    _updateSystemUIOverlay();
  });

  // Listen for theme mode changes and update system UI accordingly
  ever(sc.themeMode, (_) {
    _updateSystemUIOverlay();
  });
}

/// Show error page when startup fails
void _runErrorApp(
  Object error,
  StackTrace stackTrace,
  WidgetsBinding widgetsBinding,
) {
  runApp(
    StartupErrorPage(
      error: error,
      stackTrace: stackTrace,
      onRetry: () async {
        // Reset GetX state for a clean retry
        Get.reset();
        try {
          await _startApp(widgetsBinding);
        } catch (e, s) {
          logger.e('_startApp failed', error: e, stackTrace: s);
          _runErrorApp(e, s, widgetsBinding);
        }
      },
    ),
  );
}

Future<String> getInitRoute({required bool isLogin}) async {
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

Future<SettingController> initServices(WidgetsBinding widgetsBinding) async {
  final sw = Stopwatch()..start();
  void logStep(String step) {
    logger.i('[init] $step +${sw.elapsedMilliseconds}ms');
  }

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );
  const env = String.fromEnvironment('MYENV', defaultValue: 'prod');
  env_config.Config.instance.init(env);
  isProdEnv = env_config.Config.isProd();
  logStep('config done');

  final appFolder = await Utils.initAppFolder(env);
  final dbPath = Utils.dbPath;
  logStep('appFolder done');

  await dotenv.load(isOptional: true);
  logStep('dotenv done');

  await Storage.init();
  logStep('storage done');

  await RustLib.init();
  logStep('rustLib done');

  // init log file
  await Utils.initLoggger(appFolder);
  logStep('logger done');

  logger.i('App Folder: $dbPath');
  await DBProvider.initDB(dbPath);
  logStep('db done');

  final sc = Get.put(SettingController(), permanent: true);
  logStep('settingController done');

  Get
    ..put(EcashController(dbPath), permanent: true)
    ..put(MultiWebviewController(), permanent: true)
    ..putAsync(() => ChatxService().init(dbPath), permanent: true)
    ..put(HomeController(), permanent: true)
    ..lazyPut(WebsocketService.new, fenix: true)
    ..lazyPut(UnifiedWalletController.new, fenix: true)
    ..lazyPut(DesktopController.new, fenix: true);
  logStep('all services registered');
  return sc;
}

void _updateSystemUIOverlay() {
  /// Update system UI overlay style to match current theme
  /// Determines brightness based on current theme mode and system settings
  final sc = Get.find<SettingController>();
  final themeMode = sc.themeMode.value;

  // Determine if dark mode should be used
  bool isDarkMode;
  if (themeMode == 'dark') {
    isDarkMode = true;
  } else if (themeMode == 'light') {
    isDarkMode = false;
  } else {
    // 'system' mode - check platform brightness
    isDarkMode =
        PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  }

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDarkMode
          ? Brightness.light
          : Brightness.dark,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: true,
    ),
  );
}

void _logWriterCallback(String text, {bool isError = false}) {
  isError ? debugPrint(text) : loggerNoLine.i(text);
}
