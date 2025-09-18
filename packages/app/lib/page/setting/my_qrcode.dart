// ignore_for_file: must_be_immutable
import 'dart:convert' show jsonDecode;
import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/page/components.dart';
import 'package:app/service/signalId.service.dart';
import 'package:app/service/signal_chat_util.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

class MyQRCode extends StatefulWidget {
  MyQRCode(
      {required this.oneTimeKey,
      required this.identity,
      required this.signalId,
      super.key,
      this.onTap,
      this.time,
      this.title,
      this.isOneTime = false,
      this.showMore = false,
      this.showAppBar = false});
  final Identity identity;
  final bool showAppBar;
  final bool showMore;
  final bool isOneTime;
  final String oneTimeKey;
  final SignalId signalId;
  int? time;
  final void Function()? onTap;
  String? title;

  @override
  State<StatefulWidget> createState() => _MyQRCodeState();
}

class _MyQRCodeState extends State<MyQRCode> {
  late String url;

  @override
  void initState() {
    url = '${KeychatGlobal.mainWebsite}/u/?k=${widget.identity.npub}';
    init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: widget.title != null
            ? AppBar(
                leading: Container(),
                title: Text(widget.title!),
                centerTitle: true,
                actions: [
                    IconButton(
                        onPressed: Get.back, icon: const Icon(Icons.close))
                  ])
            : null,
        body: GestureDetector(
            onTap: widget.onTap,
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
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Share to your friends',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Utils.genQRImage(url, size: 360),
                  const SizedBox(height: 8),
                  textSmallGray(
                      context,
                      widget.isOneTime
                          ? 'Expires In: ${widget.time != null ? formatTime(widget.time!, 'MM-dd HH:mm') : '24 hours'}'
                          : ''),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: url));
                          EasyLoading.showSuccess('One-Time link copied');
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('One-Time Link'),
                      ),
                      OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.grey)),
                          onPressed: () {
                            SharePlus.instance
                                .share(ShareParams(uri: Uri.tryParse(url)));
                          },
                          icon: const Icon(Icons.share, color: Colors.white),
                          label: const Text('Share',
                              style: TextStyle(color: Colors.white))),
                    ],
                  )
                ]))));
  }

  Future<String> _initQRCodeData(
      Identity identity, String onetimekey, SignalId signalId,
      [int time = -1]) async {
    final Map userInfo = signalId.keys == null
        ? await SignalIdService.instance.getQRCodeData(signalId)
        : jsonDecode(signalId.keys!);

    final content = SignalChatUtil.getToSignMessage(
        nostrId: identity.secp256k1PKHex,
        signalId: signalId.pubkey,
        time: time);

    final sig = await SignalChatUtil.signByIdentity(
        identity: identity, content: content);
    if (sig == null) throw Exception('Sign failed or User denied');
    final avatarRemoteUrl = await identity.getRemoteAvatarUrl();

    final data = <String, dynamic>{
      'pubkey': identity.secp256k1PKHex,
      'curve25519PkHex': signalId.pubkey,
      'name': identity.displayName,
      'time': time,
      'relay': '',
      'avatar': avatarRemoteUrl,
      'lightning': identity.lightning,
      'onetimekey': onetimekey,
      'globalSign': sig,
      ...userInfo.map((k, v) => MapEntry(k.toString(), v))
    };
    logger.i('qrcode, $data');
    return QRUserModel.fromJson(data).toShortStringForQrcode();
  }

  Future<void> init() async {
    final qrString = await _initQRCodeData(
        widget.identity, widget.oneTimeKey, widget.signalId, widget.time ?? -1);
    logger.i('init qrcode: $qrString');
    setState(() {
      url =
          '${KeychatGlobal.mainWebsite}/u/?k=${Uri.encodeComponent(qrString)}';
    });
  }
}
