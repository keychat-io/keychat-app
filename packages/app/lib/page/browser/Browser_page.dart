import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'Browser_controller.dart';

class BrowserPage extends GetView<BrowserController> {
  const BrowserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // appBar: AppBar(),
        body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20),
            child: Column(children: [
              Form(
                key: const PageStorageKey('input'),
                child: TextFormField(
                  textInputAction: TextInputAction.done,
                  maxLines: 8,
                  minLines: 1,
                  controller: controller.textController,
                  decoration: InputDecoration(
                      labelText: 'Url',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste),
                        onPressed: () async {
                          controller.textController.text =
                              await Clipboard.getData('text/plain')
                                      .then((value) => value?.text) ??
                                  '';
                        },
                      )),
                  onFieldSubmitted: (value) {
                    controller.onComplete();
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a URL';
                    }
                    return null;
                  },
                ),
              )
            ])));
  }
}
