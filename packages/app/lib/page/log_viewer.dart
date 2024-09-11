import 'dart:convert' show utf8;
import 'dart:io' show File;

import 'package:flutter/material.dart';

class LogViewer extends StatefulWidget {
  final String path;
  const LogViewer({required this.path, super.key});

  @override
  _LogViewerState createState() => _LogViewerState();
}

class _LogViewerState extends State<LogViewer> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Viewer'),
      ),
      body: FutureBuilder<String>(
        future: readLogFile(widget.path),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            return SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Text(snapshot.data!.replaceAll('\\n', '\n')),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(seconds: 1),
            curve: Curves.easeOut,
          );
        },
        child: const Icon(Icons.arrow_downward),
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
