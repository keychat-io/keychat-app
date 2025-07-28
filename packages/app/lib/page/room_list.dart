import 'package:app/app.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/desktop/DesktopController.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/new_friends_rooms.dart';
import 'package:app/page/search_page.dart';
import 'package:app/page/widgets/RelayStatus.dart';
import 'package:app/service/websocket.service.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

import 'RecommendBots/RecommendBots.dart';
import 'components.dart';

class RoomList extends GetView<HomeController> {
  const RoomList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          centerTitle: true,
          leadingWidth: 0,
          actions: [RelayStatus()],
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
                            indicatorColor: KeychatGlobal.primaryColor,
                            indicatorWeight: 1,
                            isScrollable: true,
                            controller: controller.tabController,
                            tabAlignment: TabAlignment.start,
                            labelStyle: const TextStyle(
                                color: KeychatGlobal.primaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                            dividerColor: Colors.transparent,
                            tabs:
                                controller.tabBodyDatas.values.map((TabData e) {
                              Identity identity = e.identity;
                              var title = identity.displayName.length > 15
                                  ? "${identity.displayName.substring(0, 15)}..."
                                  : identity.displayName;
                              return Tab(
                                  child: badges.Badge(
                                      showBadge: (e.unReadCount +
                                              e.anonymousUnReadCount) >
                                          0,
                                      position: badges.BadgePosition.topEnd(
                                          top: -10, end: -15),
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                            overflow: TextOverflow.ellipsis),
                                      )));
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

            return SmartRefresher(
                enablePullDown: true,
                header: const WaterDropHeader(),
                controller: controller.refreshControllers[identityId] ??
                    RefreshController(),
                onRefresh: () async {
                  // reconnect websocket
                  await Get.find<WebsocketService>().start();
                  controller.refreshControllers[identityId]?.refreshCompleted();
                },
                child: ListView.separated(
                  key: ObjectKey('roomlist_tab_$identityId'),
                  padding: const EdgeInsets.only(
                      bottom: kMinInteractiveDimension * 2),
                  separatorBuilder: (context, index) {
                    if (rooms[index] is Room) {
                      if (rooms[index].pin) {
                        return Container();
                      }
                      return Divider(
                          height: 0.1,
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.1),
                          indent: 80.0);
                    }
                    return Container();
                  },
                  itemCount: friendsCount,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      if (data.rooms.length > 4) {
                        return GestureDetector(
                          onTap: () {
                            Get.to(() => const SearchPage());
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: Get.isDarkMode
                                  ? const Color(0xFF202020)
                                  : const Color(0xFFEDEDED),
                            ),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(Icons.search,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.4))),
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
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    }
                    if (index == 1) {
                      return RecommendBots(
                          data.identity, List<Room>.from(rooms.sublist(4)));
                    }
                    if (index == 2) {
                      return getNewFriendsWidget(
                          data,
                          rooms[2] as List<Room>,
                          Get.isDarkMode
                              ? const Color(0xFF202020)
                              : const Color(0xFFEDEDED),
                          context);
                    }
                    if (index == 3) {
                      return getRequestingWidget(
                          data,
                          rooms[3] as List<Room>,
                          Get.isDarkMode
                              ? const Color(0xFF202020)
                              : const Color(0xFFEDEDED),
                          context);
                    }
                    Room room = rooms[index];
                    return InkWell(
                        key: ObjectKey('${index}_room${room.id}'),
                        onTap: () async {
                          await Utils.toNamedRoom(room);

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
                            color: room.pin
                                ? Get.isDarkMode
                                    ? const Color(0xFF202020)
                                    : const Color(0xFFEDEDED)
                                : Colors.transparent,
                            child: Obx(() => ListTile(
                                  contentPadding:
                                      EdgeInsets.only(left: 16, right: 16),
                                  leading: Utils.getAvatarDot(room),
                                  key: Key('room:${room.id}'),
                                  selected: Utils.getGetxController<
                                              DesktopController>()
                                          ?.selectedRoom
                                          .value
                                          .id ==
                                      room.id,
                                  selectedTileColor: KeychatGlobal.primaryColor
                                      .withValues(alpha: 200),
                                  title: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(room.getRoomName(),
                                          maxLines: 1,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      if (controller.roomLastMessage[room.id] !=
                                          null)
                                        Wrap(
                                          direction: Axis.horizontal,
                                          children: [
                                            textSmallGray(
                                                context,
                                                Utils.formatTimeMsg(controller
                                                    .roomLastMessage[room.id]!
                                                    .createdAt)),
                                            room.isMute
                                                ? Icon(
                                                    Icons
                                                        .notifications_off_outlined,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.6),
                                                    size: 16)
                                                : Container()
                                          ],
                                        ),
                                    ],
                                  ),
                                  subtitle: Obx(() =>
                                      RoomUtil.getSubtitleDisplay(
                                          room,
                                          messageExpired,
                                          controller.roomLastMessage[room.id])),
                                ))));
                  },
                ));
          }).toList())),
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
          title: Text('New Friends',
              style: Theme.of(context).textTheme.titleMedium),
          onTap: () async {
            await Get.bottomSheet(
                clipBehavior: Clip.antiAlias,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(4))),
                AnonymousRooms(rooms));
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
          title: Text('Requesting',
              style: Theme.of(context).textTheme.titleMedium),
          onTap: () async {
            await Get.bottomSheet(
                clipBehavior: Clip.antiAlias,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(4))),
                AnonymousRooms(rooms));
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
        Offset.zero & overlay.size);
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
