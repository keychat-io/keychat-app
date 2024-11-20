import 'package:get/get.dart';

import 'package:app/models/models.dart';

import '../service/contact.service.dart';

class ContactController extends GetxController with StateMixin<Type> {
  ContactService contactService = ContactService.instance;
  RxList<Contact> contactList = <Contact>[].obs;
}
