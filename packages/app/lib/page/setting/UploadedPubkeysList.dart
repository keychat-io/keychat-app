import 'package:flutter/material.dart';

class UploadedPubkeysList extends StatelessWidget {
  final String title;
  final List<String> keys;
  const UploadedPubkeysList(this.title, this.keys, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView.builder(
        itemBuilder: (BuildContext context, int index) {
          return ListTile(
            title: Text(keys[index]),
          );
        },
        itemCount: keys.length,
      ),
    );
  }
}
