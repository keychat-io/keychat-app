import 'dart:convert';
import 'dart:io';
import 'package:app/service/secure_storage.dart';
import 'package:app/service/storage.dart';
import 'package:app/utils.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pick_or_save/pick_or_save.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DbSetting {
  Future<List<File>> getDatabaseFiles(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      throw Exception("Directory does not exist: $path");
    }

    return dir
        .listSync()
        .whereType<File>()
        // need to filter file which is not null
        .where((file) => file.lengthSync() > 0)
        .toList();
  }

  Future<List<Map<String, dynamic>>> encryptFiles(
      List<File> files, String encryptionKey) async {
    final key = encrypt.Key.fromUtf8(encryptionKey.padRight(32, '0'));
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    List<Map<String, dynamic>> encryptedFiles = [];

    for (var file in files) {
      final bytes = await file.readAsBytes();

      final encrypted = encrypter.encryptBytes(bytes, iv: iv);

      encryptedFiles.add({
        "fileName": file.uri.pathSegments.last,
        "encryptedData": iv.bytes + encrypted.bytes,
      });
    }

    return encryptedFiles;
  }

  Future<File> packageEncryptedFiles(
      List<Map<String, dynamic>> encryptedFiles, String outputPath) async {
    final outputFile = File(outputPath);

    final sink = outputFile.openWrite();

    for (var file in encryptedFiles) {
      final fileName = file['fileName'] as String;
      final encryptedData = file['encryptedData'] as List<int>;

      sink
        ..write(fileName.length.toString().padLeft(4, '0'))
        ..write(fileName)
        ..write(encryptedData.length.toString().padLeft(8, '0'))
        ..add(encryptedData);
    }

    await sink.close();
    return outputFile;
  }

  void exportDB(BuildContext context, encryptionKey) async {
    final fileName =
        'Keychat_db_${formatTime(DateTime.now().millisecondsSinceEpoch, 'yyyy-MM-dd')}';
    var appFolder = await getApplicationDocumentsDirectory();
    String sourcePath = '${appFolder.path}/prod/database/';
    String outputPath = '$sourcePath/$fileName';
    // need export shared_preferences file to sourcePath
    String sharedPrefsPath = '$sourcePath/shared_prefs_export.json';
    final exportsharedPrefsFile = File(sharedPrefsPath);
    await exportSharedPreferences(exportsharedPrefsFile);
    // need export secure storage file to sourcePath
    String secureStoragePath = '$sourcePath/secure_storage.json';
    final exportSecureStorageFile = File(secureStoragePath);
    await exportSecureStorage(exportSecureStorageFile);
    await exportAndEncryptDatabases(
        sourcePath, outputPath, fileName, encryptionKey);
    // export then delete
    exportsharedPrefsFile.deleteSync();
    exportSecureStorageFile.deleteSync();
  }

  Future<void> exportAndEncryptDatabases(String sourcePath, String outputPath,
      String fileName, String encryptionKey) async {
    try {
      final files = await getDatabaseFiles(sourcePath);

      if (files.isEmpty) {
        logger.e("No database files found at: $sourcePath");
        return;
      }

      final encryptedFiles = await encryptFiles(files, encryptionKey);

      final packagedFile =
          await packageEncryptedFiles(encryptedFiles, outputPath);
      logger.d("Encrypted package created at: ${packagedFile.path}");

      await exportFile(packagedFile.path, fileName);
      if (await packagedFile.exists()) {
        await packagedFile.delete();
        logger.d('File deleted: ${packagedFile.path}');
      }
    } catch (e) {
      logger.e("Error occurred: $e");
    }
  }

  Future<bool?> exportFile(String filePath, [String? fileName]) async {
    if (Platform.isIOS) {
      _exportFileIOS(filePath);
      return null;
    } else if (Platform.isAndroid) {
      return await _exportFileAndroid(filePath, fileName);
    }
    return false;
  }

  void _exportFileIOS(String filePath) {
    const MethodChannel channel = MethodChannel('com.keychat/export/channel');
    if (!Platform.isIOS) {
      throw Exception('exportFileIOS is only available on iOS');
    }
    channel.invokeMethod('exportFile', {'filePath': filePath}).then((result) {
      logger.d('File exported successfully: $result');
    }).catchError((error) {
      logger.e('Failed to export file: $error');
    });
  }

  Future<bool> _exportFileAndroid(String filePath, [String? fileName]) async {
    final pickOrSavePlugin = PickOrSave();
    final params = FileSaverParams(
      saveFiles: [
        SaveFileInfo(
          fileName: fileName,
          filePath: filePath,
        ),
      ],
    );
    List<String>? result;
    try {
      result = await pickOrSavePlugin.fileSaver(params: params);
    } on PlatformException catch (e) {
      logger.e(e.toString());
    } catch (e) {
      logger.e(e.toString());
    }

    return result?.isNotEmpty ?? false;
  }

  Future<List<Map<String, dynamic>>> parseEncryptedPackage(
      String packagePath) async {
    final packageFile = File(packagePath);
    if (!await packageFile.exists()) {
      throw Exception("Encrypted package does not exist: $packagePath");
    }

    final bytes = await packageFile.readAsBytes();
    int offset = 0;
    List<Map<String, dynamic>> parsedFiles = [];

    while (offset < bytes.length) {
      final fileNameLength =
          int.parse(String.fromCharCodes(bytes.sublist(offset, offset + 4)));
      offset += 4;

      final fileName =
          String.fromCharCodes(bytes.sublist(offset, offset + fileNameLength));
      offset += fileNameLength;

      final dataLength =
          int.parse(String.fromCharCodes(bytes.sublist(offset, offset + 8)));
      offset += 8;

      final encryptedData = bytes.sublist(offset, offset + dataLength);
      offset += dataLength;

      parsedFiles.add({
        "fileName": fileName,
        "encryptedData": encryptedData,
      });
    }

    return parsedFiles;
  }

  Future<bool> decryptAndSaveFiles(List<Map<String, dynamic>> encryptedFiles,
      String decryptionKey, String targetDirectory) async {
    final key = encrypt.Key.fromUtf8(decryptionKey.padRight(32, '0'));
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    try {
      for (var file in encryptedFiles) {
        final encryptedData = file['encryptedData'] as List<int>;
        final fileName = file['fileName'] as String;

        final iv = encrypt.IV(Uint8List.fromList(encryptedData.sublist(0, 16)));
        final encryptedContent = Uint8List.fromList(encryptedData.sublist(16));

        final decrypted =
            encrypter.decryptBytes(encrypt.Encrypted(encryptedContent), iv: iv);

        final targetFile = File('$targetDirectory/$fileName');
        await targetFile.writeAsBytes(decrypted);
      }
      // parse sharedPreferences data
      await importSharedPreferences(targetDirectory);
      await importSecureStorage(targetDirectory);
      return true;
    } catch (e) {
      logger.e("Error occurred: $e");
      return false;
    }
  }

  Future<bool> importAndDecryptPackage(
      String packagePath, String decryptionKey, String targetDirectory) async {
    try {
      final encryptedFiles = await parseEncryptedPackage(packagePath);

      if (encryptedFiles.isEmpty) {
        logger.e("No files found in the encrypted package.");
        return false;
      }
      logger.d("Files successfully decrypted to: $targetDirectory");

      return await decryptAndSaveFiles(
          encryptedFiles, decryptionKey, targetDirectory);
    } catch (e) {
      logger.e("Error occurred: $e");
      return false;
    }
  }

  void deleteAllFilesInDirectory(String targetDirectory) {
    final directory = Directory(targetDirectory);

    if (directory.existsSync()) {
      // List all the entities in the directory
      directory.listSync().forEach((entity) {
        if (entity is File) {
          try {
            entity.deleteSync(); // Delete the file
            ("Deleted file: ${entity.path}");
          } catch (e) {
            logger.e("Error deleting file: ${entity.path}, $e");
          }
        }
      });
      logger.d("All files in $targetDirectory have been deleted.");
    } else {
      logger.e("Directory does not exist then create: $targetDirectory");
      // path need to create
      directory.createSync(recursive: true);
    }
  }

  Future<bool> importDB(BuildContext context, String decryptionKey) async {
    var appFolder = await getApplicationDocumentsDirectory();
    String sourcePath = '${appFolder.path}/prod/database/';
    File? file = await importFile();
    if (file == null) {
      EasyLoading.showError('status: No file select',
          duration: const Duration(seconds: 3));
      logger.e("No file select.");
      return false;
    }
    deleteAllFilesInDirectory(sourcePath);
    return await importAndDecryptPackage(file.path, decryptionKey, sourcePath);
  }

  Future<File?> importFile() async {
    if (Platform.isAndroid) {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        return File(result.files.single.path!);
      }
    } else if (Platform.isIOS) {
      final filePath = await importFileIOS();
      if (filePath.isNotEmpty) {
        return File(filePath);
      }
    }
    return null;
  }

  Future<String> importFileIOS() async {
    const MethodChannel channel = MethodChannel('com.keychat/import/channel');
    if (!Platform.isIOS) {
      throw Exception('importFileIOS is only available on iOS');
    }
    return await channel.invokeMethod<String>('importFile') ?? '';
  }

  Future<void> importSharedPreferences(String importFilePath) async {
    try {
      // first clear old data
      await Storage.clearAll();
      final file = File('$importFilePath/shared_prefs_export.json');
      final jsonString = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(jsonString);

      data.forEach((key, value) async {
        if (value is int) {
          await Storage.setInt(key, value);
        }
        // else if (value is double) {
        // await Storage.setDouble(key, value);
        // }
        else if (value is bool) {
          await Storage.setBool(key, value);
        } else if (value is String) {
          await Storage.setString(key, value);
        } else if (value is List<String>) {
          await Storage.setStringList(key, value);
        }
      });
      // load then delete
      file.deleteSync();

      logger.d('Shared preferences imported.');
    } catch (e) {
      logger.e('Error importing data: $e');
    }
  }

  // first create a file in below path:
  // String sourcePath = '${appFolder.path}/prod/database/';
  Future<void> exportSharedPreferences(File exportFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = prefs.getKeys().fold({}, (map, key) {
        map[key] = prefs.get(key);
        return map;
      });

      final jsonString = jsonEncode(data);
      await exportFile.writeAsString(jsonString);

      logger.d('Exported to: ${exportFile.path}');
    } catch (e) {
      logger.e('Error exporting data: $e');
    }
  }

  Future<void> exportSecureStorage(File exportFile) async {
    try {
      Map<String, String> allData = await SecureStorage.instance.readAll();

      String jsonData = jsonEncode(allData);

      await exportFile.writeAsString(jsonData);

      logger.d('Data exported to ${exportFile.path}');
    } catch (e) {
      logger.e('Error exporting data: $e');
    }
  }

  Future<void> importSecureStorage(String importFilePath) async {
    try {
      // first clear old data
      await SecureStorage.instance.clearAll();
      String filePath = '$importFilePath/secure_storage.json';

      File file = File(filePath);
      String jsonData = await file.readAsString();

      Map<String, String> allData =
          Map<String, String>.from(jsonDecode(jsonData));

      // write secure storage
      for (var entry in allData.entries) {
        await SecureStorage.instance.write(entry.key, entry.value);
      }
      // load then delete
      file.deleteSync();

      logger.d('Data imported from $filePath');
    } catch (e) {
      logger.e('Error importing data: $e');
    }
  }
}
