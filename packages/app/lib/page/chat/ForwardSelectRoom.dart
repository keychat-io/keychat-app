import 'package:app/app.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/page/browser/SelectIdentityForward.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/components.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ForwardSelectRoom extends StatefulWidget {
  final String message;
  final Identity identity;
  final bool showContent;
  const ForwardSelectRoom(this.message, this.identity,
      {super.key, this.showContent = true});

  @override
  _ForwardSelectRoomState createState() => _ForwardSelectRoomState();
}

class _ForwardSelectRoomState extends State<ForwardSelectRoom> {
  List<Room> rooms = [];
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

  void init(Identity identity) {
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
                      clipBehavior: Clip.antiAlias,
                      shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(4))),
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
          if (widget.message.isNotEmpty && widget.showContent)
            Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: textSmallGray(context, widget.message,
                    maxLines: 3, overflow: TextOverflow.ellipsis)),
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
                    return Divider(
                        height: 0.3,
                        color: Colors.grey.shade100.withValues(alpha: 0.01));
                  }
                  return Divider(
                      height: 1,
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.05));
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
                        context,
                        room,
                        messageExpired,
                        homeController.roomLastMessage[room.id])),
                    trailing: isSelected
                        ? const Icon(Icons.check_box,
                            color: KeychatGlobal.secondaryColor)
                        : const Icon(Icons.check_box_outline_blank),
                  );
                }),
          )
        ]));
  }
}
