import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:keychat/global.dart';
import 'package:keychat/models/identity.dart';
import 'package:keychat/page/browser/BrowserConnectedWebsite.dart';
import 'package:keychat/page/browser/DownloadManager_page.dart';
import 'package:keychat/page/browser/KeepAliveHosts.dart';
import 'package:keychat/page/browser/MultiWebviewController.dart';
import 'package:keychat/service/identity.service.dart';
import 'package:keychat/service/storage.dart';
import 'package:keychat/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class BrowserSetting extends StatefulWidget {
  const BrowserSetting({super.key});

  @override
  _BrowserSettingState createState() => _BrowserSettingState();
}

class _BrowserSettingState extends State<BrowserSetting> {
  late MultiWebviewController controller;
  List<Identity> identities = [];
  bool showFAB = true;
  @override
  void initState() {
    super.initState();
    controller = Get.find<MultiWebviewController>();
    init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browser Settings'),
        centerTitle: true,
      ),
      body: Obx(
        () => SettingsList(
          platform: DevicePlatform.iOS,
          sections: [
            if (identities.isNotEmpty)
              SettingsSection(
                title: const Text('Enabled Browser ID'),
                tiles: identities
                    .map(
                      (identity) => SettingsTile.navigation(
                        leading: Utils.getAvatarByIdentity(identity, size: 32),
                        title: Text(
                          identity.displayName.length > 8
                              ? '${identity.displayName.substring(0, 8)}...'
                              : identity.displayName,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        value: Text(getPublicKeyDisplay(identity.npub)),
                        onPressed: (context) {
                          Get.to(
                            () => BrowserConnectedWebsite(identity),
                            id: GetPlatform.isDesktop
                                ? GetXNestKey.setting
                                : null,
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
            SettingsSection(
              tiles: [
                SettingsTile.navigation(
                  title: const Text('Search Engine'),
                  leading: const Icon(Icons.search),
                  value: Text(controller.defaultSearchEngineObx.value),
                  onPressed: (context) {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return RadioGroup<String>(
                          groupValue: controller.defaultSearchEngineObx.value,
                          onChanged: (value) async {
                            if (value == null) return;
                            await controller.setSearchEngine(value);
                            EasyLoading.showSuccess('Success');
                            Get.back<void>();
                          },
                          child: SimpleDialog(
                            title: const Text('Select Search Engine'),
                            children: BrowserEngine.values
                                .map(
                                  (str) => ListTile(
                                    leading: Radio<String>(
                                      value: str.name,
                                    ),
                                    title: Text(
                                      Utils.capitalizeFirstLetter(
                                        str.name,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                    );
                  },
                ),
                SettingsTile.navigation(
                  title: const Text('Downloads'),
                  leading: const Icon(Icons.file_download),
                  onPressed: (_) async {
                    await Get.to<void>(() => const DownloadManagerPage());
                  },
                ),
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  initialValue: controller.browserConfig.autoSignEvent,
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('Auto Sign Event'),
                  onToggle: (value) async {
                    await controller.browserConfig.setAutoSignEvent(value);
                    EasyLoading.showSuccess('Success');
                  },
                ),
                SettingsTile.switchTile(
                  initialValue: controller.browserConfig.enableHistory,
                  leading: const Icon(CupertinoIcons.time),
                  title: const Text('Enable History'),
                  onToggle: (value) async {
                    await controller.browserConfig.setEnableHistory(value);
                    EasyLoading.showSuccess('Success');
                  },
                ),
                if (GetPlatform.isMobile)
                  SettingsTile.navigation(
                    leading: const Icon(CupertinoIcons.heart),
                    title: const Text('KeepAlive Hosts'),
                    onPressed: (context) async {
                      await Get.to(KeepAliveHosts.new);
                    },
                  ),
                if (controller.browserConfig.enableHistory)
                  SettingsTile.navigation(
                    title: const Text('Auto-delete'),
                    value: Text(
                      "${controller.browserConfig.historyRetentionDays} ${controller.browserConfig.historyRetentionDays == 1 ? 'day' : 'days'}",
                    ),
                    leading: const Icon(CupertinoIcons.delete),
                    onPressed: (context) async {
                      final selectedDays = await showDialog<int>(
                        context: context,
                        builder: (BuildContext context) {
                          return RadioGroup<int>(
                            groupValue:
                                controller.browserConfig.historyRetentionDays,
                            onChanged: selectRetentionPeriod,
                            child: SimpleDialog(
                              title: const Text('Select Retention Period'),
                              children: [1, 7, 30].map((days) {
                                return RadioListTile<int>(
                                  title: Text(
                                    '$days ${days == 1 ? 'Day' : 'Days'}',
                                  ),
                                  value: days,
                                );
                              }).toList(),
                            ),
                          );
                        },
                      );

                      if (selectedDays != null) {
                        await controller.setConfig(
                          'historyRetentionDays',
                          selectedDays,
                        );
                      }
                    },
                  ),
              ],
            ),
            if (GetPlatform.isMobile)
              SettingsSection(
                tiles: [
                  SettingsTile.switchTile(
                    initialValue: showFAB,
                    leading: const Icon(CupertinoIcons.circle_fill),
                    title: const Text('Floating Action Button'),
                    onToggle: (value) async {
                      await controller.browserConfig.setShowFAB(value);
                      setState(() {
                        showFAB = value;
                      });
                      EasyLoading.showSuccess('Success');
                    },
                  ),
                  SettingsTile.navigation(
                    leading: const Icon(CupertinoIcons.move),
                    title: const Text('Position & Height'),
                    value: Text(
                      '${controller.browserConfig.fabPosition == 'left' ? 'Left' : 'Right'}, ${(controller.browserConfig.fabHeight * 100).round()}%',
                    ),
                    onPressed: (context) {
                      _showFabPositionEditor(context);
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> init() async {
    final list = await IdentityService.instance.getEnableBrowserIdentityList();
    final fab = controller.browserConfig.showFAB;
    setState(() {
      showFAB = fab;
      identities = list;
    });
  }

  Future<void> selectRetentionPeriod(Object? value) async {
    if (value == null) return;
    await controller.browserConfig.setHistoryRetentionDays(value as int);
    await EasyLoading.showSuccess('Success');
    await controller.deleteOldHistories();
    Get.back(result: value);
  }

  void _showFabPositionEditor(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FabPositionEditorSheet(
        initialPosition: controller.browserConfig.fabPosition,
        initialHeight: controller.browserConfig.fabHeight,
        onSave: (position, height) async {
          await controller.browserConfig.setFabPosition(position);
          await controller.browserConfig.setFabHeight(height);
          setState(() {});
          EasyLoading.showSuccess('Success');
        },
      ),
    );
  }
}

class _FabPositionEditorSheet extends StatefulWidget {
  const _FabPositionEditorSheet({
    required this.initialPosition,
    required this.initialHeight,
    required this.onSave,
  });

  final String initialPosition;
  final double initialHeight;
  final Future<void> Function(String position, double height) onSave;

  @override
  State<_FabPositionEditorSheet> createState() =>
      _FabPositionEditorSheetState();
}

class _FabPositionEditorSheetState extends State<_FabPositionEditorSheet> {
  late String _position;
  late double _height;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _height = widget.initialHeight;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final previewHeight = screenHeight * 0.5;

    return SafeArea(
      child: Container(
        height: screenHeight * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Text(
                    'FAB Position',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await widget.onSave(_position, _height);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Preview area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Instructions
                    Text(
                      'Drag the button to adjust position',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Phone preview frame
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 200,
                          height: previewHeight,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.grey[400]!,
                              width: 3,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(21),
                            child: Container(
                              color: Colors.grey[100],
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final availableHeight = constraints.maxHeight;
                                  final availableWidth = constraints.maxWidth;
                                  const fabSize = 44.0;
                                  const horizontalPadding = 16.0;

                                  // Calculate FAB position
                                  final fabBottom = availableHeight * _height;
                                  final fabLeft = _position == 'left'
                                      ? horizontalPadding
                                      : availableWidth -
                                            fabSize -
                                            horizontalPadding;

                                  return Stack(
                                    children: [
                                      // Mock browser content
                                      Positioned.fill(
                                        child: Column(
                                          children: [
                                            // Mock address bar
                                            Container(
                                              height: 30,
                                              margin: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'example.com',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Mock content lines
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: List.generate(
                                                    8,
                                                    (index) => Container(
                                                      height: 8,
                                                      margin:
                                                          const EdgeInsets.only(
                                                            bottom: 8,
                                                          ),
                                                      width: index % 3 == 0
                                                          ? availableWidth * 0.6
                                                          : index % 2 == 0
                                                          ? availableWidth * 0.8
                                                          : availableWidth *
                                                                0.5,
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[300],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Draggable FAB
                                      Positioned(
                                        left: fabLeft,
                                        bottom: fabBottom,
                                        child: GestureDetector(
                                          onPanStart: (_) {
                                            setState(() => _isDragging = true);
                                          },
                                          onPanUpdate: (details) {
                                            setState(() {
                                              // Update height based on vertical drag
                                              final newBottom =
                                                  fabBottom - details.delta.dy;
                                              _height =
                                                  (newBottom / availableHeight)
                                                      .clamp(0.05, 0.8);

                                              // Update position based on horizontal position
                                              final currentX =
                                                  fabLeft + details.delta.dx;
                                              if (currentX <
                                                  availableWidth / 2 -
                                                      fabSize / 2) {
                                                _position = 'left';
                                              } else {
                                                _position = 'right';
                                              }
                                            });
                                          },
                                          onPanEnd: (_) {
                                            setState(() => _isDragging = false);
                                          },
                                          child: AnimatedContainer(
                                            duration: _isDragging
                                                ? Duration.zero
                                                : const Duration(
                                                    milliseconds: 150,
                                                  ),
                                            width: fabSize,
                                            height: fabSize,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.black87,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(
                                                        alpha: 0.3,
                                                      ),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Container(
                                              margin: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.grey[700],
                                              ),
                                              child: Container(
                                                margin: const EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.grey[400],
                                                ),
                                                child: Container(
                                                  margin: const EdgeInsets.all(
                                                    2,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Colors.white70,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Current values display
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Position',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() => _position = 'left');
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _position == 'left'
                                              ? Theme.of(context).primaryColor
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'Left',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: _position == 'left'
                                                ? Colors.white
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() => _position = 'right');
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _position == 'right'
                                              ? Theme.of(context).primaryColor
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'Right',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: _position == 'right'
                                                ? Colors.white
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.grey[300],
                          ),
                          Column(
                            children: [
                              Text(
                                'Height',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(_height * 100).round()}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
