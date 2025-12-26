import 'package:flutter/foundation.dart'
    show FlutterError, FlutterErrorDetails, PlatformDispatcher;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/page/setting/BiometricAuthScreen.dart';
import 'package:keychat/service/secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SettingController extends GetxController with StateMixin<Type> {
  RxString displayName = ''.obs;

  RxBool viewKeychatFutures = false.obs;
  RxInt autoCleanMessageDays = 0.obs;
  RxString themeMode = 'system'.obs;
  RxString selectedMediaServer = KeychatGlobal.defaultFileServer.obs;
  RxBool biometricsEnabled = false.obs; // Biometric authentication enabled
  final LocalAuthentication auth = LocalAuthentication();

  RxList<String> mediaServers = [
    KeychatGlobal.defaultFileServer,
    'https://void.cat',
    'https://nostr.download',
  ].obs;

  RxInt biometricsAuthTime = RxInt(0);

  @override
  Future<void> onInit() async {
    await loadBiometricsStatus();
    // viewKeychatFutures.value = await getViewKeychatFutures();
    autoCleanMessageDays.value = Storage.getIntOrZero(
      StorageKeyString.autoDeleteMessageDays,
    );

    // Catch uncaught Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);

      final error = StringBuffer()
        ..writeln('Time: ${DateTime.now()}')
        ..writeln('Error: ${details.exceptionAsString()}')
        ..writeln('Stack Trace: ${details.stack}')
        ..writeln('Library: ${details.library}')
        ..writeln('Context: ${details.context}');

      Utils.logErrorToFile(error.toString());
    };

    // Catch errors not handled by Flutter
    PlatformDispatcher.instance.onError = (error, stack) {
      final errorDetails = StringBuffer()
        ..writeln('Time: ${DateTime.now()}')
        ..writeln('Error: $error')
        ..writeln('Stack Trace: $stack');

      Utils.logErrorToFile(errorDetails.toString());
      return true;
    };
    super.onInit();
    initMediaServer();
  }

  Future<void> loadBiometricsStatus() async {
    final status = await SecureStorage.instance.isBiometricsEnable();
    biometricsEnabled.value = status;

    biometricsAuthTime.value = Storage.getIntOrZero(
      StorageKeyString.biometricsAuthTime,
    );
  }

  Future<void> setBiometricsStatus(bool status) async {
    final canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
    final canAuthenticate =
        canAuthenticateWithBiometrics || await auth.isDeviceSupported();
    logger.d(
      'canAuthenticate: $canAuthenticate canAuthenticateWithBiometrics: $canAuthenticateWithBiometrics',
    );
    if (!canAuthenticate) {
      EasyLoading.showError('Biometrics not available');
      return;
    }

    try {
      final didAuthenticate = await auth.authenticate(
        localizedReason: 'Authenticate',
      );
      loggerNoLine.i('User authenticated: $didAuthenticate');
      if (!didAuthenticate) {
        EasyLoading.showError('Authentication failed');
        return;
      }
      await SecureStorage.instance.setBiometrics(status);
      biometricsEnabled.value = status;
    } on LocalAuthException catch (e) {
      late String message;
      if (e.code == LocalAuthExceptionCode.noBiometricHardware) {
        message = 'Biometrics are not available.';
      } else if (e.code == LocalAuthExceptionCode.noBiometricsEnrolled) {
        message = 'No biometrics are enrolled.';
      } else {
        message = 'Authentication failed: $e';
      }
      EasyLoading.showError(message);
    }
  }

  Future<bool> authenticate() async {
    final canAuthenticate = await canBiometricAuth();
    if (!canAuthenticate) {
      EasyLoading.showError('Biometrics not available');
      return false;
    }

    try {
      final result = await auth.authenticate(
        localizedReason: 'Authenticate',
      );
      return result;
    } catch (e) {
      EasyLoading.showError('Auth Failed: $e');
      logger.e('Authentication error: $e');
      return false;
    }
  }

  Future<bool> canBiometricAuth() async {
    final canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
    final canAuthenticate =
        canAuthenticateWithBiometrics || await auth.isDeviceSupported();
    return canAuthenticate;
  }

  Future<void> biometricAuthThen(Function anyFunction) async {
    final result = await canBiometricAuth();
    if (result) {
      final authed = await Get.to<bool>(
        () => const BiometricAuthScreen(
          canPop: true,
          title: 'Authenticate to continue',
        ),
        fullscreenDialog: true,
        popGesture: true,
        transition: Transition.fadeIn,
      );
      if (authed == null || !authed) {
        return;
      }
    } else {
      if (biometricsEnabled.value) {
        EasyLoading.showError('Biometrics enabled but not available');
        return;
      }
    }
    await anyFunction();
  }

  Future<bool> getViewKeychatFutures() async {
    final res = Storage.getIntOrZero(StorageKeyString.getViewKeychatFutures);
    return res == 1;
  }

  Future<void> setViewKeychatFutures() async {
    await Storage.setInt(StorageKeyString.getViewKeychatFutures, 1);
    viewKeychatFutures.value = true;
  }

  Future<void> initMediaServer() async {
    final res = Storage.getString(StorageKeyString.selectedMediaServer);
    if (res != null) {
      selectedMediaServer.value = res;
    }

    final servers = Storage.getStringList(StorageKeyString.mediaServers);
    if (servers.isNotEmpty) {
      mediaServers.value = servers;
    }
  }

  Future<void> setSelectedMediaServer(String server) async {
    selectedMediaServer.value = server;
    await Storage.setString(StorageKeyString.selectedMediaServer, server);
  }

  Future<void> setMediaServers(List<String> servers) async {
    mediaServers.value = servers;
    await Storage.setStringList(StorageKeyString.mediaServers, servers);
  }

  Future<void> removeMediaServer(String url) async {
    mediaServers.remove(url);
    if (url == selectedMediaServer.value) {
      selectedMediaServer.value = mediaServers.isNotEmpty
          ? mediaServers.first
          : KeychatGlobal.defaultFileServer;
    }
    await Storage.setStringList(
      StorageKeyString.mediaServers,
      List.from(mediaServers),
    );
  }

  Future<void> setBiometricsAuthTime(int minutes) async {
    biometricsAuthTime.value = minutes;
    await Storage.setInt(StorageKeyString.biometricsAuthTime, minutes);
  }
}
