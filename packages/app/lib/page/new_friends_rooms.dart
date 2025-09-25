import 'package:app/controller/home.controller.dart';
import 'package:app/models/room.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/components.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AnonymousRooms extends StatefulWidget {
  const AnonymousRooms(this.rooms, {super.key});
  final List<Room> rooms;

  @override
  _AnonymousRoomsState createState() => _AnonymousRoomsState();
}

class _AnonymousRoomsState extends State<AnonymousRooms> {
  List<Room> list = [];
  @override
  void initState() {
    setState(() {
      list = RoomUtil.sortRoomList(widget.rooms);
    });
    super.initState();
  }

  void _updateRoom(Room room) {
    final newList = <Room>[];
    for (var r in list) {
      if (r.id == room.id) {
        r = room;
      }
      newList.add(r);
    }
    setState(() {
      list = newList;
    });
  }

  void _removeRoom(Room room) {
    final newList = <Room>[];
    for (final r in list) {
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
    final messageExpired = DateTime.now().subtract(const Duration(seconds: 5));
    final homeController = Get.find<HomeController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Friends'),
      ),
      body: SafeArea(
        child: ListView.separated(
          separatorBuilder: (context2, index) => Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final room = list[index];
            return ListTile(
              leading: Utils.getAvatarByRoom(room),
              key: Key('room:${room.id}'),
              onLongPress: () async {
                await RoomUtil.showRoomActionSheet(
                  context,
                  room,
                  onDeleteHistory: () {
                    homeController.roomLastMessage[room.id] = null;
                    _updateRoom(room);
                  },
                  onDeletRoom: () {
                    _removeRoom(room);
                  },
                );
              },
              onTap: () async {
                room.unReadCount = 0;
                _updateRoom(room);
                if (list.length == 1) {
                  await Utils.offAndToNamedRoom(room);
                  return;
                }
                await Utils.toNamedRoom(room);
              },
              title: Text(
                room.getRoomName(),
                maxLines: 1,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: RoomUtil.getSubtitleDisplay(
                context,
                room,
                messageExpired,
                homeController.roomLastMessage[room.id],
              ),
              trailing:
                  homeController.roomLastMessage[room.id]?.createdAt != null
                      ? textSmallGray(
                          context,
                          Utils.formatTimeMsg(
                            homeController.roomLastMessage[room.id]!.createdAt,
                          ),
                        )
                      : null,
            );
          },
        ),
      ),
    );
  }
}
