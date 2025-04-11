import 'package:app/desktop/DesktopController.dart';
import 'package:app/models/models.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/new_friends_rooms.dart';
import 'package:app/page/search_page.dart';
import 'package:app/page/setting/RelaySetting.dart';
import 'package:app/page/widgets/home_drop_menu.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';

import '../controller/home.controller.dart';
import 'RecommendBots/RecommendBots.dart';
import 'components.dart';

class RoomList extends GetView<HomeController> {
  const RoomList({super.key});

  @override
  Widget build(BuildContext context) {
    Color pinTileBackground =
        Get.isDarkMode ? const Color(0xFF202020) : const Color(0xFFEDEDED);
    DesktopController desktopController = Get.find<DesktopController>();
    Divider divider = Divider(
        height: 0.1,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        indent: 80.0);
    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          centerTitle: true,
          leadingWidth: 0,
          actions: [Obx(() => getRelaysStatus())],
          title: PreferredSize(
              preferredSize: const Size.fromHeight(0),
              child: SizedBox(
                  height: kToolbarHeight,
                  child: Obx(
                    () => Stack(
                      alignment: controller.tabBodyDatas.length == 1
                          ? Alignment.center
                          : Alignment.bottomCenter,
                      children: <Widget>[
                        TabBar(
                            indicatorColor:
                                Theme.of(context).colorScheme.primary,
                            indicatorWeight: 1,
                            isScrollable: true,
                            controller: controller.tabController,
                            tabAlignment: TabAlignment.start,
                            labelStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                            dividerColor: Colors.transparent,
                            tabs:
                                controller.tabBodyDatas.values.map((TabData e) {
                              Identity identity = e.identity;
                              var title = identity.displayName.length > 15
                                  ? "${identity.displayName.substring(0, 15)}..."
                                  : identity.displayName;
                              return Tab(
                                  child: badges.Badge(
                                showBadge:
                                    (e.unReadCount + e.anonymousUnReadCount) >
                                        0,
                                position: badges.BadgePosition.topEnd(
                                    top: -10, end: -15),
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ));
                            }).toList()),
                      ],
                    ),
                  )))),
      body: Obx(() => TabBarView(
          key: GlobalObjectKey('roomlist_tabview'),
          controller: controller.tabController,
          children: controller.tabBodyDatas.keys.map((identityId) {
            TabData data = controller.tabBodyDatas[identityId]!;
            int friendsCount = data.rooms.length;
            List rooms = data.rooms;
            DateTime messageExpired =
                DateTime.now().subtract(const Duration(seconds: 5));
            return ListView.separated(
                key: ObjectKey('roomlist_tab_$identityId'),
                padding:
                    const EdgeInsets.only(bottom: kMinInteractiveDimension * 2),
                separatorBuilder: (context, index) {
                  if (rooms[index] is Room) {
                    if (rooms[index].pin) {
                      return Container();
                    }
                    return divider;
                  }
                  return Container();
                },
                itemCount: friendsCount,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    if (data.rooms.length > 4) {
                      return getSearchWidget(context, pinTileBackground);
                    }
                    return const SizedBox();
                  }
                  if (index == 1) {
                    return RecommendBots(
                        data.identity, List<Room>.from(rooms.sublist(4)));
                  }
                  if (index == 2) {
                    return getNewFriendsWidget(data, rooms[2] as List<Room>,
                        pinTileBackground, context);
                  }
                  if (index == 3) {
                    return getRequestingWidget(data, rooms[3] as List<Room>,
                        pinTileBackground, context);
                  }
                  Room room = rooms[index];
                  return InkWell(
                      key: ObjectKey('${index}_room${room.id}'),
                      onTap: () async {
                        if (GetPlatform.isDesktop) {
                          Get.find<DesktopController>().selectedRoom.value =
                              room;
                        } else {
                          await Utils.toNamedRoom(room);
                        }

                        RoomService.instance.markAllRead(
                            identityId: room.identityId, roomId: room.id);
                        controller.resortRoomList(room.identityId);
                      },
                      onSecondaryTapDown: (e) {
                        onSecondaryTapDown(e, room, context);
                      },
                      onLongPress: () =>
                          RoomUtil.showRoomActionSheet(context, room),
                      child: Container(
                          color:
                              room.pin ? pinTileBackground : Colors.transparent,
                          child: Obx(() => ListTile(
                                contentPadding:
                                    EdgeInsets.only(left: 16, right: 16),
                                leading: Utils.getAvatarDot(room),
                                key: Key('room:${room.id}'),
                                selected:
                                    desktopController.selectedRoom.value.id ==
                                        room.id,
                                selectedTileColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 200),
                                title: Text(room.getRoomName(),
                                    maxLines: 1,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                subtitle: Obx(() => RoomUtil.getSubtitleDisplay(
                                    room,
                                    messageExpired,
                                    controller.roomLastMessage[room.id])),
                                trailing: controller.roomLastMessage[room.id] ==
                                        null
                                    ? null
                                    : Wrap(
                                        direction: Axis.vertical,
                                        alignment: WrapAlignment.center,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.end,
                                        children: [
                                          textSmallGray(
                                              Get.context!,
                                              Utils.formatTimeMsg(controller
                                                  .roomLastMessage[room.id]!
                                                  .createdAt)),
                                          room.isMute
                                              ? Icon(
                                                  Icons
                                                      .notifications_off_outlined,
                                                  color: Theme.of(Get.context!)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.6),
                                                  size: 16,
                                                )
                                              : Container()
                                        ],
                                      ),
                              ))));
                });
          }).toList())),
    );
  }

  GestureDetector getSearchWidget(
      BuildContext context, Color pinTileBackground) {
    return GestureDetector(
      onTap: () {
        Get.to(() => const SearchPage());
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(0),
          color: pinTileBackground,
        ),
        margin: const EdgeInsets.only(top: 0, bottom: 2),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Icon(Icons.search,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4)),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  Widget getNewFriendsWidget(TabData data, List<Room> rooms,
      Color pinTileBackground, BuildContext context) {
    if (rooms.isEmpty) return Container();
    return Container(
        color: pinTileBackground,
        child: ListTile(
          key: const Key('room:anonymous'),
          leading: badges.Badge(
            showBadge: data.anonymousUnReadCount > 0,
            badgeContent: Text(
              data.anonymousUnReadCount.toString(),
              style: const TextStyle(color: Colors.white),
            ),
            badgeAnimation: const badges.BadgeAnimation.fade(toAnimate: false),
            position: badges.BadgePosition.topEnd(top: -8, end: -5),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: const Icon(
                CupertinoIcons.person_badge_plus_fill,
                size: 26,
              ),
            ),
          ),
          title: Text(
            'New Friends',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          onTap: () async {
            await Get.bottomSheet(AnonymousRooms(rooms));
            controller.loadRoomList();
          },
          subtitle: Text('Rooms: ${rooms.length}'),
          trailing: Icon(CupertinoIcons.right_chevron,
              size: 20,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4)),
        ));
  }

  Widget getRequestingWidget(TabData data, List<Room> rooms,
      Color pinTileBackground, BuildContext context) {
    if (rooms.isEmpty) return Container();

    return Container(
        color: pinTileBackground,
        child: ListTile(
          key: const Key('room:requesting'),
          leading: badges.Badge(
              showBadge: rooms.isNotEmpty,
              badgeContent: Text(rooms.length.toString(),
                  style: const TextStyle(color: Colors.white)),
              position: badges.BadgePosition.topEnd(top: -8, end: -5),
              child: CircleAvatar(
                  radius: 26,
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  child: const Icon(CupertinoIcons.person_badge_plus_fill,
                      size: 26))),
          title: Text(
            'Requesting',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          onTap: () async {
            await Get.bottomSheet(AnonymousRooms(rooms));
            controller.loadRoomList();
          },
          subtitle: Text('Rooms: ${rooms.length}'),
          trailing: Icon(CupertinoIcons.right_chevron,
              size: 20,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4)),
        ));
  }

  Widget getRelaysStatus() {
    WebsocketService webSocketService = Get.find<WebsocketService>();
    String status = webSocketService.relayStatusInt.value;
    if (!controller.isConnectedNetwork.value) {
      status = RelayStatusEnum.noNetwork.name;
    }

    switch (status) {
      case 'connecting':
        return SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            color: Colors.black,
            icon: SpinKitDoubleBounce(
              color: Colors.amber.shade200,
              size: 22.0,
              duration: const Duration(milliseconds: 4000),
            ),
            onPressed: () {
              _showDialogForReconnect(false, "Relays connecting");
              // EasyLoading.showToast('Relays connecting, please wait...');
            },
          ),
        );
      case 'noAcitveRelay':
      case 'allFailed':
      case 'noNetwork':
        return SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(
                Icons.error,
                color: Colors.red.shade400,
              ),
              onPressed: () {
                String message =
                    'All relays connecting error, please check network';
                if (status == 'noAcitveRelay') {
                  message = 'No any enable relay, please check the config';
                }
                _showDialogForReconnect(false, message);
              },
            ));
      default:
    }
    return GestureDetector(
        onLongPress: () {
          Get.to(() => const RelaySetting());
        },
        child: badges.Badge(
            showBadge: controller.addFriendTips.value,
            position: badges.BadgePosition.topEnd(top: 5, end: 5),
            child: HomeDropMenuWidget(controller.addFriendTips.value)));
  }

  _showDialogForReconnect(bool status, String message) {
    Get.dialog(CupertinoAlertDialog(
      title: status
          ? const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 34,
            )
          : const Icon(
              Icons.error,
              color: Colors.red,
              size: 34,
            ),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          child: const Text("Cancel"),
          onPressed: () async {
            Get.back();
          },
        ),
        CupertinoDialogAction(
          isDefaultAction: status,
          onPressed: () async {
            Get.find<WebsocketService>().init();
            EasyLoading.showToast('Relays connecting, please wait...');
            Get.back();
          },
          child: const Text("Reconnect"),
        ),
      ],
    ));
  }

  void onSecondaryTapDown(TapDownDetails e, Room room, BuildContext context) {
    if (!GetPlatform.isDesktop) {
      return;
    }
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        e.globalPosition,
        e.globalPosition,
      ),
      Offset.zero & overlay.size,
    );
    showMenu(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(value: 'read', child: Text('Make as Read')),
        PopupMenuItem(value: 'pin', child: Text(room.pin ? 'Unpin' : 'Pin')),
        PopupMenuItem(
            value: 'mute', child: Text(room.isMute ? 'Unmute' : 'Mute')),
      ],
    ).then((value) async {
      switch (value) {
        case 'pin':
          room.pin = !room.pin;
          room.pinAt = DateTime.now();
          await RoomService.instance.updateRoomAndRefresh(room);
          await controller.loadIdentityRoomList(room.identityId);
          break;
        case 'mute':
          await RoomService.instance.mute(room, !room.isMute);
          break;
        case 'read':
          await RoomService.instance
              .markAllRead(identityId: room.identityId, roomId: room.id);
          controller.resortRoomList(room.identityId);
          break;
        default:
      }
    });
  }
}
