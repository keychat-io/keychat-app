abstract class Routes {
  static const root = '/';
  // static const init = '/';
  static const login = '/login';
  static const importKey = '/login/import_key';
  static const onboarding = '/onboarding';
  static const addFriend = '/add_friend';
  static const addGroup = '/add_group';
  static const createIdentity = '/create_identity';

  static const setting = '/setting';
  static const settingMore = '/setting/more';
  static const settingMe = '/setting/me';

  // webrtc
  static const webrtcSetting = '/webrtc/setting';

  static const home = '/home';
  static const roomList = '/rooms';
  static const room = '/room/:id';
  static const contactList = '/contacts';
  static const contact = '/contact/:id';

  static const scanQR = '/scanQR';

  // ecash
  static const ecash = '/ecash';
  static const ecashBillCashu = '/ecash/bills/cashu';
  static const ecashBillLightning = '/ecash/bills/lightning';
  static const ecashSetting = '/ecash/setting';
  static const ecashPaySuccess = '/ecash/pay_success';
}
