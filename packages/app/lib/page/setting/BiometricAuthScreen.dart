import 'package:keychat/controller/setting.controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class BiometricAuthScreen extends StatefulWidget {
  const BiometricAuthScreen({
    this.autoAuth = false,
    super.key,
    this.canPop = false,
    this.title = 'Unlock Keychat',
  });
  final bool autoAuth;
  final bool canPop;
  final String title;

  @override
  _BiometricAuthScreenState createState() => _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends State<BiometricAuthScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoAuth) auth();
  }

  Future<void> auth() async {
    final result = await Get.find<SettingController>().authenticate();
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 100,
                color: Colors.grey,
              ),
              const SizedBox(height: 32),
              FilledButton(onPressed: auth, child: Text(widget.title)),
              if (widget.canPop) const SizedBox(height: 16),
              if (widget.canPop)
                OutlinedButton(
                  onPressed: () {
                    Get.back(result: false);
                  },
                  child: const Text('Back'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
