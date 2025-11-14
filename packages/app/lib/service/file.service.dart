import 'dart:convert' show base64Encode, utf8;
import 'dart:io' show Directory, File;
import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;

import 'package:keychat/controller/setting.controller.dart';
import 'package:keychat/global.dart';
import 'package:keychat/models/db_provider.dart';
import 'package:keychat/models/embedded/msg_file_info.dart';
import 'package:keychat/models/message.dart';
import 'package:keychat/models/room.dart';
import 'package:keychat/service/message.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/service/s3.dart';
import 'package:keychat/utils.dart';
import 'package:keychat/utils/config.dart';
import 'package:dio/dio.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:encrypt/encrypt.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' hide Key;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart' hide Response;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:video_compress/video_compress.dart';

class FileEncryptInfo {
  FileEncryptInfo({
    required this.key,
    required this.output,
    required this.iv,
    required this.suffix,
    required this.hash,
    required this.sourceName,
  });
  FileEncryptInfo.fromJson(Map<String, dynamic> json) {
    output = json['output'] as Uint8List;
    iv = json['iv'] as String;
    suffix = json['suffix'] as String;
    key = json['key'] as String;
    hash = json['hash'] as String; // sha256
    sourceName = (json['sourceName'] ?? json['hash']) as String;
  }
  late Uint8List output;
  late String iv;
  late String suffix;
  late String key;
  late String hash; // sha256
  late String sourceName;
  String? ecashToken;
  String? url;
  int size = 0;
  Map<String, dynamic> toJson() {
    return {
      'iv': iv,
      'suffix': suffix,
      'key': key,
      'hash': hash,
      'sourceName': sourceName,
    };
  }
}

class FileService {
  // Avoid self instance
  FileService._();
  static FileService? _instance;
  static FileService get instance => _instance ??= FileService._();

  Future<File> decryptFile({
    required File input,
    required File output,
    required String key,
    required String iv,
  }) async {
    final encrypter = Encrypter(AES(Key.fromBase64(key), mode: AESMode.ctr));

    final encryptedBytes = Encrypted(await input.readAsBytes());
    final decryptedBytes = encrypter.decryptBytes(
      encryptedBytes,
      iv: IV.fromBase64(iv),
    );
    await output.writeAsBytes(decryptedBytes);
    return output;
  }

  Future<void> deleteAllByIdentity(int identity) async {
    final dir = Directory(
      '${Utils.appFolder.path}/${KeychatGlobal.baseFilePath}/$identity',
    );
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> deleteAllFolder() async {
    final dir = Directory('${Utils.appFolder.path}/${Config.env}/');
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
      logger.i('delete other file');
    }
  }

  void deleteFilesByTime(String path, DateTime fromAt) {
    final directory = Directory(path);
    if (directory.existsSync()) {
      directory.listSync().forEach((element) {
        if (element is File) {
          if (element.statSync().modified.isBefore(fromAt)) {
            element.delete();
          }
        } else if (element is Directory) {
          deleteFilesByTime(element.path, fromAt);
        }
      });
    }
  }

  Future<void> deleteFolderByRoomId(int identity, int roomId) async {
    final path = await getRoomFolder(identityId: identity, roomId: roomId);
    final directory = Directory(path);
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }

  Future<File> downloadAndDecrypt({
    required String url,
    required String suffix,
    required int identityId,
    required int roomId,
    required String key,
    required String iv,
    required MessageMediaType type,
    String? fileName,
    void Function(int count, int total)? onReceiveProgress,
  }) async {
    final input = await downloadFile(url, onReceiveProgress);
    if (input == null) throw Exception('File_download_faild');
    final dir = await getRoomFolder(
      identityId: identityId,
      roomId: roomId,
      type: type,
    );
    late String outputFile;
    if (fileName != null) {
      outputFile = '$dir$fileName';
    } else {
      outputFile = '$dir${path.basename(input.path)}';
      if (suffix.isNotEmpty) {
        outputFile += '.$suffix';
      }
    }

    final output = File(outputFile);
    return FileService.instance.decryptFile(
      input: input,
      output: output,
      key: key,
      iv: iv,
    );
  }

