import 'dart:async';

import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/models/room.dart';
import 'package:keychat/service/storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/utils.dart' show Utils;
import 'package:keychat_nwc/nwc/nwc_controller.dart';
import 'package:sidebarx/sidebarx.dart';

class DesktopController extends GetxController {
  Rx<Room> selectedRoom = Room(identityId: -1, toMainPubkey: '', npub: '').obs;
  late SidebarXController sidebarXController;
  final globalKey = GlobalKey<ScaffoldState>();

  RxDouble roomListWidth = 260.0.obs;
  RxDouble browserSidebarWidth = 180.0.obs;
  late HomeController hc;
  late NwcController controller;
  @override
  void onInit() {
    hc = Get.find<HomeController>();
    sidebarXController = SidebarXController(
      selectedIndex: hc.selectedTabIndex,
      extended: false,
    );
    sidebarXController.addListener(() async {
      await hc.setSelectedTab(sidebarXController.selectedIndex);
    });
    super.onInit();

    unawaited(_loadRoomListWidth());
    unawaited(
      _loadBrowserSidebarWidth(),
    ); // Add this line to load browser sidebar width
  }

  void activeChatTabAndToRoom(Room room) {
    selectedRoom.value = room;
    sidebarXController.selectIndex(0);
    unawaited(hc.setSelectedTab(0));
  }

  Future<void> _loadRoomListWidth() async {
    final savedWidth = double.tryParse(
      (Storage.getString(StorageKeyString.desktopRoomListWidth)) ??
          roomListWidth.value.toString(),
    );
    if (savedWidth != null && savedWidth >= 100 && savedWidth <= 400) {
      roomListWidth.value = savedWidth;
    }
  }

  // Add this method to load browser sidebar width
  Future<void> _loadBrowserSidebarWidth() async {
    final savedWidth = double.tryParse(
      (Storage.getString(StorageKeyString.desktopBrowserSidebarWidth)) ??
          browserSidebarWidth.value.toString(),
    );
    if (savedWidth != null && savedWidth >= 100 && savedWidth <= 400) {
      browserSidebarWidth.value = savedWidth;
    }
  }

  Future<void> _saveRoomListWidth() async {
    await Storage.setString(
      StorageKeyString.desktopRoomListWidth,
      roomListWidth.value.toString(),
    );
  }

  // Add this method to save browser sidebar width
  Future<void> _saveBrowserSidebarWidth() async {
    await Storage.setString(
      StorageKeyString.desktopBrowserSidebarWidth,
      browserSidebarWidth.value.toString(),
    );
  }

  void setRoomListWidth(double width) {
    if (width >= 100 && width <= 400) {
      roomListWidth.value = width;
      _saveRoomListWidth();
    }
  }

  // Add this method to set browser sidebar width
  void setBrowserSidebarWidth(double width) {
    if (width >= 100 && width <= 400) {
      browserSidebarWidth.value = width;
      _saveBrowserSidebarWidth();
    }
  }

  void resetRoom() {
    try {
      selectedRoom.value = Room(identityId: -1, toMainPubkey: '', npub: '');
      // ignore: empty_catches
    } catch (e) {}
  }
}
