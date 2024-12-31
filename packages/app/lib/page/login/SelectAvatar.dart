import 'dart:math';

import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SelectAvatar extends StatefulWidget {
  const SelectAvatar({super.key});

  @override
  _SelectAvatarState createState() => _SelectAvatarState();
}

class _SelectAvatarState extends State<SelectAvatar> {
  List<String> randomStrList = [];

  @override
  initState() {
    super.initState();
    handleRefresh();
  }

  handleRefresh() {
    setState(() {
      randomStrList = List.generate(8, (index) {
        return Random().nextInt(99999999).toString();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Select Avatar'),
          leading: Container(),
          actions: [
            TextButton(
                onPressed: () {
                  handleRefresh();
                },
                child: const Text('Refresh'))
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xffCE9FFC), Color(0xff7367F0)],
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
          child: GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: List.generate(randomStrList.length, (index) {
              return GestureDetector(
                  onTap: () {
                    Get.back(result: randomStrList[index]);
                  },
                  child: Utils.getRandomAvatar(randomStrList[index],
                      height: 30, width: 30));
            }),
          ),
        ));
  }
}
