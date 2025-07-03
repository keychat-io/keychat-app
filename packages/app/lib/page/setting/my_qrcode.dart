// ignore_for_file: must_be_immutable
import 'dart:convert' show jsonDecode;

import 'package:app/models/models.dart';
import 'package:app/service/signalId.service.dart';
import 'package:app/service/signal_chat_util.dart';

import 'package:app/utils.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

class MyQRCode extends StatefulWidget {
  final Identity identity;
  final bool showAppBar;
  final bool showMore;
  final bool isOneTime;
  final String oneTimeKey;
  final SignalId signalId;
  int? time;
  final void Function()? onTap;
  String? title;
  MyQRCode(
      {super.key,
      required this.oneTimeKey,
      required this.identity,
      required this.signalId,
      this.onTap,
      this.time,
      this.title,
      this.isOneTime = false,
      this.showMore = false,
      this.showAppBar = false});

  @override
  State<StatefulWidget> createState() => _MyQRCodeState();
}

class _MyQRCodeState extends State<MyQRCode> {
// class MyQRCode extends StatelessWidget {

  late String qrString;

  @override
  void initState() {
    qrString = widget.identity.npub;
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
                    IconButton(onPressed: Get.back, icon: Icon(Icons.close))
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                      widget.isOneTime
                          ? 'Expires In: ${widget.time != null ? formatTime(widget.time!, 'MM-dd HH:mm') : '24 hours'}'
                          : "",
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 16),
                  Utils.genQRImage(qrString, size: 360),
                  Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        widget.isOneTime && qrString.length > 200
                            ? "${qrString.substring(0, 30)}......${qrString.substring(qrString.length - 30)}"
                            // ? qrString
                            : widget.identity.npub,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 4,
                      )),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    children: [
                      FilledButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text: widget.isOneTime
                                  ? qrString
                                  : widget.identity.npub));
                          EasyLoading.showSuccess("Copied");
                        },
                        child: const Text("Copy"),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                        ),
                        onPressed: () {
                          final box = context.findRenderObject() as RenderBox?;

                          Share.share(
                            widget.isOneTime ? qrString : widget.identity.npub,
                            sharePositionOrigin:
                                box!.localToGlobal(Offset.zero) & box.size,
                          );
                        },
                        child: const Text(
                          "Share",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  )
                ]))));
  }

  Future<String> _initQRCodeData(
      Identity identity, String onetimekey, SignalId signalId,
      [int time = -1]) async {
    Map userInfo = signalId.keys == null
        ? await SignalIdService.instance.getQRCodeData(signalId)
        : jsonDecode(signalId.keys!);

    String content = SignalChatUtil.getToSignMessage(
        nostrId: identity.secp256k1PKHex,
        signalId: signalId.pubkey,
        time: time);

    String? sig = await SignalChatUtil.signByIdentity(
        identity: identity, content: content);
    if (sig == null) throw Exception('Sign failed or User denied');
    Map<String, dynamic> data = {
      'pubkey': identity.secp256k1PKHex,
      'curve25519PkHex': signalId.pubkey,
      'name': identity.displayName,
      'time': time,
      'relay': "",
      "onetimekey": onetimekey,
      "globalSign": sig,
      ...userInfo
    };
    logger.i('qrcode, $data');
    return QRUserModel.fromJson(data).toShortStringForQrcode();
  }

  void init() async {
    String res = await _initQRCodeData(
        widget.identity, widget.oneTimeKey, widget.signalId, widget.time ?? -1);
    setState(() {
      qrString = res;
    });
  }
}
