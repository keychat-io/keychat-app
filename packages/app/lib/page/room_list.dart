import 'dart:io' show exit;

import 'package:app/models/models.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/common.dart';
import 'package:app/page/new_friends_rooms.dart';
import 'package:app/page/routes.dart';
import 'package:app/page/search_page.dart';
import 'package:app/page/widgets/home_drop_menu.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../controller/home.controller.dart';
import 'components.dart';

class RoomList extends StatefulWidget {
  const RoomList({super.key});
  @override
  _MyListViewState createState() => _MyListViewState();
}

class _MyListViewState extends State<RoomList> {
  GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>(debugLabel: 'home');
  HomeController homeController = Get.find<HomeController>();

  @override
  void initState() {
    super.initState();
    if (GetPlatform.isDesktop) {
      WakelockPlus.enable();
    }
  }

  @override
  void dispose() {
    if (GetPlatform.isDesktop) {
      WakelockPlus.disable();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color pinTileBackground =
        Get.isDarkMode ? const Color(0xFF202020) : const Color(0xFFEDEDED);

    Divider divider = Divider(
        height: 0.1,
        color: Theme.of(context).dividerColor.withOpacity(0.1),
        indent: 80.0);
    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          centerTitle: true,
          leadingWidth: 0,
          actions: [Obx(() => getRelaysStatus(homeController))],
          title: PreferredSize(
              preferredSize: const Size.fromHeight(0),
              child: SizedBox(
                  height: kToolbarHeight,
                  child: Obx(
                    () => Stack(
                      alignment: homeController.tabBodyDatas.length == 1
                          ? Alignment.center
                          : Alignment.bottomCenter,
                      children: <Widget>[
                        homeController.tabBodyDatas.length == 1
                            ? const Row(
                                children: [
                                  Text(
                                    '  Keychat',
                                    style: TextStyle(
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              )
                            : TabBar(
                                indicatorColor:
                                    Theme.of(context).colorScheme.primary,
                                indicatorWeight: 1,
                                isScrollable: true,
                                controller: homeController.tabController,
                                tabAlignment: TabAlignment.start,
                                labelStyle: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                                dividerColor: Colors.transparent,
                                tabs: homeController.tabBodyDatas.values
                                    .map((TabData e) {
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
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ));
                                }).toList()),
                      ],
                    ),
                  )))),
      key: scaffoldKey,
      body: Obx(() => TabBarView(
          key: const Key('roomlistTabview'),
          controller: homeController.tabController,
          children: homeController.tabBodyDatas.keys.map((identityId) {
            TabData data = homeController.tabBodyDatas[identityId]!;
            int friendsCount = data.rooms.length;
            List rooms = data.rooms;
            DateTime messageExpired =
                DateTime.now().subtract(const Duration(seconds: 5));
            return rooms.length == 3 &&
                    rooms[1].length == 0 &&
                    rooms[2].length == 0
                ? _noRoomsView(context, homeController, data.identity)
                : ListView.separated(
                    key: PageStorageKey('roomlist_tab_$identityId'),
                    padding: const EdgeInsets.only(
                        bottom: kMinInteractiveDimension * 2),
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
                        return getSearchWidget(pinTileBackground);
                      }
                      if (index == 1) {
                        return getNewFriendsWidget(data, rooms[1] as List<Room>,
                            pinTileBackground, context);
                      }
                      if (index == 2) {
                        return getRequestingWidget(data, rooms[2] as List<Room>,
                            pinTileBackground, context);
                      }
                      Room room = rooms[index];
                      return GestureDetector(
                          key: PageStorageKey('${index}_room${room.id}'),
                          onTap: () async {
                            await Get.toNamed('/room/${room.id}',
                                arguments: room);

                            RoomService().markAllRead(
                                identityId: room.identityId, roomId: room.id);
                          },
                          onLongPress: () =>
                              RoomUtil.showRoomActionSheet(context, room),
                          child: Container(
                              color: room.pin
                                  ? pinTileBackground
                                  : Colors.transparent,
                              child: ListTile(
                                leading: getAvatarDot(room),
                                key: Key('room:${room.id}'),
                                title: Text(
                                  room.getRoomName(),
                                  maxLines: 1,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                subtitle: RoomUtil.getSubtitleDisplay(
                                        room, messageExpired) ??
                                    const Text(''),
                                trailing: _getRoomTrailing(room),
                              )));
                    });
          }).toList())),
    );
  }

  GestureDetector getSearchWidget(Color pinTileBackground) {
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
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4)),
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
            await Get.to(() => AnonymousRooms(rooms));
            await Get.find<HomeController>().loadRoomList();
          },
          subtitle: Text('Rooms: ${rooms.length}'),
          trailing: Icon(CupertinoIcons.right_chevron,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
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
            badgeContent: Text(
              rooms.length.toString(),
              style: const TextStyle(color: Colors.white),
            ),
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
            'Requesting Friends',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          onTap: () async {
            await Get.to(() => AnonymousRooms(rooms));
            await Get.find<HomeController>().loadRoomList();
          },
          subtitle: Text('Rooms: ${rooms.length}'),
          trailing: Icon(CupertinoIcons.right_chevron,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
        ));
  }

  Widget getRelaysStatus(HomeController homeController) {
    WebsocketService webSocketService = Get.find<WebsocketService>();
    String status = webSocketService.relayStatusInt.value;
    if (!homeController.isConnectedNetwork.value) {
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
        EcashController ecashController = Get.find<EcashController>();
        if (ecashController.cashuInitFailed.value == true &&
            ecashController.totalSats.value == 0) {
          return _getEcashFailedStatusWidget();
        }
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
    return const HomeDropMenuWidget();
  }

  Widget _noRoomsView(
      BuildContext context, HomeController home2controller, Identity identity) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 50),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                height: 200,
              ),
              SvgPicture.asset(
                'assets/images/no-message.svg',
                height: 80,
                width: 80,
              ),
              textSmallGray(context, 'No friends'),
              const SizedBox(
                height: 20,
              ),
              OutlinedButton(
                  onPressed: () async {
                    await showMyQrCode(context, identity, false);
                  },
                  style: ButtonStyle(
                      minimumSize: WidgetStateProperty.all(
                          const Size(double.infinity, 40))),
                  child: const Text('Show My QR Code')),
              const SizedBox(
                height: 20,
              ),
              OutlinedButton(
                onPressed: () {
                  Get.toNamed(Routes.ecash);
                },
                style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all(
                        const Size(double.infinity, 40))),
                child: const Text('Deposit Ecash Sat to start a chat'),
              )
            ],
          ),
        ));
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

  Widget? _getRoomTrailing(Room room) {
    if (room.lastMessageModel?.createdAt != null) {
      return Wrap(
        direction: Axis.vertical,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          textSmallGray(
              Get.context!, formatTimeMsg(room.lastMessageModel!.createdAt)),
          room.isMute
              ? Icon(
                  Icons.notifications_off_outlined,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  size: 16,
                )
              : Container()
        ],
      );
    }
    return null;
  }

  Widget _getEcashFailedStatusWidget() {
    return SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          icon: Icon(
            Icons.error,
            color: Colors.red.shade400,
          ),
          onPressed: () {
            Get.dialog(CupertinoAlertDialog(
              title: const Icon(
                Icons.error,
                color: Colors.red,
                size: 34,
              ),
              content: const Text(
                  'The Ecash start-up failed, Please restart the app'),
              actions: [
                CupertinoDialogAction(
                  child: const Text("Cancel"),
                  onPressed: () async {
                    Get.back();
                  },
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () async {
                    exit(0);
                  },
                  child: const Text(
                    "Exit APP",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ));
          },
        ));
  }
}
