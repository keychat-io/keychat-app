import 'dart:convert' show utf8;
import 'dart:io' show File;

import 'package:flutter/material.dart';

class LogViewer extends StatelessWidget {
  final String path;
  const LogViewer({required this.path, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Viewer'),
      ),
      body: FutureBuilder(
        future: readLogFile(path),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Text(snapshot.data!.replaceAll('\\n', '\n'));
          } else {
            return const CircularProgressIndicator();
          }
        },
      ),
    );
  }

  Future<String> readLogFile(String path) async {
    try {
      File logFile = File(path);
      var bytes = await logFile.readAsBytes();
      var data = utf8.decode(bytes);
      return data;
    } catch (e) {
      return "Error reading log file: $e";
    }
  }
}
