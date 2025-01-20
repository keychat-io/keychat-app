import 'package:amberflutter/amberflutter.dart';
import 'package:app/utils.dart';

class SignerService {
  static SignerService? _instance;
  final amber = Amberflutter();
  // Avoid self instance
  SignerService._();
  static SignerService get instance => _instance ??= SignerService._();

  Future<bool> checkAvailable() async {
    return amber.isAppInstalled();
  }

  Future<String?> getPublicKey() async {
    var available = await checkAvailable();
    if (!available) {
      logger.e("Amber app not installed");
      return null;
    }
    var res = await amber.getPublicKey(
      permissions: [
        const Permission(
          type: "sign_message",
        ),
      ],
    );
    logger.d(res);
    return res['signature'];
  }

  signString({required String content, required String pubkey}) async {
    var available = await checkAvailable();
    if (!available) {
      logger.e("Amber app not installed");
      return null;
    }
    var res = await amber.signMessage(
      currentUser: pubkey,
      content: content,
    );
    logger.d(res);
    return res['signature'];
  }
}
