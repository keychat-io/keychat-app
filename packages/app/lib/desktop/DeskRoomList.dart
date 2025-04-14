import 'package:app/desktop/DesktopController.dart';
import 'package:app/global.dart';
import 'package:app/models/room.dart';
import 'package:app/page/chat/chat_page.dart';
import 'package:app/page/chat/chat_setting_group_page.dart';
import 'package:app/page/chat/chat_settings_security.dart';
import 'package:app/page/chat/message_bill/pay_to_relay_page.dart';
import 'package:app/page/components.dart';
import 'package:app/page/room_list.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../page/chat/chat_setting_contact_page.dart';

class DeskRoomList extends GetView<DesktopController> {
  const DeskRoomList({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Obx(() =>
            SizedBox(width: controller.roomListWidth.value, child: RoomList())),
        MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              controller.setRoomListWidth(
                controller.roomListWidth.value + details.delta.dx,
              );
            },
            child: Container(
              width: 1,
              decoration: BoxDecoration(
                  border: Border(
                      right: BorderSide(
                          color: Theme.of(context).dividerColor.withAlpha(40),
                          width: 1))),
            ),
          ),
        ),
        Expanded(
            child: Navigator(
                key: Get.nestedKey(GetXNestKey.room),
                initialRoute: '/room',
                onGenerateRoute: (RouteSettings settings) {
                  if (settings.name == '/room') {
                    return GetPageRoute(
                        page: () => Center(
                            child: Padding(
                                padding: EdgeInsets.all(16),
                                child: textSmallGray(context,
                                    'Select a chat to start secure messaging',
                                    fontSize: 14))));
                  }

                  String route = settings.name!;

                  // Pattern 1: /room/:id
                  final roomPathRegex = RegExp(r'^\/room\/(\d+)$');
                  if (roomPathRegex.hasMatch(route)) {
                    final match = roomPathRegex.firstMatch(route);
                    int roomId = int.parse(match!.group(1)!);
                    late Room room;
                    try {
                      room = settings.arguments as Room;
                    } catch (e) {
                      room = (settings.arguments as Map)['room'] as Room;
                    }
                    return GetPageRoute(
                        transition: Transition.fadeIn,
                        page: () =>
                            ChatPage(key: ValueKey(roomId), room: room));
                  }

                  // Pattern 2: /room/:id/:method
                  final roomMethodRegex = RegExp(r'^\/room\/(\d+)\/(.+)$');
                  if (roomMethodRegex.hasMatch(route)) {
                    final match = roomMethodRegex.firstMatch(route);
                    int roomId = int.parse(match!.group(1)!);
                    String method = match.group(2)!;

                    late Widget pageWidget;
                    switch (method) {
                      case 'chat_setting_contact':
                        pageWidget = ChatSettingContactPage(roomId: roomId);
                        break;
                      case 'chat_setting_group':
                        pageWidget = ChatSettingGroupPage(roomId: roomId);
                        break;
                      case 'chat_setting_contact/security':
                        pageWidget = ChatSettingSecurity(roomId: roomId);
                        break;
                      case 'chat_setting_contact/pay_to_relay':
                        pageWidget = PayToRelayPage(roomId: roomId);
                        break;
                      default:
                        return null;
                    }

                    return GetPageRoute(
                      transition: Transition.rightToLeft,
                      page: () => pageWidget,
                    );
                  }

                  return null;
                })),
      ],
    );
  }
}
