import 'dart:io' show File, FileMode, IOSink;

import 'package:logger/logger.dart';

class LogFileOutputs extends LogOutput {
  LogFileOutputs(this.file) {
    // Open file sink for writing
    _sink = file.openWrite(mode: FileMode.writeOnlyAppend);
  }
  File file;
  IOSink? _sink;

  @override
  Future<void> output(OutputEvent event) async {
    if (_sink == null || event.level.value < Level.error.value) {
      return;
    }
    var outputs = '';
    for (var line in event.lines) {
      line = line.replaceAll(RegExp(r'[^\x20-\x7E\n\r\t]'), '');
      outputs += '$line\n';
    }
    _sink!.write(outputs);
  }

  /// Close the file sink to release file handle
  Future<void> close() async {
    if (_sink != null) {
      await _sink!.flush();
      await _sink!.close();
      _sink = null;
    }
  }
}
