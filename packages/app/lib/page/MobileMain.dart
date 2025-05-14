// import 'package:app/controller/home.controller.dart';
// import 'package:app/desktop/MobileBrowser.dart';
// import 'package:app/global.dart';
// import 'package:app/models/room.dart';
// import 'package:app/page/chat/chat_page.dart';
// import 'package:app/page/chat/chat_setting_contact_page.dart';
// import 'package:app/page/chat/chat_setting_group_page.dart';
// import 'package:app/page/chat/chat_settings_security.dart';
// import 'package:app/page/chat/message_bill/pay_to_relay_page.dart';
// import 'package:app/page/root_page_cupertino.dart';
// import 'package:app/utils.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';

// class MobileMain extends StatefulWidget {
//   const MobileMain({super.key});

//   @override
//   _MobileMainState createState() => _MobileMainState();
// }

// class _MobileMainState extends State<MobileMain> {
//   int currentIndex = 0;
//   late HomeController homeController;
//   @override
//   void initState() {
//     super.initState();
//     homeController = Get.find<HomeController>();
//     currentIndex = homeController.currentMainIndexedStackIndex;
//     homeController.setMainIndexedStackIndex = (int index) {
//       logger.d('setMainIndexedStackIndex $index');
//       setState(() {
//         currentIndex = index;
//         homeController.currentMainIndexedStackIndex = index;
//       });
//     };
//   }

//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//         canPop: false,
//         onPopInvokedWithResult: (didPop, d) {
//           if (didPop) return;
//           if (Get.currentRoute == '/root') {
//             SystemNavigator.pop();
//             return;
//           }
//           if (currentIndex == 0) {
//             Get.back(id: GetXNestKey.mobileMain);
//             return;
//           } else {
//             setState(() {
//               currentIndex = 0;
//               homeController.currentMainIndexedStackIndex = 0;
//             });
//           }
//         },
//         child: IndexedStack(index: currentIndex, children: [
//           Navigator(
//               key: Get.nestedKey(GetXNestKey.mobileMain),
//               initialRoute: '/root',
//               onGenerateRoute: (RouteSettings settings) {
//                 if (settings.name == '/root') {
//                   return GetPageRoute(page: () => CupertinoRootPage());
//                 }
//                 String route = settings.name!;

//                 // Pattern 1: /room/:id
//                 final roomPathRegex = RegExp(r'^\/room\/(\d+)$');
//                 if (roomPathRegex.hasMatch(route)) {
//                   final match = roomPathRegex.firstMatch(route);
//                   int roomId = int.parse(match!.group(1)!);
//                   late Room room;
//                   try {
//                     room = settings.arguments as Room;
//                   } catch (e) {
//                     room = (settings.arguments as Map)['room'] as Room;
//                   }
//                   return GetPageRoute(
//                       transition: Transition.cupertino,
//                       page: () => ChatPage(key: ValueKey(roomId), room: room));
//                 }

//                 // Pattern 2: /room/:id/:method
//                 final roomMethodRegex = RegExp(r'^\/room\/(\d+)\/(.+)$');
//                 if (roomMethodRegex.hasMatch(route)) {
//                   final match = roomMethodRegex.firstMatch(route);
//                   int roomId = int.parse(match!.group(1)!);
//                   String method = match.group(2)!;

//                   late Widget pageWidget;
//                   switch (method) {
//                     case 'chat_setting_contact':
//                       pageWidget = ChatSettingContactPage(roomId: roomId);
//                       break;
//                     case 'chat_setting_group':
//                       pageWidget = ChatSettingGroupPage(roomId: roomId);
//                       break;
//                     case 'chat_setting_contact/security':
//                       pageWidget = ChatSettingSecurity(roomId: roomId);
//                       break;
//                     case 'chat_setting_contact/pay_to_relay':
//                       pageWidget = PayToRelayPage(roomId: roomId);
//                       break;
//                     default:
//                       return null;
//                   }

//                   return GetPageRoute(
//                     transition: Transition.cupertino,
//                     page: () => pageWidget,
//                   );
//                 }
//                 return null;
//               }),
//           MobileBrowser()
//         ]));
//   }
// }
