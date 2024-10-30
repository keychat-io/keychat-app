// ignore_for_file: must_be_immutable
import 'dart:convert' show jsonDecode;

import 'package:app/models/models.dart';
import 'package:app/models/signal_id.dart';
import 'package:app/page/components.dart';
import 'package:app/service/signalId.service.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:app/utils.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
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
  MyQRCode(
      {super.key,
      required this.oneTimeKey,
      required this.identity,
      required this.signalId,
      this.onTap,
      this.time,
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

  bool _checkboxSelected = true;

  Widget markAsUsed() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Mark as used",
          style: TextStyle(
            fontSize: 16,
          ),
        ),
        Switch(
            value: _checkboxSelected,
            onChanged: (value) async {
              setState(() {
                _checkboxSelected = value;
              });
            })
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
                child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10.0, vertical: 10),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          widget.isOneTime
                              ? 'Expires in ${widget.time != null ? formatTimeToYYYYMMDDhhmm(widget.time!) : '24 hours'}'
                              : "",
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 20),
                      Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: genQRImage(qrString,
                              size: 360, embeddedImage: null)),
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
                            child: const Text(
                              "Copy",
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              final box =
                                  context.findRenderObject() as RenderBox?;

                              Share.share(
                                widget.isOneTime
                                    ? qrString
                                    : widget.identity.npub,
                                sharePositionOrigin:
                                    box!.localToGlobal(Offset.zero) & box.size,
                              );
                            },
                            child: const Text(
                              "Share",
                            ),
                          ),
                        ],
                      )
                    ])))));
  }

  Future<String> _initQRCodeData(Identity identity, String onetimekey,
      SignalId signalId, int? time) async {
    Map userInfo = signalId.keys == null
        ? await SignalIdService.instance.getQRCodeData(signalId)
        : jsonDecode(signalId.keys!);
    String globalSignStr =
        "Keychat-${identity.secp256k1PKHex}-${signalId.pubkey}-$time";
    // add gloabl sign

    String globalSignResult = await rust_nostr.signSchnorr(
        senderKeys: await identity.getSecp256k1SKHex(), content: globalSignStr);
    Map<String, dynamic> data = {
      'pubkey': identity.secp256k1PKHex,
      'curve25519PkHex': signalId.pubkey,
      'name': identity.displayName,
      'time': time ?? -1,
      'relay': "",
      "onetimekey": onetimekey,
      "globalSign": globalSignResult,
      ...userInfo
    };
    logger.d('qrcode, $data');
    return QRUserModel.fromJson(data).toShortStringForQrcode();
  }

  void init() async {
    String res = await _initQRCodeData(
        widget.identity, widget.oneTimeKey, widget.signalId, widget.time);
    setState(() {
      qrString = res;
    });
  }
}

String stringToHex(String input) {
  return input.codeUnits
      .map((unit) => unit.toRadixString(16).padLeft(2, '0'))
      .join();
}

String hexToString(String input) {
  return String.fromCharCodes(List.generate(
      input.length ~/ 2,
      (index) =>
          int.parse(input.substring(index * 2, index * 2 + 2), radix: 16)));
}
