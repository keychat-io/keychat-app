import 'package:app/models/browser/browser_connect.dart';
import 'package:app/models/identity.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class BrowserConnectedWebsite extends StatefulWidget {
  final Identity identity;
  const BrowserConnectedWebsite(this.identity, {super.key});

  @override
  _BrowserConnectedWebsiteState createState() =>
      _BrowserConnectedWebsiteState();
}

class _BrowserConnectedWebsiteState extends State<BrowserConnectedWebsite> {
  List<BrowserConnect> urls = [];
  late RefreshController refreshController;
  @override
  void initState() {
    refreshController = RefreshController();
    loadData(pubkey: widget.identity.secp256k1PKHex, limit: 20, offset: 0);
    super.initState();
  }

  @override
  void dispose() {
    refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Logged in Websites')),
        body: SmartRefresher(
            enablePullUp: true,
            enablePullDown: false,
            onLoading: () async {
              await loadData(
                  pubkey: widget.identity.secp256k1PKHex,
                  limit: 20,
                  offset: urls.length);
              refreshController.loadComplete();
            },
            controller: refreshController,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: urls.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const Divider(
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final site = urls[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 1.0, horizontal: 16.0),
                  leading: Utils.getRandomAvatar(site.pubkey, width: 36),
                  title: Row(children: [
                    const Text('x'),
                    Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: Utils.getNeworkImage(site.favicon, size: 24) ??
                            Container()),
                    Text(site.host,
                        style: Theme.of(context).textTheme.titleMedium)
                  ]),
                  onTap: () {
                    // dialog to disconnect
                    Get.dialog(CupertinoAlertDialog(
                      title: const Text('Disconnect'),
                      content:
                          const Text('Are you sure you want to disconnect?'),
                      actions: <Widget>[
                        CupertinoDialogAction(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Get.back();
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
                            Get.back();
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
    var list = await BrowserConnect.getAllByPubkey(
        pubkey: pubkey, limit: limit, offset: offset);
    urls.addAll(list);
    setState(() {
      urls = [...urls];
    });
  }
}
