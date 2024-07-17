import 'package:get/get.dart';
import 'package:app/models/models.dart';

import '../service/contact.service.dart';

class ContactSettingController extends GetxController with StateMixin<Type> {
  ContactService contactService = ContactService();
  Rx<Contact> roomContact = Contact(pubkey: '', npubkey: '', identityId: 0).obs;
}
