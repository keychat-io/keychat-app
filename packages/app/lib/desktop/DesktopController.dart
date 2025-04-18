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
  final browserSidebarWidth =
      260.0.obs; // Add this line for browser sidebar width

  @override
  void onInit() {
    super.onInit();
    _loadRoomListWidth();
    _loadBrowserSidebarWidth(); // Add this line to load browser sidebar width
  }

  Future<void> _loadRoomListWidth() async {
    double? savedWidth = double.tryParse(
        (await Storage.getString(StorageKeyString.desktopRoomListWidth)) ??
            roomListWidth.value.toString());
    if (savedWidth != null && savedWidth >= 180 && savedWidth <= 400) {
      roomListWidth.value = savedWidth;
    }
  }

  // Add this method to load browser sidebar width
  Future<void> _loadBrowserSidebarWidth() async {
    double? savedWidth = double.tryParse((await Storage.getString(
            StorageKeyString.desktopBrowserSidebarWidth)) ??
        browserSidebarWidth.value.toString());
    if (savedWidth != null && savedWidth >= 180 && savedWidth <= 400) {
      browserSidebarWidth.value = savedWidth;
    }
  }

  Future<void> _saveRoomListWidth() async {
    await Storage.setString(
        StorageKeyString.desktopRoomListWidth, roomListWidth.value.toString());
  }

  // Add this method to save browser sidebar width
  Future<void> _saveBrowserSidebarWidth() async {
    await Storage.setString(StorageKeyString.desktopBrowserSidebarWidth,
        browserSidebarWidth.value.toString());
  }

  void setRoomListWidth(double width) {
    if (width >= 150 && width <= 400) {
      roomListWidth.value = width;
      _saveRoomListWidth();
    }
  }

  // Add this method to set browser sidebar width
  void setBrowserSidebarWidth(double width) {
    if (width >= 150 && width <= 400) {
      browserSidebarWidth.value = width;
      _saveBrowserSidebarWidth();
    }
  }

  resetRoom() {
    try {
      selectedRoom.value = Room(identityId: -1, toMainPubkey: '', npub: '');
      // ignore: empty_catches
    } catch (e) {}
  }

  @override
  void onClose() {
    // Dispose of any resources here
    super.onClose();
  }
}
