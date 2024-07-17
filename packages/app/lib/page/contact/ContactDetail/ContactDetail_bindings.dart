import 'package:get/get.dart';
import './ContactDetail_controller.dart';

class ContactDetailBindings implements Bindings {
    @override
    void dependencies() {
        Get.put(ContactDetailController());
    }
}