  /// Download and decrypt file from URL with custom save directory
  ///
  /// [url] - The URL to download from, example: "https://s3.keychat.io/s3.keychat.io/cS49k27IJoAyw3z0yXILIW_eI6_aYU7sbWbSn0PCYw8?kctype=image&suffix=png&key=vGUmQ0jnct7j%2BKgM2XXnvRyWOzBG0PsDlMo%2FbAiaWvM%3D&iv=diVdEf3QX4akMfRsqVeQBQ%3D%3D&size=6048&hash=cS49k27IJoAyw3z0yXILIW%2FeI6%2FaYU7sbWbSn0PCYw8%3D&sourceName=1758092675587_i4z8ci5q3yhb2o47.png"
  /// [outputFolder] - The directory where the decrypted file should be saved
  /// [onReceiveProgress] - Optional callback for download progress
  ///
  /// Returns the decrypted file with randomly generated filename
  Future<File> downloadAndDecryptToPath({
    required String url,
    required String outputFolder,
    void Function(int count, int total)? onReceiveProgress,
  }) async {
    // Parse URL to extract parameters
    final uri = Uri.parse(url);
    final key = uri.queryParameters['key'];
    final iv = uri.queryParameters['iv'];
    final suffix = uri.queryParameters['suffix'];

    if (key == null || iv == null) {
      throw Exception('Missing encryption parameters in URL');
    }

    // Create base URL without query parameters for download
    final baseUrl = '${uri.scheme}://${uri.host}${uri.path}';

    // Download the encrypted file
    final encryptedFile = await downloadFile(baseUrl, onReceiveProgress);
    if (encryptedFile == null) {
      throw Exception('File download failed');
    }

    try {
      // Ensure output directory exists
      final outputDir = Directory(outputFolder);
      await outputDir.create(recursive: true);

      // Generate random filename with suffix
      var randomFileName =
          '${DateTime.now().millisecondsSinceEpoch}_${Utils.randomInt(6)}';
      if (suffix != null && suffix.isNotEmpty) {
        randomFileName += '.$suffix';
      }

      final fullOutputPath = path.join(outputFolder, randomFileName);
      final outputFile = File(fullOutputPath);

      // Decrypt the file to the specified path
      final decryptedFile = await decryptFile(
        input: encryptedFile,
        output: outputFile,
        key: Uri.decodeComponent(key),
        iv: Uri.decodeComponent(iv),
      );

      // Clean up temporary encrypted file
      if (encryptedFile.existsSync()) {
        await encryptedFile.delete();
      }

      return decryptedFile;
    } catch (e) {
      // Clean up temporary file on error
      if (encryptedFile.existsSync()) {
        await encryptedFile.delete();
      }
      rethrow;
    }
  }

  Future<File?> downloadFile(
    String url, [
    void Function(int count, int total)? onReceiveProgress,
  ]) async {
    final dio = Dio();
    final outputDir = await getTemporaryDirectory();
    final fileName = path.basename(url);
    final output = path.join(outputDir.path, fileName);
    try {
      await dio.download(url, output, onReceiveProgress: onReceiveProgress);
      return File(output);
    } on DioException catch (e) {
      if (e.response != null) {
        logger.e('repsponse: ${e.response}', error: e);
      } else {
        logger.e('error no repsponse', error: e);
      }
    }
    return null;
  }

