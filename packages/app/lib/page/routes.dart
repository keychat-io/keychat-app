abstract class Routes {
  static const root = '/';
  // static const init = '/';
  static const login = '/login';
  static const importKey = '/login/import_key';
  static const onboarding = '/onboarding';

  static const createIdentity = '/create_identity';

  // webrtc
  static const webrtcSetting = '/webrtc/setting';

  static const home = '/home';
  static const roomList = '/rooms';
  static const roomEmpty = '/room';
  static const room = '/room/:id';
  static const roomSettingContact = '/room/:id/chat_setting_contact';
  static const roomSettingGroup = '/room/:id/chat_setting_group';
  static const roomSettingContactSecurity =
      '/room/:id/chat_setting_contact/security';
  static const roomSettingPayToRelay =
      '/room/:id/chat_setting_contact/pay_to_relay';
  static const contact = '/contact/:id';

  static const scanQR = '/scanQR';

  // ecash
  static const ecash = '/ecash';
  static const ecashSetting = '/ecash/setting';
  static const ecashPaySuccess = '/ecash/pay_success';
}
