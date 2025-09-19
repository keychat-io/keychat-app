import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/service/storage.dart';

class KeepAliveHosts extends StatefulWidget {
  const KeepAliveHosts({super.key});

  @override
  _KeepAliveHostsState createState() => _KeepAliveHostsState();
}

class _KeepAliveHostsState extends State<KeepAliveHosts> {
  final MultiWebviewController controller = Get.find<MultiWebviewController>();
  List<String> hosts = [];

  @override
  void initState() {
    super.initState();
    _loadHosts();
  }

  Future<void> _loadHosts() async {
    hosts = Storage.getStringList(StorageKeyString.mobileKeepAlive);
    setState(() {});
  }

  Future<void> _removeHost(String host) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Remove Host'),
          content:
              Text('Are you sure you want to remove "$host" from KeepAlive?'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: Get.back,
              child: const Text('Cancel'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                await controller.disableKeepAlive(host);
                await _loadHosts();
                Get.back<void>();
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearAllHosts() async {
    if (hosts.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Clear All'),
          content: const Text(
              'Are you sure you want to remove all KeepAlive hosts? This action cannot be undone.'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(context).pop();
                // Clear all hosts
                for (final host in hosts) {
                  controller.removeKeepAlive(host);
                }
                controller.mobileKeepAlive.clear();
                await Storage.setStringList(
                    StorageKeyString.mobileKeepAlive, []);
                await _loadHosts();

                if (mounted) {
                  EasyLoading.showSuccess('All KeepAlive hosts cleared');
                }
              },
              child:
                  const Text('Clear All', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KeepAlive Hosts'),
        centerTitle: true,
        actions: [
          if (hosts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearAllHosts,
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: hosts.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.web_asset_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No KeepAlive hosts configured',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'KeepAlive hosts help maintain web sessions',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'KeepAlive hosts save the web sessions to local storage',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.blue,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: hosts.length,
                    itemBuilder: (context, index) {
                      final host = hosts[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.web, color: Colors.green),
                          title: Text(host),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _removeHost(host),
                            tooltip: 'Remove host',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (hosts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${hosts.length} host${hosts.length == 1 ? '' : 's'} configured',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ),
              ],
            ),
    );
  }
}
