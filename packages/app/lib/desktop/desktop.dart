import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/page/browser/Browser_page.dart';
import 'package:app/page/login/me.dart';
import 'package:app/page/room_list.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sidebarx/sidebarx.dart';

class DesktopMain extends StatefulWidget {
  const DesktopMain({super.key});

  @override
  State<DesktopMain> createState() => _DesktopMainState();
}

class _DesktopMainState extends State<DesktopMain> {
  final _controller = SidebarXController(selectedIndex: 0, extended: true);
  final _key = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _key,
      drawer: HomeSidebarX(controller: _controller),
      body: Row(
        children: [
          HomeSidebarX(controller: _controller),
          Expanded(
            child: Center(
              child: _ScreensBody(
                sidebarXController: _controller,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeSidebarX extends GetView<HomeController> {
  const HomeSidebarX({
    super.key,
    required SidebarXController controller,
  }) : _controller = controller;

  final SidebarXController _controller;
  @override
  Widget build(BuildContext context) {
    return SidebarX(
      controller: _controller,
      theme: SidebarXTheme(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: canvasColor,
          borderRadius: BorderRadius.circular(20),
        ),
        hoverColor: scaffoldBackgroundColor,
        textStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        selectedTextStyle: const TextStyle(color: Colors.white),
        hoverTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        itemTextPadding: const EdgeInsets.only(left: 30),
        selectedItemTextPadding: const EdgeInsets.only(left: 30),
        itemDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: canvasColor),
        ),
        selectedItemDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: actionColor.withOpacity(0.37),
          ),
          gradient: const LinearGradient(
            colors: [accentCanvasColor, canvasColor],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 30,
            )
          ],
        ),
        iconTheme: IconThemeData(
          color: Colors.white.withOpacity(0.7),
          size: 20,
        ),
        selectedIconTheme: const IconThemeData(
          color: Colors.white,
          size: 20,
        ),
      ),

      showToggleButton: false, // footerDivider: divider,
      headerBuilder: (context, extended) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Image.asset('assets/images/logo.png'),
        );
      },
      items: [
        SidebarXItem(
          iconBuilder: (selected, hovered) {
            return Obx(() => Badge(
                backgroundColor: Colors.red,
                textColor: Colors.white,
                label: Text('${controller.allUnReadCount.value}'),
                isLabelVisible: controller.allUnReadCount.value > 0,
                child: Icon(CupertinoIcons.chat_bubble_fill,
                    color: selected
                        ? KeychatGlobal.primaryColor.withValues(alpha: 0.9)
                        : Colors.white,
                    size: 26)));
          },
          label: 'Chat',
          onTap: () {
            debugPrint('Chat');
          },
        ),
        const SidebarXItem(
          icon: CupertinoIcons.compass,
          label: 'Browser',
        ),
        const SidebarXItem(
          icon: CupertinoIcons.settings,
          label: 'Me',
        ),
      ],
    );
  }
}

class _ScreensBody extends StatelessWidget {
  const _ScreensBody({
    required this.sidebarXController,
  });

  final SidebarXController sidebarXController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: sidebarXController,
      builder: (context, child) {
        switch (sidebarXController.selectedIndex) {
          case 0:
            return RoomList();
          case 1:
            return BrowserPage();
          case 2:
            return MinePage();
          default:
            return Text(
              sidebarXController.selectedIndex.toString(),
              style: theme.textTheme.headlineSmall,
            );
        }
      },
    );
  }
}

const primaryColor = Color(0xFF685BFF);
const canvasColor = Color(0xFF2E2E48);
const scaffoldBackgroundColor = Color(0xFF464667);
const accentCanvasColor = Color(0xFF3E3E61);
const white = Colors.white;
final actionColor = const Color(0xFF5F5FA7).withOpacity(0.6);
final divider = Divider(color: white.withOpacity(0.3), height: 1);
