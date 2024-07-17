import 'dart:io' show File, FileMode;

import 'package:logger/logger.dart';

class LogFileOutputs extends LogOutput {
  File file;
  LogFileOutputs(this.file);

  @override
  void output(OutputEvent event) async {
    if (event.level.value < Level.error.value) {
      return;
    }
    String outputs = '';
    for (var line in event.lines) {
      line = line.replaceAll(RegExp(r'[^\x20-\x7E\n\r\t]'), '');
      outputs += '$line\n';
    }
    file.writeAsString(outputs, mode: FileMode.writeOnlyAppend);
  }
}
