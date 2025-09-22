import 'package:app/models/contact.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class ContactDetailController extends GetxController {
  ContactDetailController(this.source);
  final Contact source;
  Rx<Contact> contact = Contact(pubkey: '', identityId: 0).obs;
  late TextEditingController usernameController;
  @override
  Future<void> onInit() async {
    if (source.npubkey.isEmpty) {
      source.npubkey = rust_nostr.getBech32PubkeyByHex(hex: source.pubkey);
    }
    contact.value = source;
    usernameController = TextEditingController();
    usernameController.text = contact.value.petname ?? '';
    super.onInit();
  }

  @override
  void onClose() {
    super.onClose();
    usernameController.dispose();
  }
}
