import 'package:keychat/desktop/desktop.dart';
import 'package:keychat/page/chat/chat_page.dart';
import 'package:keychat/page/chat/chat_setting_contact_page.dart';
import 'package:keychat/page/chat/chat_setting_group_page.dart';
import 'package:keychat/page/chat/chat_settings_security.dart';
import 'package:keychat/page/chat/message_bill/pay_to_relay_page.dart';
import 'package:keychat/page/login/OnboardingPage2.dart';
import 'package:keychat/page/login/login.dart';
import 'package:keychat/page/room_list.dart';
import 'package:keychat/page/root_page_cupertino.dart';
import 'package:keychat/page/routes.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/keychat_ecash.dart';

class Pages {
  static final List<GetPage> routes = [
    GetPage(
      name: Routes.onboarding,
      page: () => const OnboardingPage2(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.root,
      page: () {
        return GetPlatform.isMobile
            ? const CupertinoRootPage()
            : const DesktopMain();
      },
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.login,
      page: () => const Login(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.home,
      page: () => const RoomList(),
      transition: Transition.leftToRight,
    ),
    GetPage(name: Routes.room, page: ChatPage.new),
    GetPage(
      name: Routes.roomSettingContact,
      page: () => const ChatSettingContactPage(),
    ),
    GetPage(
      name: Routes.roomSettingGroup,
      page: () => const ChatSettingGroupPage(),
    ),
    GetPage(
      name: Routes.roomSettingContactSecurity,
      page: () => const ChatSettingSecurity(),
    ),
    GetPage(
      name: Routes.roomSettingPayToRelay,
      page: () => const PayToRelayPage(),
    ),
    GetPage(name: Routes.ecashSetting, page: () => const EcashSettingPage()),
  ];
}
