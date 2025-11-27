import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/models/room.dart';
import 'package:keychat/page/chat/SelectRoomRelay.dart';
import 'package:keychat/service/contact.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/service/signal_chat.service.dart';
import 'package:settings_ui/settings_ui.dart';

class ChatSettingSecurity extends StatelessWidget {
  const ChatSettingSecurity({super.key, this.roomId});
  final int? roomId;
  @override
  Widget build(BuildContext context) {
    final id = roomId ?? int.parse(Get.parameters['id']!);
    final cc = RoomService.getController(id)!;

    final receiveKeys =
        ContactService.instance.getMyReceiveKeys(cc.roomObs.value) ?? [];
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Security Settings')),
      body: Obx(
        () => SettingsList(
          platform: DevicePlatform.iOS,
          sections: [
            SettingsSection(
              title: const Text('Message Encrypt Protocol'),
              tiles: [
                SettingsTile(
                  title: const Text('Encrypt mode'),
                  leading: const Icon(CupertinoIcons.lock),
                  value: Text(cc.roomObs.value.encryptMode.name.toUpperCase()),
                  onPressed: (context) {
                    if (!(cc.roomObs.value.encryptMode == EncryptMode.nip04 ||
                        cc.roomObs.value.encryptMode == EncryptMode.nip17)) {
                      return;
                    }
                    Get.dialog(
                      CupertinoAlertDialog(
                        title: const Text('Select Encrypt Mode'),
                        content: Text(
                          'Current mode: ${cc.roomObs.value.encryptMode.name.toUpperCase()}',
                        ),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('NIP04'),
                            onPressed: () async {
                              Get.back<void>();
                              if (cc.roomObs.value.encryptMode ==
                                  EncryptMode.nip04) {
                                return;
                              }
                              cc.roomObs.value.encryptMode = EncryptMode.nip04;
                              await RoomService.instance.updateRoomAndRefresh(
                                cc.roomObs.value,
                              );
                              EasyLoading.showToast('Switched to NIP04');
                            },
                          ),
                          CupertinoDialogAction(
                            child: const Text('NIP17'),
                            onPressed: () async {
                              Get.back<void>();
                              if (cc.roomObs.value.encryptMode ==
                                  EncryptMode.nip17) {
                                return;
                              }
                              cc.roomObs.value.encryptMode = EncryptMode.nip17;
                              await RoomService.instance.updateRoomAndRefresh(
                                cc.roomObs.value,
                              );
                              EasyLoading.showToast('Switched to NIP17');
                            },
                          ),
                          CupertinoDialogAction(
                            child: const Text('Signal'),
                            onPressed: () async {
                              Get.back<void>();
                              await SignalChatService.instance
                                  .resetSignalSession(cc.roomObs.value);
                            },
                          ),
                          CupertinoDialogAction(
                            child: const Text('Cancel'),
                            onPressed: () {
                              Get.back<void>();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                SettingsTile.navigation(
                  title: const Text('Reset Signal Session'),
                  leading: const Icon(CupertinoIcons.refresh),
                  onPressed: (value) async {
                    Get.dialog(
                      CupertinoAlertDialog(
                        title: const Text('Send request'),
                        content: const Text(
                          'Waiting for your friend comes online and approve',
                        ),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('OK'),
                            onPressed: () async {
                              Get.back<void>();
                              await SignalChatService.instance
                                  .resetSignalSession(cc.roomObs.value);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            SettingsSection(
              title: const Text('Message Relays'),
              tiles: [
                SettingsTile(
                  title: const Text('SendTo'),
                  leading: const Icon(CupertinoIcons.up_arrow),
                  value: Obx(
                    () => cc.roomObs.value.sendingRelays.isEmpty
                        ? const Text('All Relays')
                        : Flexible(
                            child: Text(
                              cc.roomObs.value.sendingRelays.isNotEmpty
                                  ? cc.roomObs.value.sendingRelays.join(',')
                                  : '',
                            ),
                          ),
                  ),
                  onPressed: (c) {
                    if (cc.roomObs.value.sendingRelays.isEmpty) {
                      return;
                    }
                    Get.dialog(
                      CupertinoAlertDialog(
                        title: const Text('Delete Config'),
                        content: const Text(
                          'Are you sure to delete receving config?',
                        ),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('Cancel'),
                            onPressed: () {
                              Get.back<void>();
                            },
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            onPressed: () async {
                              cc.roomObs.value.receivingRelays = [];
                              await RoomService.instance.updateRoomAndRefresh(
                                cc.roomObs.value,
                              );
                              EasyLoading.showToast('Save Success');
                              Get.back<void>();
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (cc.roomObs.value.type != RoomType.bot)
                  SettingsTile.navigation(
                    title: const Text('ReceiveFrom'),
                    leading: const Icon(CupertinoIcons.down_arrow),
                    description: Obx(
                      () => Text(
                        cc.roomObs.value.receivingRelays.isNotEmpty
                            ? cc.roomObs.value.receivingRelays.join(',')
                            : '',
                      ),
                    ),
                    onPressed: (context) async {
                      final relays = await Get.bottomSheet<List<String>>(
                        clipBehavior: Clip.antiAlias,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        SelectRoomRelay(cc.roomObs.value.receivingRelays),
                      );
                      if (relays == null) return;
                      cc.roomObs.value.receivingRelays = relays;
                      await RoomService.instance.updateRoomAndRefresh(
                        cc.roomObs.value,
                      );
                      await SignalChatService.instance.sendRelaySyncMessage(
                        cc.roomObs.value,
                        relays,
                      );
                      EasyLoading.showToast('Save Success');
                    },
                  ),
              ],
            ),
            if (receiveKeys.isNotEmpty)
              SettingsSection(
                title: const Text('My Receiving Addresses'),
                tiles: receiveKeys
                    .map((e) => SettingsTile(title: Text(e)))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
