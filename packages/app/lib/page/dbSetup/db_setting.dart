import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:io' show Directory, File, Platform;
import 'dart:math' show Random;
import 'dart:typed_data' show ByteData, Endian, Uint8List;

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:file_picker/file_picker.dart';
import 'package:hashlib/hashlib.dart';
import 'package:keychat/service/secure_storage.dart';
import 'package:keychat/service/storage.dart';
import 'package:keychat/utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

/// V2 backup format magic bytes for format detection.
const _v2Magic = 'KCBK';

/// V2 format version byte.
const _v2Version = 0x02;

/// V2 fixed header size: 4 (magic) + 1 (version) + 16 (salt) = 21 bytes.
/// After this, 2 bytes for metadata length + variable metadata JSON follow.
const _v2FixedHeaderSize = 21;

class DbSetting {
  /// Lists non-empty files in the given directory.
  Future<List<File>> getDatabaseFiles(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      throw Exception('Directory does not exist: $dirPath');
    }

    return dir
        .listSync()
        .whereType<File>()
        .where((file) => file.lengthSync() > 0)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // V2 encryption: Argon2id KDF + in-memory secure data
  // ---------------------------------------------------------------------------

  /// Derives a 32-byte AES-256 key from password + salt using Argon2id.
  ///
  /// Uses OWASP-recommended parameters (47 MB memory, 1 iteration, 1 lane).
  static Uint8List deriveKeyV2(String password, Uint8List salt) {
    final result = argon2id(
      utf8.encode(password),
      salt,
      hashLength: 32,
      security: Argon2Security.owasp,
    );
    return Uint8List.fromList(result.bytes);
  }

  /// Encrypts disk files and in-memory byte entries using a derived key.
  Future<List<Map<String, dynamic>>> _encryptFilesV2(
    List<File> diskFiles,
    List<MapEntry<String, List<int>>> memoryFiles,
    Uint8List derivedKey,
  ) async {
    final key = encrypt.Key(derivedKey);
    final encryptedFiles = <Map<String, dynamic>>[];

    for (final file in diskFiles) {
      final iv = encrypt.IV.fromSecureRandom(16);
      final bytes = await file.readAsBytes();
      final encrypted = encrypt.Encrypter(
        encrypt.AES(key),
      ).encryptBytes(bytes, iv: iv);
      encryptedFiles.add({
        'fileName': file.uri.pathSegments.last,
        'encryptedData': iv.bytes + encrypted.bytes,
      });
    }

    for (final entry in memoryFiles) {
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypted = encrypt.Encrypter(
        encrypt.AES(key),
      ).encryptBytes(entry.value, iv: iv);
      encryptedFiles.add({
        'fileName': entry.key,
        'encryptedData': iv.bytes + encrypted.bytes,
      });
    }

    return encryptedFiles;
  }

  /// Builds device metadata for the backup header.
  Future<Map<String, dynamic>> _buildMetadata() async {
    String appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      appVersion = 'unknown';
    }

