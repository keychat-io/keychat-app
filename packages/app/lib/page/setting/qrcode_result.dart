import 'package:flutter/material.dart';
import 'package:get/get.dart';

class QRViewResult extends StatelessWidget {
  const QRViewResult({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('scan result'),
      ),
      body: Text(Get.arguments ?? 'scan result'),
    );
  }
}
