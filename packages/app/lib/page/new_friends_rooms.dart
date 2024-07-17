import 'package:app/models/room.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/common.dart';
import 'package:app/page/components.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AnonymousRooms extends StatefulWidget {
  final List<Room> rooms;
  const AnonymousRooms(this.rooms, {super.key});

  @override
  _AnonymousRoomsState createState() => _AnonymousRoomsState();
}

class _AnonymousRoomsState extends State<AnonymousRooms> {
  List<Room> list = [];
  @override
  void initState() {
    setState(() {
      list = widget.rooms;
    });
    super.initState();
  }

  _updateRoom(Room room) {
    List<Room> newList = [];
    for (Room r in list) {
      if (r.id == room.id) {
        r = room;
      }
      newList.add(r);
    }
    setState(() {
      list = newList;
    });
  }

  _removeRoom(Room room) {
    List<Room> newList = [];
    for (Room r in list) {
      if (r.id != room.id) {
        newList.add(r);
      }
    }
    setState(() {
      list = newList;
    });
  }

  @override
  Widget build(BuildContext context) {
    DateTime messageExpired =
        DateTime.now().subtract(const Duration(seconds: 5));
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Friends'),
      ),
      body: SafeArea(
          child: ListView.separated(
              separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor.withOpacity(0.05),
                  ),
              itemCount: list.length,
              itemBuilder: (context, index) {
                Room room = list[index];
                return ListTile(
                  leading: getAvatarDot(room),
                  key: Key('room:${room.id}'),
                  onLongPress: () async {
                    await RoomUtil.showRoomActionSheet(context, room,
                        onDeleteHistory: () {
                      room.lastMessageModel = null;
                      _updateRoom(room);
                    }, onDeletRoom: () {
                      _removeRoom(room);
                    });
                  },
                  onTap: () async {
                    room.unReadCount = 0;
                    _updateRoom(room);
                    if (list.length == 1) {
                      await Get.offAndToNamed('/room/${room.id}',
                          arguments: room);
                      return;
                    }
                    await Get.toNamed('/room/${room.id}', arguments: room);
                  },
                  title: Text(
                    room.getRoomName(),
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: RoomUtil.getSubtitleDisplay(room, messageExpired),
                  trailing: room.lastMessageModel?.createdAt != null
                      ? textSmallGray(Get.context!,
                          formatTimeMsg(room.lastMessageModel!.createdAt))
                      : null,
                );
              })),
    );
  }
}
