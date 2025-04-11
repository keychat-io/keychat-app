import 'package:app/models/room.dart';
import 'package:app/service/storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sidebarx/sidebarx.dart';

class DesktopController extends GetxController {
  Rx<Room> selectedRoom = Room(identityId: -1, toMainPubkey: '', npub: '').obs;
  final sidebarXController =
      SidebarXController(selectedIndex: 0, extended: false);
  final globalKey = GlobalKey<ScaffoldState>();

  final roomListWidth = 260.0.obs;

  @override
  void onInit() {
    super.onInit();
    _loadRoomListWidth();
  }

  Future<void> _loadRoomListWidth() async {
    double? savedWidth = double.tryParse(
        (await Storage.getString(StorageKeyString.desktopRoomListWidth)) ??
            roomListWidth.value.toString());
    if (savedWidth != null && savedWidth >= 180 && savedWidth <= 400) {
      roomListWidth.value = savedWidth;
    }
  }

  Future<void> _saveRoomListWidth() async {
    await Storage.setString(
        StorageKeyString.desktopRoomListWidth, roomListWidth.value.toString());
  }

  void setRoomListWidth(double width) {
    if (width >= 180 && width <= 400) {
      roomListWidth.value = width;
      _saveRoomListWidth();
    }
  }

  resetRoom() {
    selectedRoom.value = Room(identityId: -1, toMainPubkey: '', npub: '');
  }

  @override
  void onClose() {
    // Dispose of any resources here
    super.onClose();
  }
}
