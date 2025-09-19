import 'dart:ui' show ImageFilter;

import 'package:app/controller/chat.controller.dart';
import 'package:app/models/contact.dart';
import 'package:app/models/room.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';

import 'package:app/page/contact/ContactDetail/ContactDetail_controller.dart';

class ContactDetailPage extends StatelessWidget {
  const ContactDetailPage(this.contact, {super.key});
  final Contact contact;

  SizedBox avatarSection(String url, Widget child) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            url,
            fit: BoxFit.fitWidth,
            width: double.infinity,
          ),
          ClipRect(child: buildBackdropFilter(child)),
        ],
      ),
    );
  }

  SizedBox avatarSection2(Widget main, Widget child) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          main,
          ClipRect(
            child: buildBackdropFilter(child),
          ),
        ],
      ),
    );
  }

  BackdropFilter buildBackdropFilter(Widget child) {
    return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 20,
          sigmaY: 20,
        ),
        child: Container(
          color: Colors.white.withValues(alpha: 0.4),
          alignment: Alignment.center,
          child: child,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ContactDetailController(contact));
    return SafeArea(
        child: Scaffold(
      body: Column(
        children: [
          Obx(() => avatarSection2(
                Utils.getRandomAvatar(controller.contact.value.pubkey,
                    httpAvatar: controller.contact.value.avatarFromRelay),
                Column(
                  children: [
                    AppBar(backgroundColor: Colors.transparent),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Utils.getRandomAvatar(controller.contact.value.pubkey,
                            httpAvatar:
                                controller.contact.value.avatarFromRelay,
                            height: 60,
                            width: 60),
                        Text(
                          controller.contact.value.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(height: 2, color: Colors.black87),
                        ),
                      ],
                    )
                  ],
                ),
              )),
          Expanded(
              child: Obx(() => SettingsList(
                      // shrinkWrap: true,
                      platform: DevicePlatform.iOS,
                      sections: [
                        SettingsSection(tiles: [
                          SettingsTile(
                            leading: const Icon(Icons.copy),
                            title: const Text('ID Key'),
                            value: Text(getPublicKeyDisplay(
                                controller.contact.value.npubkey)),
                            onPressed: (context) {
                              Clipboard.setData(ClipboardData(
                                  text: controller.contact.value.npubkey));
                              EasyLoading.showSuccess('ID Key copied');
                            },
                          ),
                          if (kDebugMode)
                            SettingsTile(
                              leading: const Icon(Icons.copy),
                              title: const Text('Hex ID Key'),
                              value: Text(getPublicKeyDisplay(
                                  controller.contact.value.pubkey)),
                              onPressed: (context) {
                                Clipboard.setData(ClipboardData(
                                    text: controller.contact.value.pubkey));
                                EasyLoading.showSuccess('ID Key copied');
                              },
                            ),
                          // SettingsTile(
                          //   title: const Text('Nickname'),
                          //   leading:
                          //       const Icon(CupertinoIcons.person_alt_circle),
                          //   value: Text(controller.contact.value.name ?? ''),
                          // ),
                          SettingsTile.navigation(
                            title: const Text('Nickname'),
                            leading: const Icon(CupertinoIcons.pencil),
                            value: Text(controller.contact.value.petname ?? ''),
                            onPressed: (context) async {
                              await _showContactNameDialog(controller,
                                  controller.contact.value.petname ?? '');
                            },
                          ),
                          if (Get.previousRoute != '/ShowContactDetail')
                            RoomUtil.fromContactClick(
                                controller.contact.value.pubkey,
                                controller.contact.value.identityId),
                        ]),
                        dangerZoom(controller)
                      ]))),
        ],
      ),
    ));
  }

  Future<void> handleUpdateContact(
      ContactDetailController controller, Contact contact) async {
    controller.contact.value = contact;
    await ContactService.instance.saveContact(controller.contact.value);
    controller.contact.refresh();
    final room = await RoomService.instance
        .getRoomByIdentity(contact.pubkey, contact.identityId);
    if (room != null) {
      final cc = RoomService.getController(room.id);
      if (cc != null) {
        cc.roomContact.value = contact;
        cc.roomContact.refresh();
      }
    }
    EasyLoading.showSuccess('Updated');
  }

  SettingsSection dangerZoom(ContactDetailController controller) {
    return SettingsSection(
      tiles: [
        SettingsTile(
          leading: const Icon(CupertinoIcons.trash, color: Colors.red),
          title:
              const Text('Delete Contact', style: TextStyle(color: Colors.red)),
          onPressed: (context) async {
            Get.dialog(CupertinoAlertDialog(
              title: const Text('Delete chat?'),
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
                        await RoomService.instance.deleteRoomHandler(
                            controller.contact.value.pubkey,
                            controller.contact.value.identityId);
                        EasyLoading.showSuccess('Deleted');
                        Get.back<void>();
                        Get.back(result: false);
                      } catch (e) {
                        final msg = Utils.getErrorMessage(e);
                        logger.e(msg, error: e, stackTrace: StackTrace.current);
                        EasyLoading.showError('Error: $msg');
                      }
                    }),
              ],
            ));
          },
        ),
      ],
    );
  }

  Future<void> _showContactNameDialog(
      ContactDetailController controller, String preRoomName) async {
    await Get.dialog(CupertinoAlertDialog(
      title: const Text('Name'),
      content: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(top: 15),
        child: TextField(
          controller: controller.usernameController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => handleUpdateName(controller),
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: <Widget>[
        CupertinoDialogAction(
          child: const Text('Cancel'),
          onPressed: () {
            Get.back<void>();
          },
        ),
        CupertinoDialogAction(
          child: const Text('Confirm'),
          onPressed: () async {
            await handleUpdateName(controller);
          },
        ),
      ],
    ));
  }

  Future<void> handleUpdateName(ContactDetailController controller) async {
    if (controller.usernameController.text.isEmpty) return;
    final contact0 = controller.contact.value;
    contact0.petname = controller.usernameController.text.trim();
    final id = await ContactService.instance.saveContact(contact0);
    final contact = await ContactService.instance.getContactById(id);
    await handleUpdateContact(controller, contact!);
    Get.back<void>();
  }
}
