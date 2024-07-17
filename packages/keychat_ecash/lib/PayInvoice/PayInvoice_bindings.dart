import 'package:get/get.dart';
import './PayInvoice_controller.dart';

class PayInvoiceBindings implements Bindings {
    @override
    void dependencies() {
        Get.put(PayInvoiceController());
    }
}