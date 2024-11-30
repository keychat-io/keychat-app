import 'package:app/models/room.dart';
import 'package:app/page/common.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ForwardSelectRoom extends StatefulWidget {
  final List<Room> rooms;
  final String message;
  final String title;
  const ForwardSelectRoom(this.rooms, this.message, this.title, {super.key});

  @override
  _ForwardSelectRoomState createState() => _ForwardSelectRoomState();
}

class _ForwardSelectRoomState extends State<ForwardSelectRoom> {
  List<Room> rooms = [];
  Color pinTileBackground =
      Get.isDarkMode ? const Color(0xFF202020) : const Color(0xFFEDEDED);
  late TextEditingController _searchController;

  @override
  void initState() {
    _searchController = TextEditingController();
    setState(() {
      rooms = widget.rooms;
    });
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var divider = Divider(
      height: 1,
      color: Theme.of(context).dividerColor.withOpacity(0.05),
    );
    var divider2 = Divider(
      height: 0.3,
      color: Colors.grey.shade100.withOpacity(0.01),
    );
    return Scaffold(
        appBar: AppBar(
          leading: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Icon(Icons.close),
          ),
          title: Text(widget.title),
        ),
        body: Column(children: <Widget>[
          Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search',
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              rooms = widget.rooms;
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  if (value.isEmpty) return;

                  List<Room> filters = widget.rooms
                      .where((item) => item
                          .getRoomName()
                          .toLowerCase()
                          .contains(_searchController.text.toLowerCase()))
                      .toList();
                  setState(() {
                    rooms = filters;
                  });
                },
              )),
          Expanded(
            child: ListView.separated(
                padding:
                    const EdgeInsets.only(bottom: kMinInteractiveDimension * 2),
                separatorBuilder: (context, index) {
                  if (rooms[index].pin) {
                    return divider2;
                  }
                  return divider;
                },
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  Room room = rooms[index];
                  return ListTile(
                    leading: getAvatarDot(room, width: 40),
                    dense: false,
                    key: Key('room:${room.id}'),
                    onTap: () => {
                      Get.dialog(CupertinoAlertDialog(
                        title: Text('SendTo: ${room.getRoomName()}'),
                        content: Text(widget.message, maxLines: 10),
                        actions: <Widget>[
                          CupertinoDialogAction(
                            child: const Text('Cancel'),
                            onPressed: () {
                              Get.back();
                            },
                          ),
                          CupertinoDialogAction(
                            isDefaultAction: true,
                            child: const Text('Send'),
                            onPressed: () {
                              Get.back();
                              Get.back(result: room);
                            },
                          ),
                        ],
                      ))
                    },
                    title: Text(
                      room.getRoomName(),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                }),
          )
        ]));
  }
}
