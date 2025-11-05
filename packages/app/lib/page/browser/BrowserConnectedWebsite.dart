import 'dart:async';
import 'package:keychat/models/browser/browser_connect.dart';
import 'package:keychat/models/identity.dart';
import 'package:keychat/utils.dart';
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
    unawaited(
      loadData(pubkey: widget.identity.secp256k1PKHex, limit: 20, offset: 0),
    );
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
      body: urls.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.language,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No websites connected yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Websites you log in to will appear here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : CustomMaterialIndicator(
              onRefresh: () async {
                await loadData(
                  pubkey: widget.identity.secp256k1PKHex,
                  limit: 20,
                  offset: urls.length,
                );
              },
              displacement: 20,
              backgroundColor: Colors.white,
              trigger: IndicatorTrigger.trailingEdge,
              triggerMode: IndicatorTriggerMode.anywhere,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: urls.length,
                separatorBuilder: (BuildContext context2, int index) =>
                    const Divider(
                      indent: 16,
                      endIndent: 16,
                    ),
                itemBuilder: (context, index) {
                  final site = urls[index];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 1,
                      horizontal: 16,
                    ),
                    leading: Utils.getAvatarByIdentity(
                      widget.identity,
                      size: 36,
                    ),
                    title: Row(
                      children: [
                        const Text('+'),
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 8),
                          child:
                              Utils.getNetworkImage(site.favicon, size: 24) ??
                              Container(),
                        ),
                        Text(
                          site.host,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.close),
                    onTap: () {
                      Get.dialog(
                        CupertinoAlertDialog(
                          title: const Text('Disconnect'),
                          content: const Text(
                            'Are you sure you want to disconnect?',
                          ),
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
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  Future<void> loadData({
    required String pubkey,
    required int limit,
    required int offset,
  }) async {
    final list = await BrowserConnect.getAllByPubkey(
      pubkey: pubkey,
      limit: limit,
      offset: offset,
    );
    urls.addAll(list);
    setState(() {
      urls = [...urls];
    });
  }
}
