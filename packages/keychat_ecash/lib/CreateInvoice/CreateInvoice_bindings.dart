import 'package:get/get.dart';
import './CreateInvoice_controller.dart';

class CreateInvoiceBindings implements Bindings {
    @override
    void dependencies() {
        Get.put(CreateInvoiceController());
    }
}