  Future<void> downloadForMessage(
    Message message,
    MsgFileInfo mfi, {
    void Function(MsgFileInfo fi)? callback,
    void Function(int count, int total)? onReceiveProgress,
  }) async {
    final uri = Uri.parse(message.content);
    final outputFilePath = await getOutputFilePath(message, mfi, uri);
    var newFile = File(outputFilePath);
    final exist = newFile.existsSync();
    try {
      // file not exist
      if (!exist) {
        mfi
          ..status = FileStatus.downloading
          ..updateAt = DateTime.now();
        message.realMessage = mfi.toString();
        await updateMessageAndCallback(message, mfi, callback);
        newFile = await downloadAndDecrypt(
          identityId: message.identityId,
          url: '${uri.origin}${uri.path}',
          suffix: mfi.suffix ?? '',
          roomId: message.roomId,
          key: mfi.key!,
          iv: mfi.iv!,
          type: message.mediaType,
          fileName: mfi.sourceName,
          onReceiveProgress: onReceiveProgress,
        );
      } else {
        // file exist, check the hash, then save the file using a new name
        final List<int> bytes = await newFile.readAsBytes();
        final existFileHash = await rust_nostr.sha256HashBytes(data: bytes);

        // not the same file, check hash first
        if (existFileHash != mfi.hash) {
          // If the hash doesn't match, rename the file and re-download
          logger.i('File hash mismatch: $existFileHash != ${mfi.hash}');
          final fileName = path.basename(newFile.path);
          final fileNameWithoutExt = fileName.contains('.')
              ? fileName.substring(0, fileName.lastIndexOf('.'))
              : fileName;
          final extension = fileName.contains('.')
              ? fileName.substring(fileName.lastIndexOf('.'))
              : '';

          // Generate random string for filename
          final randomString = Utils.randomInt(4);
          final newFileName = '${fileNameWithoutExt}_$randomString$extension';

          // Re-download the file
          mfi
            ..status = FileStatus.downloading
            ..updateAt = DateTime.now();
          message.realMessage = mfi.toString();
          await updateMessageAndCallback(message, mfi, callback);
          newFile = await downloadAndDecrypt(
            identityId: message.identityId,
            url: '${uri.origin}${uri.path}',
            suffix: mfi.suffix ?? '',
            roomId: message.roomId,
            key: mfi.key!,
            iv: mfi.iv!,
            type: message.mediaType,
            fileName: newFileName,
            onReceiveProgress: onReceiveProgress,
          );
        }
      }

      mfi
        ..status = FileStatus.decryptSuccess
        ..updateAt = DateTime.now()
        ..localPath = newFile.path.replaceFirst(Utils.appFolder.path, '');
      message.realMessage = mfi.toString();
      final isCurrentPage = DBProvider.instance.isCurrentPage(message.roomId);
      if (isCurrentPage) {
        message.isRead = true;
      }
      // generate thumbnail for video
      if (message.mediaType == MessageMediaType.video) {
        getOrCreateThumbForVideo(newFile.path);
      }
      await updateMessageAndCallback(message, mfi, callback);
    } catch (e, s) {
      // mark as failed
      logger.e(e.toString(), error: e, stackTrace: s);
      mfi
        ..status = FileStatus.failed
        ..updateAt = DateTime.now();
      message.realMessage = mfi.toString();
      await updateMessageAndCallback(message, mfi, callback);
    }
  }

