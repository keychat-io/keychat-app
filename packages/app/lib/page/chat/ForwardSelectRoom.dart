import 'package:app/controller/home.controller.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/room.dart';
import 'package:app/page/browser/SelectIdentityForward.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ForwardSelectRoom extends StatefulWidget {
  final String message;
  final Identity identity;
  const ForwardSelectRoom(this.message, this.identity, {super.key});

  @override
  _ForwardSelectRoomState createState() => _ForwardSelectRoomState();
}

class _ForwardSelectRoomState extends State<ForwardSelectRoom> {
  List<Room> rooms = [];
  Color pinTileBackground =
      Get.isDarkMode ? const Color(0xFF202020) : const Color(0xFFEDEDED);
  late TextEditingController _searchController;
  Set<Room> selectedRooms = {};
  late Identity selectedIdentity;
  @override
  void initState() {
    selectedIdentity = widget.identity;
    _searchController = TextEditingController();
    init(selectedIdentity);
    super.initState();
  }

  init(Identity identity) {
    List<Room> res = Get.find<HomeController>().getRoomsByIdentity(identity.id);
    setState(() {
      selectedIdentity = identity;
      rooms = res;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    HomeController homeController = Get.find<HomeController>();
    var divider = Divider(
        height: 1,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.05));
    var divider2 = Divider(
        height: 0.3, color: Colors.grey.shade100.withValues(alpha: 0.01));
    DateTime messageExpired =
        DateTime.now().subtract(const Duration(seconds: 5));
    return Scaffold(
        appBar: AppBar(
          leading: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Icon(Icons.close),
          ),
          title: const Text('Select to Forward'),
          actions: [
            TextButton.icon(
                onPressed: () async {
                  Identity? selected = await Get.bottomSheet(
                      const SelectIdentityForward('Select a Identity'));
                  if (selected == null) return;
                  init(selected);
                },
                icon: const Icon(Icons.swap_horiz),
                label: Text(selectedIdentity.displayName))
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FilledButton(
            onPressed: () {
              Get.back(result: selectedRooms.toList());
            },
            child: const Text('Send')),
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
                            init(selectedIdentity);
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  if (value.isEmpty) return;

                  List<Room> filters = rooms
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
                  bool isSelected = selectedRooms.contains(room);

                  return ListTile(
                    leading: Utils.getAvatarDot(room, width: 40),
                    dense: true,
                    key: Key('room:${room.id}'),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedRooms.remove(room);
                        } else {
                          selectedRooms.add(room);
                        }
                      });
                    },
                    title: Text(room.getRoomName(),
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Obx(() => RoomUtil.getSubtitleDisplay(
                        room,
                        messageExpired,
                        homeController.roomLastMessage[room.id])),
                    trailing: isSelected
                        ? const Icon(Icons.check_box)
                        : const Icon(Icons.check_box_outline_blank),
                  );
                }),
          )
        ]));
  }
}
