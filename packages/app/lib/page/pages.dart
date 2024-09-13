import 'package:app/page/login/OnboardingPage2.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:app/page/contact/ContactDetail/ContactDetail_bindings.dart';
import 'package:app/page/contact/ContactDetail/ContactDetail_page.dart';
import 'package:app/page/contact/contact_list_page.dart';
import 'package:app/page/login/AccountSetting/AccountSetting_bindings.dart';
import 'package:app/page/login/AccountSetting/AccountSetting_page.dart';
import 'package:app/page/login/import_key.dart';
import 'package:app/page/root_page_cupertino.dart';
import 'package:get/get.dart';
import 'package:app/page/setting/more_setting.dart';

import 'chat/create_group_page.dart';
import 'chat/chat_page.dart';
import 'chat/create_contact_page.dart';
import 'login/login.dart';
import 'room_list.dart';
import 'routes.dart';

class Pages {
  static final routes = [
    GetPage(
        name: Routes.onboarding,
        page: () => const OnboardingPage2(),
        transition: Transition.fadeIn),
    GetPage(
        name: Routes.root,
        page: () => const CupertinoRootPage(),
        transition: Transition.fadeIn),
    GetPage(
        name: Routes.login,
        page: () => const Login(),
        transition: Transition.fadeIn),
    GetPage(name: Routes.importKey, page: () => const ImportKey()),
    GetPage(name: Routes.settingMore, page: () => const MoreSetting()),
    GetPage(
        name: Routes.settingMe,
        page: () => const AccountSettingPage(),
        binding: AccountSettingBindings()),
    GetPage(
        name: Routes.home,
        page: () => const RoomList(),
        transition: Transition.leftToRight),
    GetPage(name: Routes.addFriend, page: () => const AddtoContactsPage("")),
    GetPage(
        name: Routes.addGroup,
        page: () => const AddGroupPage(),
        transition: Transition.fadeIn),
    GetPage(
      name: Routes.contactList,
      page: () => const ContactsPage(),
    ),
    GetPage(
        name: Routes.contact,
        page: () => const ContactDetailPage(),
        binding: ContactDetailBindings()),
    GetPage(name: Routes.room, page: () => const ChatPage()),
    GetPage(name: Routes.ecash, page: () => const CashuPage()),
    GetPage(name: Routes.ecashBillCashu, page: () => const CashuBillPage()),
    GetPage(
        name: Routes.ecashBillLightning, page: () => const LightningBillPage()),
    GetPage(name: Routes.ecashSetting, page: () => const EcashSettingPage()),
  ];
}
