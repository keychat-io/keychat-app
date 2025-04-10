import 'package:app/models/room.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sidebarx/sidebarx.dart';

class DesktopController extends GetxController {
  Rx<Room> selectedRoom = Room(identityId: -1, toMainPubkey: '', npub: '').obs;
  final sidebarXController =
      SidebarXController(selectedIndex: 0, extended: false);
  final globalKey = GlobalKey<ScaffoldState>();
  @override
  void onClose() {
    // Dispose of any resources here
    super.onClose();
  }
}