    return {
      'device': Platform.localHostname,
      'os': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'appVersion': appVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Packages encrypted files with the V2 header.
  ///
  /// V2 binary layout:
  /// ```
  /// KCBK (4) + version (1) + salt (16)
  /// + metadataLen (2 bytes big-endian) + metadata JSON (variable)
  /// + [file entries...]
  /// ```
  Future<File> _packageEncryptedFilesV2(
    List<Map<String, dynamic>> encryptedFiles,
    String outputPath,
    Uint8List salt,
    Map<String, dynamic> metadata,
  ) async {
    final outputFile = File(outputPath);
    final sink = outputFile.openWrite();

    // V2 fixed header
    sink
      ..add(utf8.encode(_v2Magic))
      ..add([_v2Version])
      ..add(salt);

    // Metadata section
    final metaBytes = utf8.encode(jsonEncode(metadata));
    final lenBytes = ByteData(2)..setUint16(0, metaBytes.length, Endian.big);
    sink
      ..add(lenBytes.buffer.asUint8List())
      ..add(metaBytes);

    // File entries (same binary structure as V1, but use byte length for names)
    for (final file in encryptedFiles) {
      final fileName = file['fileName'] as String;
      final fileNameBytes = utf8.encode(fileName);
      final encryptedData = file['encryptedData'] as List<int>;

      sink
        ..write(fileNameBytes.length.toString().padLeft(4, '0'))
        ..add(fileNameBytes)
        ..write(encryptedData.length.toString().padLeft(8, '0'))
        ..add(encryptedData);
    }

    await sink.close();
    return outputFile;
  }

  /// Exports the database with V2 encryption.
  ///
  /// Sensitive data (secure_storage, shared_prefs) is serialized and encrypted
  /// entirely in memory — no plaintext ever touches disk.
  Future<void> exportDB(String encryptionKey) async {
    final deviceName = Platform.localHostname.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
    final fileName =
        'Keychat_db_${deviceName}_${formatTime(DateTime.now().millisecondsSinceEpoch, 'yyyy-MM-dd_HH-mm-ss')}';
    final sourcePath = '${Utils.appFolder.path}/prod/database';
    final outputPath = '$sourcePath/$fileName';

    // 1. Serialize sensitive data to bytes in memory (never written to disk)
    final secureStorageBytes = utf8.encode(
      jsonEncode(await SecureStorage.instance.readAll()),
    );
    final sharedPrefsBytes = utf8.encode(
      jsonEncode(await _getSharedPrefsMap()),
    );

    final memoryFiles = <MapEntry<String, List<int>>>[
      MapEntry('secure_storage.json', secureStorageBytes),
      MapEntry('shared_prefs_export.json', sharedPrefsBytes),
    ];

    // 2. Generate random salt and derive key via Argon2id
    final salt = Uint8List.fromList(
      List.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final derivedKey = deriveKeyV2(encryptionKey, salt);

    // 3. Read database files from disk
    final dbFiles = await getDatabaseFiles(sourcePath);
    if (dbFiles.isEmpty) {
      logger.e('No database files found at: $sourcePath');
      return;
    }

    // 4. Encrypt everything
    final encryptedFiles = await _encryptFilesV2(
      dbFiles,
      memoryFiles,
      derivedKey,
    );

    // 5. Collect device metadata
    final metadata = await _buildMetadata();

    // 6. Package with V2 header
    final packagedFile = await _packageEncryptedFilesV2(
      encryptedFiles,
      outputPath,
      salt,
      metadata,
    );
    logger.i('Encrypted package created at: ${packagedFile.path}');

    // 7. Export via FilePicker
    await exportFile(packagedFile.path, fileName);
    if (await packagedFile.exists()) {
      await packagedFile.delete();
      logger.i('Temp file deleted: ${packagedFile.path}');
    }
  }

  Future<bool?> exportFile(String filePath, [String? fileName]) async {
    fileName ??= path.basename(filePath);
    final outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output path:',
      fileName: fileName,
      bytes: await File(filePath).readAsBytes(),
    );
    return outputFile != null;
  }

  // ---------------------------------------------------------------------------
  // Import: auto-detect V1 / V2 format
  // ---------------------------------------------------------------------------

  /// Imports a backup with safe rollback.
  ///
  /// Decrypts to a temporary directory first. Only replaces the real database
  /// after decryption succeeds. If decryption fails (wrong password, corrupt
  /// file, crash), the original data remains intact.
  Future<bool> importDB(String decryptionKey, File file) async {
    final sourcePath = '${Utils.appFolder.path}/prod/database/';
    final tempPath = '${Utils.appFolder.path}/prod/database_import_temp/';

    // 1. Decrypt to a temporary directory first
    final tempDir = Directory(tempPath);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    tempDir.createSync(recursive: true);

    final decryptOk = await _decryptPackageTo(
      file.path,
      decryptionKey,
      tempPath,
    );

    if (!decryptOk) {
      // Decryption failed — clean up temp dir, original data untouched
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
      return false;
    }

    // 2. Decryption succeeded — replace original database
    deleteAllFilesInDirectory(sourcePath);
    for (final entity in tempDir.listSync()) {
      if (entity is File) {
        final destPath = '$sourcePath${entity.uri.pathSegments.last}';
        entity.copySync(destPath);
      }
    }

    // 3. Import shared preferences and secure storage from the restored files
    await importSharedPreferences(sourcePath);
    await importSecureStorage(sourcePath);

    // 4. Clean up temp directory
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }

    return true;
  }

