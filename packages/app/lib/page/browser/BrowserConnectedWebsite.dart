import 'package:app/models/browser/browser_connect.dart';
import 'package:app/models/identity.dart';
import 'package:app/utils.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BrowserConnectedWebsite extends StatefulWidget {
  const BrowserConnectedWebsite(this.identity, {super.key});
  final Identity identity;

  @override
  _BrowserConnectedWebsiteState createState() =>
      _BrowserConnectedWebsiteState();
}

class _BrowserConnectedWebsiteState extends State<BrowserConnectedWebsite> {
  List<BrowserConnect> urls = [];
  @override
  void initState() {
    loadData(pubkey: widget.identity.secp256k1PKHex, limit: 20, offset: 0);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Logged-in Websites')),
        body: CustomMaterialIndicator(
            onRefresh: () async {
              await loadData(
                  pubkey: widget.identity.secp256k1PKHex,
                  limit: 20,
                  offset: urls.length);
            },
            displacement: 20,
            backgroundColor: Colors.white,
            trigger: IndicatorTrigger.trailingEdge,
            triggerMode: IndicatorTriggerMode.anywhere,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: urls.length,
              separatorBuilder: (BuildContext context2, int index) =>
                  const Divider(
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final site = urls[index];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 1, horizontal: 16),
                  leading: Utils.getRandomAvatar(site.pubkey, width: 36),
                  title: Row(children: [
                    const Text('+'),
                    Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: Utils.getNetworkImage(site.favicon, size: 24) ??
                            Container()),
                    Text(site.host,
                        style: Theme.of(context).textTheme.titleMedium)
                  ]),
                  trailing: const Icon(Icons.close),
                  onTap: () {
                    Get.dialog(CupertinoAlertDialog(
                      title: const Text('Disconnect'),
                      content:
                          const Text('Are you sure you want to disconnect?'),
                      actions: <Widget>[
                        CupertinoDialogAction(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Get.back<void>();
                          },
                        ),
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          child: const Text('Disconnect'),
                          onPressed: () async {
                            await BrowserConnect.delete(site.id);
                            urls.removeAt(index);
                            setState(() {
                              urls = [...urls];
                            });
                            Get.back<void>();
                          },
                        ),
                      ],
                    ));
                  },
                );
              },
            )));
  }

  Future loadData(
      {required String pubkey, required int limit, required int offset}) async {
    final list = await BrowserConnect.getAllByPubkey(
        pubkey: pubkey, limit: limit, offset: offset);
    urls.addAll(list);
    setState(() {
      urls = [...urls];
    });
  }
}
