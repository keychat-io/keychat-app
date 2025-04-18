import 'package:app/controller/home.controller.dart';
import 'package:app/page/chat/create_contact_page.dart';
import 'package:app/page/chat/create_group_page.dart';
import 'package:app/page/components.dart';
import 'package:app/service/qrscan.service.dart';
import 'package:app/service/storage.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
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
  final bool showAddFriendTips;
  const HomeDropMenuWidget(this.showAddFriendTips, {super.key});

  @override
  State<HomeDropMenuWidget> createState() => _HomeDropMenuWidgetState();
}

class _HomeDropMenuWidgetState extends State<HomeDropMenuWidget> {
  List<MenuItem> firstItems = [];
  bool showAddFriendTips = false;
  @override
  void initState() {
    showAddFriendTips = widget.showAddFriendTips;

    MenuItem addContact =
        const MenuItem(text: menuAddContacts, icon: Icons.person_add);
    MenuItem addGroup =
        const MenuItem(text: menuNewGroup, icon: CupertinoIcons.group_solid);
    MenuItem scan =
        const MenuItem(text: menuScan, icon: CupertinoIcons.qrcode_viewfinder);
    MenuItem qrcode =
        const MenuItem(text: menuMyQrcode, icon: CupertinoIcons.qrcode);
    firstItems = [addContact, addGroup, scan, qrcode];

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    TextStyle? ts = Theme.of(context).textTheme.bodyMedium;
    return DropdownButtonHideUnderline(
      child: DropdownButton2(
        enableFeedback: true,
        customButton: Container(
            decoration:
                BoxDecoration(color: Theme.of(context).colorScheme.surface),
            width: 48,
            height: 48,
            child: const Icon(CupertinoIcons.add_circled)),
        items: [
          ...firstItems.map(
            (item) => DropdownMenuItem<MenuItem>(
              value: item,
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
                          borderRadius: BorderRadius.circular(4)),
                    ),
                ],
              ),
            ),
          ),
        ],
        onChanged: (MenuItem? value) async {
          if (value == null) return;
          String name = value.text;
          switch (name) {
            case menuAddContacts:
              var hc = Get.find<HomeController>();
              setState(() {
                showAddFriendTips = false;
              });
              hc.setTipsViewed(
                  StorageKeyString.tipsAddFriends, hc.addFriendTips);
              Get.bottomSheet(const AddtoContactsPage(""),
                  isScrollControlled: true,
                  ignoreSafeArea: false,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16))));
              break;
            case menuScan:
              QrScanService.instance.handleQRScan();
              break;
            case menuNewGroup:
              Get.bottomSheet(const AddGroupPage(),
                  isScrollControlled: true,
                  ignoreSafeArea: false,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16))));
              break;
            case menuMyQrcode:
              var identity = Get.find<HomeController>().getSelectedIdentity();
              showMyQrCode(context, identity, true);
              break;
          }
        },
        dropdownStyleData: DropdownStyleData(
          width: 180,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Theme.of(context).colorScheme.surface,
          ),
          offset: const Offset(-120, 8),
        ),
        menuItemStyleData: MenuItemStyleData(
          customHeights: List<double>.filled(firstItems.length, 48),
          padding: const EdgeInsets.only(left: 16, right: 16),
        ),
      ),
    );
  }
}
