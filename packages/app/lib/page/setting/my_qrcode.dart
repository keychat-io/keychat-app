import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/utils.dart';
import 'package:share_plus/share_plus.dart';

// ignore: must_be_immutable
class MyQRCode extends StatelessWidget {
  MyQRCode({
    required this.url,
    super.key,
    this.expiredTime,
    this.isOneTime = false,
    this.title,
  });
  String url;
  bool isOneTime;
  String? title;
  int? expiredTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null
          ? AppBar(
              leading: Container(),
              title: Text(title!),
              centerTitle: true,
              actions: [
                IconButton(
                  onPressed: Get.back,
                  icon: const Icon(Icons.close),
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: Get.back,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xffCE9FFC), Color(0xff7367F0)],
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share to your friends',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Utils.genQRImage(url, size: 360),
              const SizedBox(height: 8),
              textSmallGray(
                context,
                isOneTime
                    ? 'Expires In: ${expiredTime != null ? formatTime(expiredTime!, 'MM-dd HH:mm') : '24 hours'}'
                    : '',
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      await EasyLoading.showSuccess('One-Time link copied');
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                    ),
                    onPressed: () async {
                      await SharePlus.instance.share(
                        ShareParams(uri: Uri.tryParse(url)),
                      );
                    },
                    icon: const Icon(Icons.share, color: Colors.white),
                    label: const Text(
                      'Share',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
