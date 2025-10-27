import 'package:app/controller/home.controller.dart';
import 'package:app/page/chat/create_contact_page.dart';
import 'package:app/page/chat/create_group_page.dart';
import 'package:app/page/components.dart';
import 'package:app/service/qrscan.service.dart';
import 'package:app/service/storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MenuItem {
  const MenuItem({required this.text, required this.icon});

  final String text;
  final IconData icon;
}

const menuAddContacts = 'Add Contact';
const menuNewGroup = 'New Group';
const menuScan = 'Scan';
const menuMyQrcode = 'My QRCode';

class HomeDropMenuWidget extends StatefulWidget {
  const HomeDropMenuWidget({this.showAddFriendTips = false, super.key});
  final bool showAddFriendTips;

  @override
  State<HomeDropMenuWidget> createState() => _HomeDropMenuWidgetState();
}

class _HomeDropMenuWidgetState extends State<HomeDropMenuWidget> {
  List<MenuItem> firstItems = [];
  bool showAddFriendTips = false;
  final MenuController _menuController = MenuController();

  @override
  void initState() {
    showAddFriendTips = widget.showAddFriendTips;

    const addContact = MenuItem(text: menuAddContacts, icon: Icons.person_add);
    const addGroup =
        MenuItem(text: menuNewGroup, icon: CupertinoIcons.group_solid);
    const scan =
        MenuItem(text: menuScan, icon: CupertinoIcons.qrcode_viewfinder);
    // MenuItem qrcode =
    //     const MenuItem(text: menuMyQrcode, icon: CupertinoIcons.qrcode);
    firstItems = [addContact, addGroup, scan];

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme.bodyMedium;

    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(-120, 8),
      style: MenuStyle(
        elevation: WidgetStateProperty.all(8),
        backgroundColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.surface,
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 6),
        ),
        fixedSize: WidgetStateProperty.all(const Size(180, double.infinity)),
      ),
      menuChildren: _buildMenuItems(ts),
      builder: (context, controller, child) {
        return GestureDetector(
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
            ),
            width: 48,
            height: 48,
            child: const Icon(CupertinoIcons.add_circled),
          ),
        );
      },
    );
  }

  List<Widget> _buildMenuItems(TextStyle? ts) {
    return firstItems.map((item) {
      return MenuItemButton(
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(double.infinity, 48)),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
        onPressed: () => _handleMenuSelection(item),
        child: Row(
          children: [
            Icon(item.icon, color: ts?.color, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(item.text, style: ts)),
            if (item.text == menuAddContacts && showAddFriendTips)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  Future<void> _handleMenuSelection(MenuItem item) async {
    _menuController.close();

    final name = item.text;
    switch (name) {
      case menuAddContacts:
        final hc = Get.find<HomeController>();
        setState(() {
          showAddFriendTips = false;
        });
        hc.setTipsViewed(
          StorageKeyString.tipsAddFriends,
          hc.addFriendTips,
        );
        Get.bottomSheet(
          const AddtoContactsPage(''),
          isScrollControlled: true,
          ignoreSafeArea: false,
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
        );
      case menuScan:
        QrScanService.instance.handleQRScan();
      case menuNewGroup:
        Get.bottomSheet(
          const AddGroupPage(),
          isScrollControlled: true,
          ignoreSafeArea: false,
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
        );
      case menuMyQrcode:
        final identity = Get.find<HomeController>().getSelectedIdentity();
        showMyQrCode(context, identity, true);
    }
  }
}
