import 'package:get/get.dart';
import './NostrEvents_controller.dart';

class NostrEventsBindings implements Bindings {
    @override
    void dependencies() {
        Get.put(NostrEventsController());
    }
}