  /// Decrypts a backup package to [targetDirectory], auto-detecting V1/V2.
  ///
  /// Returns true only if all files decrypt successfully.
  Future<bool> _decryptPackageTo(
    String packagePath,
    String decryptionKey,
    String targetDirectory,
  ) async {
    try {
      final bytes = await File(packagePath).readAsBytes();

      if (_isV2Format(bytes)) {
        return _decryptV2(bytes, decryptionKey, targetDirectory);
      } else {
        return _decryptV1(bytes, decryptionKey, targetDirectory);
      }
    } catch (e, s) {
      logger.e('Import error: $e', stackTrace: s);
      return false;
    }
  }

  /// Returns true if the backup bytes start with the V2 magic header.
  static bool _isV2Format(Uint8List bytes) {
    if (bytes.length < _v2FixedHeaderSize) return false;
    return String.fromCharCodes(bytes.sublist(0, 4)) == _v2Magic;
  }

  // ---------------------------------------------------------------------------
  // V2 import
  // ---------------------------------------------------------------------------

  Future<bool> _decryptV2(
    Uint8List bytes,
    String decryptionKey,
    String targetDirectory,
  ) async {
    // Parse fixed header
    final salt = Uint8List.fromList(bytes.sublist(5, 21));
    final derivedKey = deriveKeyV2(decryptionKey, salt);

    // Parse metadata section (skip it — used for display only)
    var offset = _v2FixedHeaderSize;
    if (offset + 2 > bytes.length) {
      logger.e('V2 package too short for metadata length.');
      return false;
    }
    final metaLen = ByteData.sublistView(
      bytes,
      offset,
      offset + 2,
    ).getUint16(0, Endian.big);
    offset += 2 + metaLen;

    // Log metadata for diagnostics
    if (metaLen > 0) {
      try {
        final metaJson = utf8.decode(bytes.sublist(offset - metaLen, offset));
        logger.i('Importing backup: $metaJson');
      } catch (_) {
        // Metadata is optional, don't fail on parse error
      }
    }

    // Parse file entries after header + metadata
    final encryptedFiles = _parseFileEntries(
      Uint8List.sublistView(bytes, offset),
    );

    if (encryptedFiles.isEmpty) {
      logger.e('No files found in V2 package.');
      return false;
    }

    return _decryptAndRestore(
      encryptedFiles,
      encrypt.Key(derivedKey),
      targetDirectory,
    );
  }

  // ---------------------------------------------------------------------------
  // V1 import (legacy compatibility)
  // ---------------------------------------------------------------------------

  Future<bool> _decryptV1(
    Uint8List bytes,
    String decryptionKey,
    String targetDirectory,
  ) async {
    final key = encrypt.Key.fromUtf8(decryptionKey.padRight(32, '0'));
    final encryptedFiles = _parseFileEntries(bytes);

    if (encryptedFiles.isEmpty) {
      logger.e('No files found in V1 package.');
      return false;
    }

    return _decryptAndRestore(encryptedFiles, key, targetDirectory);
  }

  // ---------------------------------------------------------------------------
  // Shared parse / decrypt helpers
  // ---------------------------------------------------------------------------

  /// Parses the repeating file-entry structure from raw bytes.
  List<Map<String, dynamic>> _parseFileEntries(Uint8List bytes) {
    var offset = 0;
    final parsedFiles = <Map<String, dynamic>>[];

    while (offset < bytes.length) {
      if (offset + 4 > bytes.length) break;
      final fileNameLength = int.parse(
        String.fromCharCodes(bytes.sublist(offset, offset + 4)),
      );
      offset += 4;

      if (offset + fileNameLength > bytes.length) break;
      final fileName = utf8.decode(
        bytes.sublist(offset, offset + fileNameLength),
      );
      offset += fileNameLength;

      if (offset + 8 > bytes.length) break;
      final dataLength = int.parse(
        String.fromCharCodes(bytes.sublist(offset, offset + 8)),
      );
      offset += 8;

      if (offset + dataLength > bytes.length) break;
      final encryptedData = bytes.sublist(offset, offset + dataLength);
      offset += dataLength;

      parsedFiles.add({
        'fileName': fileName,
        'encryptedData': encryptedData,
      });
    }

    return parsedFiles;
  }

