import 'package:keychat/models/contact.dart';
import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:keychat/page/widgets/notice_text_widget.dart';
import 'package:keychat/service/contact.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class ContactDetailPage extends StatelessWidget {
  const ContactDetailPage(this.contact, {super.key});
  final Contact contact;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              actions: [
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () {
                    showCupertinoModalPopup<void>(
                      context: context,
                      builder: (BuildContext context) => CupertinoActionSheet(
                        actions: <CupertinoActionSheetAction>[
                          CupertinoActionSheetAction(
                            isDestructiveAction: true,
                            onPressed: () async {
                              Get.back<void>();
                              _showDeleteConfirmDialog();
                            },
                            child: const Text('Delete Contact'),
                          ),
                        ],
                        cancelButton: CupertinoActionSheetAction(
                          onPressed: () {
                            Get.back<void>();
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Utils.getRandomAvatar(
                    contact.pubkey,
                    contact: contact,
                    size: 60,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    contact.displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  if (contact.displayAbout != null &&
                      contact.displayAbout!.isNotEmpty)
                    NoticeTextWidget.info(
                      contact.displayAbout ?? '',
                      fontSize: 12,
                      borderRadius: 8,
                    ),
                ],
              ),
            ),

            Expanded(
              child: SettingsList(
                platform: DevicePlatform.iOS,
                sections: [
                  SettingsSection(
                    tiles: [
                      SettingsTile(
                        leading: const Icon(Icons.person),
                        title: const Text('ID Key'),
                        value: Text(
                          getPublicKeyDisplay(
                            contact.npubkey,
                          ),
                        ),
                        onPressed: (context) {
                          Clipboard.setData(
                            ClipboardData(
                              text: contact.npubkey,
                            ),
                          );
                          EasyLoading.showSuccess('ID Key copied');
                        },
                      ),
                      if (kDebugMode)
                        SettingsTile(
                          leading: const Icon(Icons.copy),
                          title: const Text('Hex ID Key'),
                          value: Text(
                            getPublicKeyDisplay(
                              contact.pubkey,
                            ),
                          ),
                          onPressed: (context) {
                            Clipboard.setData(
                              ClipboardData(
                                text: contact.pubkey,
                              ),
                            );
                            EasyLoading.showSuccess('ID Key copied');
                          },
                        ),

                      if (Get.previousRoute != '/ShowContactDetail')
                        RoomUtil.fromContactClick(
                          contact.pubkey,
                          contact.identityId,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog() {
    Get.dialog(
      CupertinoAlertDialog(
        title: const Text('Delete this contact?'),
        actions: <Widget>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              Get.back<void>();
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              try {
                await ContactService.instance.deleteContactByPubkey(
                  contact.pubkey,
                  contact.identityId,
                );
                final room = await RoomService.instance.getRoomByIdentity(
                  contact.pubkey,
                  contact.identityId,
                );
                if (room != null) {
                  await RoomService.instance.deleteRoom(room);
                }
                await EasyLoading.showSuccess('Deleted');
                Get
                  ..back<void>()
                  ..back<bool>(result: true);
              } catch (e) {
                final msg = Utils.getErrorMessage(e);
                logger.e(msg, error: e, stackTrace: StackTrace.current);
                EasyLoading.showError('Error: $msg');
              }
            },
          ),
        ],
      ),
    );
  }
}
