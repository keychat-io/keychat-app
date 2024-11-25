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

import './ContactDetail_controller.dart';

String defaultAvatar = "assets/images/logo.png";

class ContactDetailPage extends StatelessWidget {
  final Contact contact;
  const ContactDetailPage(this.contact, {super.key});

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
          color: Colors.white.withOpacity(0.4),
          alignment: Alignment.center,
          child: child,
        ));
  }

  @override
  Widget build(BuildContext context) {
    ContactDetailController controller =
        Get.put(ContactDetailController(contact));
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Obx(() => avatarSection2(
                getRandomAvatar(controller.contact.value.pubkey,
                    fit: BoxFit.contain,
                    height: double.infinity,
                    width: double.infinity),
                Column(
                  children: [
                    AppBar(backgroundColor: Colors.transparent),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        getRandomAvatar(controller.contact.value.pubkey,
                            height: 60, width: 60),
                        Text(
                          controller.contact.value.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(height: 2, color: Colors.black87),
                        ),
                        // ElevatedButton(
                        //     onPressed: () async {
                        //       Room room = await RoomService.instance
                        //           .getRoomByContact(controller.contact.value);
                        //       Get.offAndToNamed('/room/${room.id}',
                        //           arguments: room);
                        //     },
                        //     child: const Text('Send message'))
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
                            title: const Text("ID Key"),
                            value: Text(getPublicKeyDisplay(
                                controller.contact.value.npubkey, 6)),
                            onPressed: (context) {
                              Clipboard.setData(ClipboardData(
                                  text: controller.contact.value.npubkey));
                              EasyLoading.showSuccess("ID Key copied");
                            },
                          ),
                          if (kDebugMode)
                            SettingsTile(
                              leading: const Icon(Icons.copy),
                              title: const Text("Hex ID Key"),
                              value: Text(getPublicKeyDisplay(
                                  controller.contact.value.pubkey, 6)),
                              onPressed: (context) {
                                Clipboard.setData(ClipboardData(
                                    text: controller.contact.value.pubkey));
                                EasyLoading.showSuccess("ID Key copied");
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
    );
  }

  Future handleUpdateContact(
      ContactDetailController controller, Contact contact) async {
    controller.contact.value = contact;
    await ContactService.instance.saveContact(controller.contact.value);
    controller.contact.refresh();
    Room? room = await RoomService.instance
        .getRoomByIdentity(contact.pubkey, contact.identityId);
    if (room != null) {
      ChatController? cc = RoomService.getController(room.id);
      if (cc != null) {
        cc.roomContact.value = contact;
        cc.roomContact.refresh();
      }
    }
    EasyLoading.showSuccess("Updated");
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
              title: const Text("Delete chat?"),
              actions: <Widget>[
                CupertinoDialogAction(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Get.back();
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
                        Get.back();
                        Get.back(result: false);
                      } catch (e) {
                        String msg = Utils.getErrorMessage(e);
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

  Future _showContactNameDialog(
      ContactDetailController controller, String preRoomName) async {
    await Get.dialog(CupertinoAlertDialog(
      title: const Text("Name"),
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
          child: const Text("Cancel"),
          onPressed: () {
            Get.back();
          },
        ),
        CupertinoDialogAction(
          child: const Text("Confirm"),
          onPressed: () async {
            await handleUpdateName(controller);
          },
        ),
      ],
    ));
  }

  Future handleUpdateName(ContactDetailController controller) async {
    if (controller.usernameController.text.isEmpty) return;
    Contact contact0 = controller.contact.value;
    contact0.petname = controller.usernameController.text.trim();
    int id = await ContactService.instance.saveContact(contact0);
    Contact? contact = await ContactService.instance.getContactById(id);
    await handleUpdateContact(controller, contact!);
    Get.back();
  }
}
