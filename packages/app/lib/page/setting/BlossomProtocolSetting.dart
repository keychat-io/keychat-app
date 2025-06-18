import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/service/storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class BlossomProtocolSetting extends StatefulWidget {
  const BlossomProtocolSetting({super.key});

  @override
  _BlossomProtocolSettingState createState() => _BlossomProtocolSettingState();
}

class _BlossomProtocolSettingState extends State<BlossomProtocolSetting> {
  List<String> selected = [];
  bool isEditMode = false;
  List<String> builtInMedias = [
    "https://void.cat",
    "https://cdn.satellite.earth",
    "https://cdn.nostrcheck.me",
    "https://nostr.download",
    "https://nostrmedia.com",
  ];

  @override
  void initState() {
    super.initState();
    _loadSelectedServers();
  }

  Future<void> _loadSelectedServers() async {
    List<String> savedServers =
        await Storage.getStringList(StorageKeyString.blossomProtocolServers);
    setState(() {
      selected = savedServers;
    });
  }

  Future<void> _saveSelectedServers() async {
    await Storage.setStringList(
        StorageKeyString.blossomProtocolServers, selected);
  }

  void _toggleEditMode() {
    setState(() {
      isEditMode = !isEditMode;
    });
  }

  void _addToSelected(String url) async {
    if (!selected.contains(url)) {
      setState(() {
        selected.add(url);
      });
      await _saveSelectedServers();
    }
  }

  void _removeFromSelected(String url) async {
    setState(() {
      selected.remove(url);
    });
    await _saveSelectedServers();
  }

  void _showAddCustomDialog() {
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Add Custom Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoTextField(
              controller: urlController,
              placeholder: 'URL',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              if (urlController.text.isNotEmpty) {
                if (!(Uri.tryParse(urlController.text)?.hasAbsolutePath ??
                    false)) {
                  EasyLoading.showError('Invalid URL');
                  return;
                }
                _addToSelected(urlController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SettingsList(
        sections: [
          SettingsSection(
            title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Selected Servers'),
                  TextButton(
                      onPressed: _toggleEditMode,
                      child: Text(isEditMode ? 'Done' : 'Edit'))
                ]),
            tiles: [
              ...selected.map((url) => SettingsTile(
                    title: Text(url),
                    trailing: isEditMode
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.red),
                            onPressed: () => _removeFromSelected(url),
                          )
                        : TextButton(
                            onPressed: () {
                              Get.find<MultiWebviewController>()
                                  .launchWebview(content: url);
                            },
                            child: Text('Pay')),
                  )),
              SettingsTile(
                title: const Text('Add Custom Server'),
                leading: const Icon(Icons.add),
                onPressed: (context) => _showAddCustomDialog(),
              ),
            ],
          ),
          SettingsSection(
            title: const Text('Recommended Servers'),
            tiles: builtInMedias
                .map((url) => SettingsTile(
                      title: Text(url),
                      trailing: IconButton(
                        icon: Icon(
                          selected.contains(url)
                              ? Icons.check_circle
                              : Icons.add_circle,
                          color: selected.contains(url)
                              ? Colors.green
                              : Colors.blue,
                        ),
                        onPressed: () => _addToSelected(url),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
