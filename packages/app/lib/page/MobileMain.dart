// import 'package:app/desktop/MobileBrowser.dart';
// import 'package:app/page/root_page_cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:app/controller/home.controller.dart';
// import 'package:app/page/browser/MultiWebviewController.dart';

// class MobileMain extends StatefulWidget {
//   const MobileMain({super.key});

//   @override
//   _MobileMainState createState() => _MobileMainState();
// }

// class _MobileMainState extends State<MobileMain> {
//   int currentIndex = 0;
//   final HomeController homeController = Get.put(HomeController());
//   final FocusNode _focusNode = FocusNode();
//   late MultiWebviewController webviewController;

//   @override
//   void initState() {
//     super.initState();
//     webviewController = Get.find<MultiWebviewController>();
//     homeController.mobileMainIndex = currentIndex.obs;
//     homeController.setMobileMainIndex = (int index) {
//       setState(() {
//         currentIndex = index;
//       });
//     };
//   }

//   @override
//   void dispose() {
//     _focusNode.dispose();
//     super.dispose();
//   }

//   KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
//     if (event is KeyDownEvent) {
//       // Check if we're in browser view (index 1)
//       if (currentIndex == 1) {
//         // Handle Cmd+W or Ctrl+W to close current tab
//         if ((event.logicalKey == LogicalKeyboardKey.keyW) &&
//             (GetPlatform.isMacOS
//                 ? event.isMetaPressed
//                 : event.isControlPressed)) {
//           if (webviewController.tabs.isNotEmpty &&
//               webviewController.currentTabIndex <
//                   webviewController.tabs.length) {
//             webviewController.removeByIndex(webviewController.currentTabIndex);
//           }
//           return KeyEventResult.handled;
//         }

//         // Handle Cmd+N or Ctrl+N to open new tab
//         if ((event.logicalKey == LogicalKeyboardKey.keyN) &&
//             (GetPlatform.isMacOS
//                 ? event.isMetaPressed
//                 : event.isControlPressed)) {
//           webviewController.addNewTab();
//           return KeyEventResult.handled;
//         }
//       }
//     }
//     return KeyEventResult.ignored;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return KeyboardListener(
//       focusNode: _focusNode,
//       onKeyEvent: _handleKeyEvent,
//       autofocus: true,
//       child: IndexedStack(
//           index: currentIndex,
//           children: [CupertinoRootPage(), MobileBrowser()]),
//     );
//   }
// }
