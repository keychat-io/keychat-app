import 'package:get/get.dart';
import 'package:keychat_ecash/CreateInvoice/CreateInvoice_controller.dart';

class CreateInvoiceBindings implements Bindings {
  @override
  void dependencies() {
    Get.put(CreateInvoiceController());
  }
}
