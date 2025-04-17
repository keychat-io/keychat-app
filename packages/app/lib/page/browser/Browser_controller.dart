import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BrowserController extends GetxController {
  late TextEditingController textController;
  RxString title = 'Loading'.obs;
  RxString defaultSearchEngineObx = 'google'.obs;
  RxString input = ''.obs;
  RxDouble progress = 0.2.obs;

  initBrowser() {
    title.value = 'Loading';
    progress.value = 0.0;
  }
}