  /// Decrypts file entries and writes them to the target directory.
  ///
  /// Does NOT import shared preferences or secure storage — the caller is
  /// responsible for that after verifying decryption succeeded.
  Future<bool> _decryptAndRestore(
    List<Map<String, dynamic>> encryptedFiles,
    encrypt.Key key,
    String targetDirectory,
  ) async {
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    try {
      for (final file in encryptedFiles) {
        final encryptedData = file['encryptedData'] as List<int>;
        final fileName = file['fileName'] as String;

        final iv = encrypt.IV(Uint8List.fromList(encryptedData.sublist(0, 16)));
        final encryptedContent = Uint8List.fromList(encryptedData.sublist(16));

        final decrypted = encrypter.decryptBytes(
          encrypt.Encrypted(encryptedContent),
          iv: iv,
        );

        final targetFile = File('$targetDirectory$fileName');
        await targetFile.writeAsBytes(decrypted);
      }

      return true;
    } catch (e, s) {
      logger.e('Decryption error: $e', stackTrace: s);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Utility methods
  // ---------------------------------------------------------------------------

  void deleteAllFilesInDirectory(String targetDirectory) {
    final directory = Directory(targetDirectory);

    if (directory.existsSync()) {
      directory.listSync().forEach((entity) {
        if (entity is File) {
          try {
            entity.deleteSync();
          } catch (e) {
            logger.e('Error deleting file: ${entity.path}, $e');
          }
        }
      });
      logger.i('All files in $targetDirectory have been deleted.');
    } else {
      logger.e('Directory does not exist then create: $targetDirectory');
      directory.createSync(recursive: true);
    }
  }

  Future<File?> importFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      return File(result.files.single.path!);
    }
    return null;
  }

  /// Returns shared preferences as a JSON-serializable map.
  Future<Map<String, dynamic>> _getSharedPrefsMap() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys().fold<Map<String, dynamic>>({}, (map, key) {
      map[key] = prefs.get(key);
      return map;
    });
  }

  Future<void> importSharedPreferences(String importFilePath) async {
    try {
      await Storage.clearAll();
      final file = File('$importFilePath/shared_prefs_export.json');
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      for (final entry in data.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value is int) {
          await Storage.setInt(key, value);
        } else if (value is bool) {
          await Storage.setBool(key, value);
        } else if (value is String) {
          await Storage.setString(key, value);
        } else if (value is List<String>) {
          await Storage.setStringList(key, value);
        }
      }

      file.deleteSync();
      logger.i('Shared preferences imported.');
    } catch (e) {
      logger.e('Error importing shared preferences: $e');
    }
  }

  Future<void> importSecureStorage(String importFilePath) async {
    try {
      await SecureStorage.instance.clearAll();
      final filePath = '${importFilePath}secure_storage.json';

      final file = File(filePath);
      final jsonData = await file.readAsString();

      final allData = Map<String, String>.from(
        jsonDecode(jsonData) as Map<String, dynamic>,
      );

      for (final entry in allData.entries) {
        await SecureStorage.instance.write(entry.key, entry.value);
      }

      file.deleteSync();
      logger.i('Secure storage imported from $filePath');
    } catch (e) {
      logger.e('Error importing secure storage: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Password strength validation
  // ---------------------------------------------------------------------------

  /// Validates password meets minimum strength requirements.
  /// Returns an error message string, or null if the password is acceptable.
  static String? validatePasswordStrength(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!password.contains(RegExp('[A-Z]'))) {
      return 'Password must contain an uppercase letter';
    }
    if (!password.contains(RegExp('[a-z]'))) {
      return 'Password must contain a lowercase letter';
    }
    if (!password.contains(RegExp('[0-9]'))) {
      return 'Password must contain a digit';
    }
    return null;
  }
}
