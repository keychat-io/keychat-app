import 'package:app/controller/setting.controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class BiometricAuthScreen extends StatefulWidget {
  final bool autoAuth;
  final bool canPop;
  final String title;
  const BiometricAuthScreen(
      {this.autoAuth = false,
      super.key,
      this.canPop = false,
      this.title = 'Unlock Keychat'});

  @override
  _BiometricAuthScreenState createState() => _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends State<BiometricAuthScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoAuth) auth();
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
      Get.back(result: true);
    }
    if (Get.isDialogOpen ?? false) {
      Get.back(result: true);
    }
    Get.back(result: true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: widget.canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (widget.canPop) {
            Get.back(result: false);
          }
        },
        child: Scaffold(
          body: Center(
              child: FilledButton(onPressed: auth, child: Text(widget.title))),
        ));
  }
}
