import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRCodeScanText extends StatefulWidget {
  const QRCodeScanText({super.key});

  @override
  State<StatefulWidget> createState() => _QRCodeViewState();
}

class _QRCodeViewState extends State<QRCodeScanText> {
  MobileScannerController cameraController =
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);

  @override
  Widget build(BuildContext context) {
    bool detected = false;
    return Scaffold(
        appBar: AppBar(
            centerTitle: true,
            title: Text(
              'Scan',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 18),
            )),
        body: Stack(alignment: Alignment.center, children: [
          MobileScanner(
              // fit: BoxFit.contain,
              controller: cameraController,
              // startDelay: true,
              onDetect: (capture) async {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isEmpty || detected) return;
                detected = true;
                final barcode = barcodes[0];

                var str = barcode.rawValue!.toString();
                Get.back(result: str);
              }),
        ]));
  }
}
