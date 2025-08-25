import 'package:app/controller/setting.controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class BiometricAuthScreen extends StatefulWidget {
  const BiometricAuthScreen({super.key});

  @override
  _BiometricAuthScreenState createState() => _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends State<BiometricAuthScreen> {
  @override
  void initState() {
    super.initState();
    // auth();
  }

  Future auth() async {
    bool result = await Get.find<SettingController>().authenticate();
    if (!result) {
      EasyLoading.showError('Authentication failed or cancelled');
      return;
    }
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }
    if (Get.isBottomSheetOpen ?? false) {
      Get.back();
    }
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        child: Scaffold(
          body: Center(
            child: FilledButton(
                onPressed: () {
                  auth();
                },
                child: const Text('Unlock Keychat')),
          ),
        ));
  }
}
