import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class MyMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (route == '/myRoute') {}
    return super.redirect(route);
  }
}