  /// Download avatar from URL and save to local avatars folder
  Future<String?> downloadAndSaveAvatar(String avatarUrl, String pubkey) async {
    try {
      EasyLoading.show(status: 'Downloading avatar...');

      // Get file extension from URL
      final uri = Uri.parse(avatarUrl);
      var extension = path.extension(uri.path).toLowerCase();
      if (extension.isEmpty) {
        extension = '.png'; // Default extension
      }

      // Generate filename based on pubkey
      final filename = '${Utils.randomString(16)}$extension';
      final localPath = path.join(Utils.avatarsFolder, filename);
      final localFile = File(localPath);

      // Download the file
      final downloadedFile = await FileService.instance
          .downloadFile(
            avatarUrl,
            (int count, int total) async {
              EasyThrottle.throttle(
                'downloadAndSaveAvatar$avatarUrl',
                const Duration(milliseconds: 300),
                () async {
                  if (total > 0) {
                    await EasyLoading.showProgress(
                      count / total,
                      status: 'Downloading avatar...',
                    );
                  }
                },
              );
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () async {
              await EasyLoading.dismiss();
              await EasyLoading.showError('Download timeout');
              return null;
            },
          );

      if (downloadedFile != null) {
        // Copy to avatars folder
        await downloadedFile.copy(localPath);
        await downloadedFile.delete(); // Clean up temp file

        EasyLoading.dismiss();
        EasyLoading.showSuccess('Avatar downloaded');

        // Return relative path
        return localFile.path.replaceFirst(Utils.appFolder.path, '');
      }
      EasyLoading.dismiss();
    } catch (e, s) {
      EasyLoading.dismiss();
      EasyLoading.showError('Failed to download avatar');
      logger.e(
        'Failed to download avatar from $avatarUrl: $e',
        error: e,
        stackTrace: s,
      );
    }
    return null;
  }

  Future<MsgFileInfo?> encryptAndUploadImage(
    XFile xfile, {
    String? localFilePath,
    bool writeToLocal = true,
    bool compress = false,
    void Function(int count, int total)? onSendProgress,
  }) async {
    // Create temporary file first
    final tempDir = await getTemporaryDirectory();
    final tempFileName =
        '${DateTime.now().millisecondsSinceEpoch}_${xfile.name}';
    final tempFile = File('${tempDir.path}/$tempFileName');

    EasyLoading.show(status: 'Encrypting and Uploading avatar...');

    try {
      // Write to temporary file
      await tempFile.writeAsBytes(await xfile.readAsBytes());

      final selectedMediaServer =
          Get.find<SettingController>().selectedMediaServer.value;
      final uri = Uri.parse(selectedMediaServer);
      late FileEncryptInfo fileInfo;

      // Wrap the progress callback to show loading status
      void progressCallback(int count, int total) {
        EasyThrottle.throttle(
          'uploadImageProgress${xfile.path}',
          const Duration(milliseconds: 300),
          () {
            if (total > 0) {
              EasyLoading.showProgress(
                count / total,
                status: 'Encrypting and Uploading avatar...',
              );
            }
          },
        );
      }

      EasyLoading.showProgress(
        0.1,
        status: 'Encrypting and Uploading avatar...',
      );

      if (uri.host == 'relay.keychat.io') {
        fileInfo = await AwsS3.instance
            .encryptAndUploadByRelay(tempFile, onSendProgress: progressCallback)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                EasyLoading.dismiss();
                EasyLoading.showError('Upload timeout');
                throw Exception('Upload timeout after 30 seconds');
              },
            );
      } else {
        try {
          fileInfo =
              await uploadToBlossom(
                input: tempFile,
                onSendProgress: progressCallback,
              ).timeout(
                const Duration(seconds: 30),
                onTimeout: () {
                  EasyLoading.dismiss();
                  EasyLoading.showError('Upload timeout');
                  throw Exception('Upload timeout after 30 seconds');
                },
              );
        } catch (e, s) {
          EasyLoading.dismiss();
          logger.e('Upload to blossom failed: $e', stackTrace: s);
          await Get.dialog(
            CupertinoAlertDialog(
              title: const Text('Upload Failed'),
              content: const Column(
                children: [
                  Text(
                    'Check your blossom servers, make sure your subscription is valid.',
                  ),
                  Text(
                    'Make sure your server support uploading encrypted files.',
                  ),
                  Text('Tab:Me -> Chat Settings -> Media Relay'),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: Get.back,
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return null;
        }
      }

      EasyLoading.showSuccess('Upload complete');

      // Upload successful, now write to local file
      String? relativePath;
      if (writeToLocal && localFilePath != null) {
        final localFile = File(localFilePath);
        await localFile.parent.create(recursive: true);
        await localFile.writeAsBytes(await tempFile.readAsBytes());
        relativePath = localFile.path.replaceFirst(Utils.appFolder.path, '');
      }

      return MsgFileInfo()
        ..fileInfo = fileInfo
        ..localPath = relativePath
        ..url = fileInfo.url
        ..suffix = fileInfo.suffix
        ..key = fileInfo.key
        ..iv = fileInfo.iv
        ..size = fileInfo.size
        ..hash = fileInfo.hash
        ..updateAt = DateTime.now()
        ..sourceName = fileInfo.sourceName
        ..status = FileStatus.decryptSuccess;
    } catch (e, s) {
      logger.e('Error in encryptAndUploadImage: $e', stackTrace: s);
      EasyLoading.dismiss();
      EasyLoading.showError('Upload failed: $e');
      rethrow;
    } finally {
      // Clean up temporary file
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }

      // Make sure to dismiss the loading indicator if it's still showing
      Future.delayed(const Duration(milliseconds: 500), EasyLoading.dismiss);
    }
  }

  Future<FileEncryptInfo> encryptFile(
    File input, {
    bool base64Hash = false,
  }) async {
    final iv = IV.fromSecureRandom(16);
    final salt = SecureRandom(16).bytes;
    final key = Key.fromUtf8(
      Random(16).nextInt(10).toString(),
    ).stretch(32, salt: salt);
    final encrypter = Encrypter(AES(key, mode: AESMode.ctr));
    final fileName = path.basename(input.path);
    final encryptedBytes = encrypter.encryptBytes(
      Uint8List.fromList(await input.readAsBytes()),
      iv: iv,
    );
    var sha256Result = await rust_nostr.sha256HashBytes(
      data: encryptedBytes.bytes,
    );
    if (base64Hash) {
      sha256Result = base64Encode(Utils.hexToBytes(sha256Result));
    }
    return FileEncryptInfo.fromJson({
      'output': encryptedBytes.bytes,
      'iv': iv.base64,
      'key': key.base64,
      'suffix': fileName.contains('.') ? fileName.split('.').last : '',
      'hash': sha256Result,
      'sourceName': fileName,
    });
  }

  Future<MsgFileInfo?> encryptToSendFile(
    Room room,
    XFile xfile,
    MessageMediaType type, {
    bool compress = false,
    void Function(int count, int total)? onSendProgress,
  }) async {
    final appDocPath = await getRoomFolder(
      identityId: room.identityId,
      roomId: room.id,
      type: type,
    );

    final newPath = await getNewFilePath(appDocPath, xfile.path);
    var fileBytes = <int>[];
    if (type == MessageMediaType.image && compress) {
      final sourceInput = await img.decodeImageFile(xfile.path);
      if (sourceInput == null) {
        throw Exception('Image decode failed');
      }
      sourceInput.exif = img.ExifData();
      fileBytes = img.encodeJpg(sourceInput, quality: 70);
      // img.Image? processedImage =
      //     img.decodeImage(Uint8List.fromList(fileBytes));
      // print('Processed EXIF: ${processedImage?.exif.toString()}');
    } else if (type == MessageMediaType.video) {
      if (compress) {
        MediaInfo? compressedFile;
        try {
          // try compressed video
          compressedFile = await VideoCompress.compressVideo(
            xfile.path,
          );
          if (compressedFile?.path != null) {
            fileBytes = await File(compressedFile!.path!).readAsBytes();
          }
        } catch (e) {
          logger.e('Video compression failed: $e');
        }
      }
    }
    if (fileBytes.isEmpty) {
      fileBytes = await xfile.readAsBytes();
    }
    final newFile = File(newPath);
    await newFile.writeAsBytes(fileBytes);
    final selectedMediaServer =
        Get.find<SettingController>().selectedMediaServer.value;
    final uri = Uri.parse(selectedMediaServer);
    late FileEncryptInfo fileInfo;
    if (uri.host == 'relay.keychat.io') {
      fileInfo = await AwsS3.instance.encryptAndUploadByRelay(
        newFile,
        onSendProgress: onSendProgress,
      );
    } else {
      try {
        fileInfo = await uploadToBlossom(
          input: newFile,
          onSendProgress: onSendProgress,
        );
      } catch (e, s) {
        logger.e('Upload to blossom failed: $e', stackTrace: s);
        Get.dialog(
          CupertinoAlertDialog(
            title: const Text('Upload Failed'),
            content: const Column(
              children: [
                Text(
                  'Check your blossom servers, make sure your subscription is valid.',
                ),
                Text(
                  'Make sure your server support uploading encrypted files.',
                ),
                Text('Tab:Me -> Chat Settings -> Media Relay'),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: Get.back,
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return null;
      }
    }

    final relativePath = newFile.path.replaceFirst(Utils.appFolder.path, '');
    return MsgFileInfo()
      ..fileInfo = fileInfo
      ..localPath = relativePath
      ..url = fileInfo.url
      ..suffix = fileInfo.suffix
      ..key = fileInfo.key
      ..iv = fileInfo.iv
      ..size = fileInfo.size
      ..hash = fileInfo.hash
      ..updateAt = DateTime.now()
      ..ecashToken = fileInfo.ecashToken
      ..sourceName = fileInfo.sourceName
      ..status = FileStatus.decryptSuccess;
  }

  String getAbsolutelyFilePath(String appFolder, String localPath) {
    if (localPath.startsWith('/var/mobile')) {
      final file = localPath.split(KeychatGlobal.baseFilePath).last;
      return '$appFolder/${KeychatGlobal.baseFilePath}$file';
    }
    return appFolder + localPath;
  }

  String getDisplayFileName(String filePath, [int maxLength = 10]) {
    var fullName = filePath;
    if (filePath.length < maxLength) return filePath;
    if (filePath.contains('/')) {
      fullName = path.basename(filePath);
    }
    if (!fullName.contains('.')) return fullName;
    var name = fullName.split('.').first;
    final suffix = fullName.split('.').last;

    if (name.length > 10) {
      name = '${name.substring(0, 5)}...${name.substring(name.length - 5)}';
    }
    return '$name.$suffix';
  }

  String getFileSizeDisplay(int size) {
    const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB'];
    var digitGroups = 0;
    while (size >= 1024) {
      size ~/= 1024;
      digitGroups++;
    }
    return '$size ${units[digitGroups]}';
  }

  Widget getImageView(File file, [double width = 150, double height = 150]) {
    final isSVG = file.path.endsWith('.svg');

    if (isSVG) {
      return SvgPicture.file(
        file,
        width: width,
        height: height,
        fit: BoxFit.fitWidth,
      );
    }

    return Image.file(
      file,
      width: width,
      fit: BoxFit.fitWidth,
    );
  }

  Future<String> getNewFilePath(
    String appDocPath,
    String sourceFilePath,
  ) async {
    final fileName = path.basename(sourceFilePath);
    var newFilePath = path.join(appDocPath, fileName);
    var newFile = File(newFilePath);
    final exist = await newFile.exists();
    if (!exist) {
      return newFilePath;
    }

    // Split the filename and extension
    final fileNameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final extension = fileName.contains('.')
        ? fileName.substring(fileName.lastIndexOf('.'))
        : '';

    var counter = 1;
    while (await newFile.exists()) {
      // Create a new filename with counter
      final newFileName = '${fileNameWithoutExt}_$counter$extension';
      newFilePath = appDocPath + newFileName;
      newFile = File(newFilePath);
      counter++;
    }

    return newFilePath;
  }

  Future<File> getOrCreateThumbForVideo(String videoFilePath) async {
    final thumbnailFilePath = getVideoThumbPath(videoFilePath);
    final thumbnailFile = File(thumbnailFilePath);
    final exist = await thumbnailFile.exists();
    if (exist) {
      if (await thumbnailFile.length() > 0) {
        return File(thumbnailFilePath);
      }
    }

    final file = File(videoFilePath);
    final thumbnail = await VideoCompress.getFileThumbnail(
      file.path,
      quality: 75,
    );
    await thumbnailFile.writeAsBytes(await thumbnail.readAsBytes());
    return File(thumbnailFilePath);
  }

  Future<String> getOutputFilePath(
    Message message,
    MsgFileInfo mfi,
    Uri uri,
  ) async {
    final dir = await getRoomFolder(
      identityId: message.identityId,
      roomId: message.roomId,
      type: message.mediaType,
    );
    late String outputFilePath;
    if (mfi.sourceName != null) {
      outputFilePath = '$dir${mfi.sourceName}';
    } else {
      outputFilePath = '$dir${path.basename(uri.path)}';
      if (mfi.suffix != null) {
        outputFilePath += mfi.suffix!;
      }
    }
    return outputFilePath;
  }

  Future<String> getRoomFolder({
    required int identityId,
    required int roomId,
    MessageMediaType? type,
  }) async {
    var outputPath =
        '${Utils.appFolder.path}/${KeychatGlobal.baseFilePath}/$identityId/$roomId/';

    if (type != null) {
      outputPath += '${type.name}/';
    }
    final dir = Directory(outputPath);
    final exist = dir.existsSync();
    if (!exist) {
      await dir.create(recursive: true);
    }
    return outputPath;
  }

  Future<List<File>> getRoomImageAndVideo(int identityId, int roomId) async {
    final imageDirectory = await getRoomFolder(
      identityId: identityId,
      roomId: roomId,
      type: MessageMediaType.image,
    );

    final files = Directory(imageDirectory).listSync(recursive: true);
    final res = <File>[];
    for (final file in files) {
      if (file is File && isImageFile(file.path)) {
        res.add(file);
      }
    }

    // video
    final videoDirectory = await getRoomFolder(
      identityId: identityId,
      roomId: roomId,
      type: MessageMediaType.video,
    );
    final files2 = Directory(videoDirectory).listSync(recursive: true);
    for (final file in files2) {
      if (file is File && isVideoFile(file.path)) {
        res.add(file);
      }
    }
    res.sort((a, b) => b.statSync().changed.compareTo(a.statSync().changed));
    if (res.length > 50) return res.sublist(0, 50);

    return res;
  }

  Future<Map> getUploadParams({
    required String cashu,
    required int length,
    required String sha256,
  }) async {
    try {
      final dio = Dio();
      final headers = {'Content-type': 'application/json'};
      const url = '${KeychatGlobal.defaultFileServer}/api/v1/object';
      final response = await dio.post(
        url,
        data: {
          'cashu': cashu,
          'length': length,
          'sha256': sha256,
        },
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        return response.data as Map;
      }
    } on DioException catch (e, s) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      if (e.response != null) {
        logger.e(e.response?.data, stackTrace: s);
      } else {
        // Something happened in setting up or sending the request that triggered an Error
        logger.e(e.message, stackTrace: s);
        throw Exception('Fetch_upload_params_failed: ${e.message ?? ''}');
      }
    }
    throw Exception('Fetch upload params failed');
  }

  String getVideoThumbPath(String videoFilePath) {
    final fileDir = path.dirname(videoFilePath);
    final fileName = path.basenameWithoutExtension(videoFilePath);
    return '$fileDir/${fileName}_thumb.jpg';
  }

  Future<Message?> handleFileUpload(Room room, [XFile? xfile]) async {
    if (xfile == null) {
      final result = await FilePicker.platform.pickFiles();
      if (result == null) return null;
      xfile = result.files.first.xFile;
    }

    if (FileService.instance.isImageFile(xfile.path)) {
      return handleSendMediaFile(room, xfile, MessageMediaType.image);
    }

    if (FileService.instance.isVideoFile(xfile.path)) {
      return handleSendMediaFile(
        room,
        xfile,
        MessageMediaType.video,
        compress: true,
      );
    }
    await handleSendMediaFile(room, xfile, MessageMediaType.file);
    return null;
  }

  Future<Message?> handleSendMediaFile(
    Room room,
    XFile xfile,
    MessageMediaType mediaType, {
    bool compress = false,
  }) async {
    try {
      final statusMessage = mediaType != MessageMediaType.image
          ? 'Encrypting and Uploading...'
          : '''
1. Remove EXIF info
2. Encrypting 
3. Uploading''';
      EasyLoading.showProgress(0.1, status: statusMessage);
      EasyLoading.showProgress(0.2, status: statusMessage);
      final mfi = await FileService.instance.encryptToSendFile(
        room,
        xfile,
        mediaType,
        compress: compress,
        onSendProgress: (count, total) =>
            FileService.instance.onSendProgress(statusMessage, count, total),
      );
      logger.d('FileService: handleSendMediaFile: $mfi');
      if (mfi == null || mfi.fileInfo == null) return null;
      EasyLoading.showProgress(1, status: statusMessage);
      final smr = await RoomService.instance.sendMessage(
        room,
        mfi.getUriString(mediaType.name),
        realMessage: mfi.toString(),
        mediaType: mediaType,
      );

      Future.delayed(const Duration(milliseconds: 500)).then((_) {
        EasyLoading.dismiss();
      });
      return smr.message;
    } catch (e, s) {
      final msg = Utils.getErrorMessage(e);
      logger.e('encrypt And SendFile $msg', error: e, stackTrace: s);
      EasyLoading.showError(msg, duration: const Duration(seconds: 3));
    } finally {
      RoomService.getController(room.id)?.hideAdd.value = true;
      Future.delayed(const Duration(seconds: 2)).then((_) {
        EasyLoading.dismiss();
      });
    }
    return null;
  }

  // check text is image
  bool isImage(String text) {
    final regex = RegExp(
      r'(https?://\S+\.(?:jpg|bmp|gif|ico|pcx|jpeg|tif|png|raw))',
      caseSensitive: false,
    );
    return regex.hasMatch(text);
  }

  /// Check if file path is an image file
  bool isImageFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.tiff',
      '.svg',
    ].contains(extension);
  }

  /// Check if file path is a video file
  bool isVideoFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return [
      '.mp4',
      '.avi',
      '.mov',
      '.mkv',
      '.webm',
      '.flv',
      '.wmv',
      '.m4v',
    ].contains(extension);
  }

  void onSendProgress(String status, int count, int total) {
    EasyThrottle.throttle(
      'onSendProgress',
      const Duration(milliseconds: 100),
      () {
        if (count == total && total != 0) {
          EasyLoading.showSuccess('Upload success');
          return;
        }
        var progress = count / total;
        if (progress < 0.2) {
          progress = 0.2;
        }
        EasyLoading.showProgress(progress, status: status);
      },
    );
  }

  // pick image only
  Future<XFile?> pickImage(ImageSource imageSource) async {
    final picker = ImagePicker();
    return picker.pickImage(source: imageSource, imageQuality: 75);
  }

  // Pick singe image or video.
  Future<XFile?> pickMedia() async {
    final picker = ImagePicker();
    return picker.pickMedia(imageQuality: 50);
  }

  // Pick a video only
  Future<XFile?> pickVideo(ImageSource imageSource) async {
    final picker = ImagePicker();
    return picker.pickVideo(
      source: imageSource,
      maxDuration: const Duration(minutes: 1),
    );
  }

  Future<FileEncryptInfo> uploadToBlossom({
    required File input,
    void Function(int, int)? onSendProgress,
  }) async {
    final fe = await FileService.instance.encryptFile(input);

    fe.size = fe.output.length;
    // Generate a new key pair
    final random = await rust_nostr.generateSecp256K1();
    final eventString = await rust_nostr.signEvent(
      senderKeys: random.prikey,
      content: fe.hash,
      createdAt: BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      kind: 24242,
      tags: [
        ['t', 'upload'],
        ['x', fe.hash],
        [
          'expiration',
          (DateTime.now()
                      .add(const Duration(days: 30))
                      .millisecondsSinceEpoch ~/
                  1000)
              .toString(),
        ],
      ],
    );
    final server = Get.find<SettingController>().selectedMediaServer.value;
    String? errorMessage;
    try {
      final dio = Dio();
      final response = await dio.put(
        '$server/upload',
        data: Stream.fromIterable(fe.output.map((e) => [e])),
        onSendProgress: onSendProgress,
        options: Options(
          sendTimeout: const Duration(seconds: 120),
          headers: {
            'Content-Type': 'application/octet-stream',
            'Authorization': 'Nostr ${base64Encode(utf8.encode(eventString))}',
          },
        ),
      );

      if (response.statusCode == 200) {
        logger.i('Success ${random.pubkey}: ${response.data}');
        fe.url = response.data['url'] as String? ?? '';
        fe.size = response.data['size'] as int? ?? fe.size;
        return fe;
      }
    } on DioException catch (e, s) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      if (e.response != null) {
        logger.e('Server $server failed: ${e.response?.data}', stackTrace: s);
        errorMessage = e.response?.data as String?;
      } else {
        errorMessage = e.message;
        logger.e('Server $server failed: ${e.message}', stackTrace: s);
      }
    } catch (e, s) {
      logger.e('Server $server failed: $e', stackTrace: s);
    }

    // If all servers fail, throw an exception
    throw Exception(errorMessage ?? 'Failed to upload file to $server');
  }

  static String getFileTypeFromBytes(Uint8List bytes) {
    if (bytes.length < 8) {
      return 'Unknow';
    }
    // Check file signatures (magic numbers)
    final List<int> header = bytes.sublist(0, 8);

    // Check for common image formats
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    if (bytes.length >= 8 &&
        header[0] == 0x89 &&
        header[1] == 0x50 &&
        header[2] == 0x4E &&
        header[3] == 0x47 &&
        header[4] == 0x0D &&
        header[5] == 0x0A &&
        header[6] == 0x1A &&
        header[7] == 0x0A) {
      return 'image/png';
    }

    if (bytes.length >= 4 &&
        header[0] == 0x47 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x38) {
      return 'image/gif';
    }

    if (bytes.length >= 4 &&
        ((header[0] == 0x49 &&
                header[1] == 0x49 &&
                header[2] == 0x2A &&
                header[3] == 0x00) ||
            (header[0] == 0x4D &&
                header[1] == 0x4D &&
                header[2] == 0x00 &&
                header[3] == 0x2A))) {
      return 'image/tiff';
    }

    // Check for PDF
    if (bytes.length >= 5 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D) {
      return 'application/pdf';
    }

    // Check for common video formats
    if (bytes.length >= 8 &&
        header[4] == 0x66 &&
        header[5] == 0x74 &&
        header[6] == 0x79 &&
        header[7] == 0x70) {
      return 'video/mp4';
    }

    // Check for WebM
    if (bytes.length >= 4 &&
        header[0] == 0x1A &&
        header[1] == 0x45 &&
        header[2] == 0xDF &&
        header[3] == 0xA3) {
      return 'video/webm';
    }

    // Check for ZIP-based formats
    if (bytes.length >= 4 &&
        header[0] == 0x50 &&
        header[1] == 0x4B &&
        header[2] == 0x03 &&
        header[3] == 0x04) {
      return 'application/zip';
    }

    // Check for common document formats
    if (bytes.length >= 8 &&
        header[0] == 0xD0 &&
        header[1] == 0xCF &&
        header[2] == 0x11 &&
        header[3] == 0xE0 &&
        header[4] == 0xA1 &&
        header[5] == 0xB1 &&
        header[6] == 0x1A &&
        header[7] == 0xE1) {
      return 'application/vnd.ms-office';
    }
    return 'application/octet-stream';
  }

  static Future<void> updateMessageAndCallback(
    Message message,
    MsgFileInfo mfi, [
    Function(MsgFileInfo fi)? callback,
  ]) async {
    await MessageService.instance.updateMessage(message);
    if (callback != null) {
      callback(mfi);
    } else {
      MessageService.instance.refreshMessageInPage(message);
    }
  }
}
