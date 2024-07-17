// ignore_for_file: depend_on_referenced_packages

import 'package:app/page/routes.dart';
import 'package:app/page/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:flutter/material.dart';
import 'package:keychat_ecash/components/SelectMint.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import './PayInvoice_controller.dart';

class PayInvoicePage extends StatefulWidget {
  const PayInvoicePage({super.key});

  @override
  _PayInvoicePageState createState() => _PayInvoicePageState();
}

class _PayInvoicePageState extends State<PayInvoicePage> {
  late EcashController cashuController;

  @override
  void initState() {
    cashuController = Get.find<EcashController>();
    cashuController.getBalance();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    PayInvoiceController controller = Get.put(PayInvoiceController());
    return Scaffold(
        appBar: AppBar(
          leading: Container(),
          centerTitle: true,
          title: const Text('Send to LightingNetwork'),
        ),
        body: SafeArea(
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
                child: Column(children: [
                  Form(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Expanded(
                        child: Column(
                      children: [
                        Obx(() =>
                            SelectMint(cashuController.latestMintUrl.value,
                                (String mint) {
                              cashuController.latestMintUrl.value = mint;
                              controller.selectedMint.value = mint;
                            })),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          child: TextField(
                            controller: controller.textController,
                            textInputAction: TextInputAction.done,
                            autofocus: true,
                            maxLines: 8,
                            style: const TextStyle(fontSize: 10),
                            decoration: InputDecoration(
                                labelText: 'Input Invoice',
                                hintText: 'Paste Lightning invoice',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.paste),
                                  onPressed: () async {
                                    final clipboardData =
                                        await Clipboard.getData('text/plain');
                                    if (clipboardData != null) {
                                      final pastedText = clipboardData.text;
                                      if (pastedText != null &&
                                          pastedText != '') {
                                        controller.textController.text =
                                            pastedText;
                                      }
                                    }
                                  },
                                )),
                          ),
                        ),
                        OutlinedButton.icon(
                            onPressed: () async {
                              PermissionStatus permissionStatus =
                                  await Permission.camera.status;
                              if (!permissionStatus.isGranted) {
                                permissionStatus =
                                    await Permission.camera.request();
                              }
                              if (permissionStatus.isGranted) {
                                var result =
                                    await Get.toNamed(Routes.scanQRText);
                                if (result != null) {
                                  if (GetPlatform.isMobile) {
                                    await Haptics.vibrate(
                                        HapticsType.selection);
                                  }
                                  controller.textController.text = result;
                                }
                              } else {
                                EasyLoading.showToast(
                                    'Camera permission not grant');
                                await Future.delayed(
                                    const Duration(milliseconds: 1000),
                                    () => {});
                                openAppSettings();
                              }
                            },
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan')),
                      ],
                    )),
                  ),
                  Obx(() => cashuController
                          .supportMint(controller.selectedMint.value)
                      ? FilledButton(
                          style: ButtonStyle(
                              minimumSize: WidgetStateProperty.all(
                                  const Size(double.infinity, 44))),
                          onPressed: () {
                            controller.confirm(controller.selectedMint.value);
                          },
                          child: const Text(
                            'Pay Invoice',
                          ),
                        )
                      : FilledButton(
                          onPressed: null,
                          style: ButtonStyle(
                            minimumSize: WidgetStateProperty.all(
                                const Size(double.infinity, 44)),
                            backgroundColor:
                                WidgetStateProperty.resolveWith<Color>(
                              (Set<WidgetState> states) {
                                if (states.contains(WidgetState.disabled)) {
                                  return Colors.grey;
                                }
                                return MaterialTheme.lightScheme().primary;
                              },
                            ),
                          ),
                          child: const Text(
                            'Disabled By Mint Server',
                          ))),
                ]))));
  }
}
