import 'package:app/controller/home.controller.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/message.dart';
import 'package:app/models/room.dart';
import 'package:app/service/room.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';

class UnreadMessages extends StatefulWidget {
  const UnreadMessages({super.key});

  @override
  _UnreadMessagesState createState() => _UnreadMessagesState();
}

class _UnreadMessagesState extends State<UnreadMessages> {
  List<Message> messages = [];
  Map<int, Room> roomMap = {};

  @override
  void initState() {
    super.initState();
    getUnreadMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Unread Messages'),
          actions: [
            TextButton(
                onPressed: () async {
                  await DBProvider.database.writeTxn(() async {
                    for (var m in messages) {
                      m.isRead = true;
                      await DBProvider.database.messages.put(m);
                    }
                  });
                  EasyLoading.showSuccess('Marked as read');
                  Get.find<HomeController>().loadRoomList();
                  getUnreadMessages();
                },
                child: const Text('Clear'))
          ],
        ),
        body: ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              int roomId = messages[index].roomId;
              return ListTile(
                leading: CircleAvatar(
                  child: Text('$roomId'),
                ),
                title: Text(
                    '${roomMap[roomId]?.getRoomName() ?? roomId.toString()}: ${messages[index].content}'),
                subtitle: Text(
                    '${messages[index].createdAt} ${messages[index].realMessage ?? ""}'),
                onTap: () {},
              );
            }));
  }

  getUnreadMessages() async {
    List<Message> ms = await DBProvider.database.messages
        .filter()
        .isReadEqualTo(false)
        .findAll();
    Map<int, Room> map = {};

    for (var m in ms) {
      if (!map.containsKey(m.roomId)) {
        Room? room = await RoomService().getRoomById(m.roomId);
        if (room != null) {
          map[m.roomId] = room;
        }
      }
    }
    setState(() {
      messages = ms;
      roomMap = map;
    });
  }
}
