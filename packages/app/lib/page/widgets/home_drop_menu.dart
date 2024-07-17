import 'package:app/page/routes.dart';
import 'package:app/utils.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomeDropMenuWidget extends StatefulWidget {
  const HomeDropMenuWidget({super.key});

  @override
  State<HomeDropMenuWidget> createState() => _HomeDropMenuWidgetState();
}

class _HomeDropMenuWidgetState extends State<HomeDropMenuWidget> {
  @override
  Widget build(BuildContext context) {
    TextStyle? ts = Theme.of(context).textTheme.bodyMedium;
    return DropdownButtonHideUnderline(
      child: DropdownButton2(
        customButton: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
          ),
          width: 48,
          height: 48,
          child: const Icon(
            CupertinoIcons.add_circled,
          ),
        ),
        items: [
          ...MenuItems.firstItems.map(
            (item) => DropdownMenuItem<MenuItem>(
              value: item,
              child: MenuItems.buildItem(item, ts),
            ),
          ),
        ],
        onChanged: (value) {
          MenuItems.onChanged(context, value!);
        },
        dropdownStyleData: DropdownStyleData(
          width: 160,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Theme.of(context).colorScheme.surface,
          ),
          offset: const Offset(-120, 8),
        ),
        menuItemStyleData: MenuItemStyleData(
          customHeights: [
            ...List<double>.filled(MenuItems.firstItems.length, 48),
          ],
          padding: const EdgeInsets.only(left: 16, right: 16),
        ),
      ),
    );
  }
}

class MenuItem {
  const MenuItem({
    required this.text,
    required this.icon,
  });

  final String text;
  final IconData icon;
}

abstract class MenuItems {
  static const List<MenuItem> firstItems = [addContact, addGroup, scan];

  static const addContact =
      MenuItem(text: 'Add contact', icon: Icons.person_add);
  static const addGroup =
      MenuItem(text: 'New Group', icon: CupertinoIcons.group_solid);
  static const scan =
      MenuItem(text: 'Scan', icon: CupertinoIcons.qrcode_viewfinder);

  static Widget buildItem(MenuItem item, TextStyle? style) {
    return Row(
      children: [
        Icon(item.icon, color: style?.color, size: 22),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: Text(item.text, style: style),
        ),
      ],
    );
  }

  static void onChanged(BuildContext context, MenuItem item) async {
    switch (item) {
      case MenuItems.addContact:
        await Get.toNamed(Routes.addFriend);
        break;
      case MenuItems.scan:
        handleQRScan();
        break;
      case MenuItems.addGroup:
        await Get.toNamed(Routes.addGroup);
        break;
    }
  }
}
