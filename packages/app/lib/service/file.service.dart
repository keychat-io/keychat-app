import 'dart:convert' show base64Encode, utf8;
import 'dart:io' show File, Directory, FileSystemEntity;
import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;
import 'package:app/controller/setting.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/embedded/msg_file_info.dart';
import 'package:app/models/message.dart';
import 'package:app/models/room.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/s3.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' hide Key;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart' hide Response;
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';
import 'package:image_picker/image_picker.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:video_compress/video_compress.dart';
import 'package:image/image.dart' as img;
import 'package:app/utils/config.dart';

class FileEncryptInfo {
  late Uint8List output;
  late String iv;
  late String suffix;
  late String key;
  late String hash; // sha256
  late String sourceName;
  String? ecashToken;
  String? url;
  int size = 0;
  FileEncryptInfo(
      {required this.key,
      required this.output,
      required this.iv,
      required this.suffix,
      required this.hash,
      required this.sourceName});
  FileEncryptInfo.fromJson(Map<String, dynamic> json) {
    output = json['output'];
    iv = json['iv'];
    suffix = json['suffix'];
    key = json['key'];
    hash = json['hash'];
    sourceName = json['sourceName'] ?? json['hash'];
  }
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
  static FileService? _instance;
  static FileService get instance => _instance ??= FileService._();
  // Avoid self instance
  FileService._();

  Future<Message?> handleFileUpload(Room room, [XFile? xfile]) async {
    if (xfile == null) {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result == null) return null;
      xfile = result.files.first.xFile;
    }

    if (FileService.instance.isImageFile(xfile.path)) {
      return handleSendMediaFile(room, xfile, MessageMediaType.image, true);
    }

    if (FileService.instance.isVideoFile(xfile.path)) {
      return handleSendMediaFile(room, xfile, MessageMediaType.video, true);
    }
    handleSendMediaFile(room, xfile, MessageMediaType.file, false);
    return null;
  }

  Future<Message?> handleSendMediaFile(
      Room room, XFile xfile, MessageMediaType mediaType, bool compress) async {
    try {
      String statusMessage = mediaType != MessageMediaType.image
          ? 'Encrypting and Uploading...'
          : '''1. Remove EXIF info
2. Encrypting 
3. Uploading''';
      EasyLoading.showProgress(0.0, status: statusMessage);
      EasyLoading.showProgress(0.2, status: statusMessage);
      MsgFileInfo? mfi = await FileService.instance.encryptAndSendFile(
          room, xfile, mediaType,
          compress: compress,
          onSendProgress: (count, total) =>
              FileService.instance.onSendProgress(statusMessage, count, total));
      if (mfi == null || mfi.fileInfo == null) return null;
      EasyLoading.showProgress(1, status: statusMessage);
      SendMessageResponse smr = await RoomService.instance.sendMessage(
          room, mfi.getUriString(mediaType.name, mfi.fileInfo!),
          realMessage: mfi.toString(), mediaType: mediaType);

      Future.delayed(Duration(milliseconds: 500)).then((_) {
        EasyLoading.dismiss();
      });
      return smr.message;
    } catch (e, s) {
      EasyLoading.showError(Utils.getErrorMessage(e),
          duration: const Duration(seconds: 3));
      logger.e('encrypt And SendFile', error: e, stackTrace: s);
    } finally {
      RoomService.getController(room.id)?.hideAdd.value = true;
      Future.delayed(Duration(seconds: 2)).then((_) {
        EasyLoading.dismiss();
      });
    }
    return null;
  }

  Future<File> decryptFile(
      {required File input,
      required File output,
      required String key,
      required String iv}) async {
    final encrypter = Encrypter(AES(Key.fromBase64(key), mode: AESMode.ctr));

    final encryptedBytes = Encrypted(await input.readAsBytes());
    final decryptedBytes =
        encrypter.decryptBytes(encryptedBytes, iv: IV.fromBase64(iv));
    await output.writeAsBytes(decryptedBytes);
    return output;
  }

  Future<FileEncryptInfo> encryptFile(File input,
      {bool base64Hash = false}) async {
    final iv = IV.fromSecureRandom(16);
    final salt = SecureRandom(16).bytes;
    final key =
        Key.fromUtf8(Random(16).nextInt(10).toString()).stretch(32, salt: salt);
    final encrypter = Encrypter(AES(key, mode: AESMode.ctr));
    String fileName = input.path.split('/').last;
    final encryptedBytes = encrypter
        .encryptBytes(Uint8List.fromList(await input.readAsBytes()), iv: iv);
    String sha256Result =
        await rust_nostr.sha256HashBytes(data: encryptedBytes.bytes);
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

  // check text is image
  bool isImage(String text) {
    final regex = RegExp(
        r'(https?://\S+\.(?:jpg|bmp|gif|ico|pcx|jpeg|tif|png|raw))',
        caseSensitive: false);
    return regex.hasMatch(text);
  }

  Future<Map> getUploadParams(
      {required String cashu,
      required int length,
      required String sha256}) async {
    try {
      final dio = Dio();
      final headers = {'Content-type': 'application/json'};
      String url = '${KeychatGlobal.defaultFileServer}/api/v1/object';
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
        return response.data;
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

  String getAbsolutelyFilePath(String appFolder, String localPath) {
    if (localPath.startsWith('/var/mobile')) {
      String file = localPath.split(KeychatGlobal.baseFilePath).last;
      return '$appFolder/${KeychatGlobal.baseFilePath}$file';
    }
    return appFolder + localPath;
  }

  String getVideoThumbPath(String videoFilePath) {
    String fullFileName = videoFilePath.split('/').last;
    String fileDir = videoFilePath.replaceAll(fullFileName, '');
    String fileName = fullFileName.split('.').first;
    return '$fileDir${fileName}_thumb.jpg';
  }

  Future<File> getOrCreateThumbForVideo(String videoFilePath) async {
    String thumbnailFilePath = getVideoThumbPath(videoFilePath);
    var thumbnailFile = File(thumbnailFilePath);
    bool exist = await thumbnailFile.exists();
    if (exist) {
      if (await thumbnailFile.length() > 0) {
        return File(thumbnailFilePath);
      }
    }

    File file = File(videoFilePath);
    File thumbnail = await VideoCompress.getFileThumbnail(
      file.path,
      quality: 75,
    );
    await thumbnailFile.writeAsBytes(await thumbnail.readAsBytes());
    return File(thumbnailFilePath);
  }

  onSendProgress(String status, int count, int total) {
    EasyThrottle.throttle('onSendProgress', Duration(milliseconds: 100), () {
      if (count == total && total != 0) {
        EasyLoading.showSuccess('Upload success');
        return;
      }
      double progress = count / total;
      if (progress < 0.2) {
        progress = 0.2;
      }
      EasyLoading.showProgress(progress, status: status);
    });
  }

  Widget getImageView(File file, [double width = 150, double height = 150]) {
    bool isSVG = file.path.endsWith('.svg');

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

  Future<String> getRoomFolder(
      {required int identityId,
      required int roomId,
      MessageMediaType? type}) async {
    Directory appFolder = await Utils.getAppFolder();
    String outputPath =
        '${appFolder.path}/${KeychatGlobal.baseFilePath}/$identityId/$roomId/';

    if (type != null) {
      outputPath += '${type.name}/';
    }
    Directory dir = Directory(outputPath);
    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }
    return outputPath;
  }

  Future<List<File>> getRoomImageAndVideo(int identityId, int roomId) async {
    String imageDirectory = await getRoomFolder(
        identityId: identityId, roomId: roomId, type: MessageMediaType.image);

    List<FileSystemEntity> files =
        Directory(imageDirectory).listSync(recursive: true);
    List<File> res = [];
    for (var file in files) {
      if (file is File && isImageFile(file.path)) {
        res.add(file);
      }
    }

    // video
    String videoDirectory = await getRoomFolder(
        identityId: identityId, roomId: roomId, type: MessageMediaType.video);
    List<FileSystemEntity> files2 =
        Directory(videoDirectory).listSync(recursive: true);
    for (var file in files2) {
      if (file is File && isVideoFile(file.path)) {
        res.add(file);
      }
    }
    res.sort((a, b) => b.statSync().changed.compareTo(a.statSync().changed));
    if (res.length > 50) return res.sublist(0, 50);

    return res;
  }

  deleteFilesByTime(String path, DateTime fromAt) {
    Directory directory = Directory(path);
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

  Future<MsgFileInfo?> encryptAndSendFile(
    Room room,
    XFile xfile,
    MessageMediaType type, {
    bool compress = false,
    Function(int count, int total)? onSendProgress,
  }) async {
    String appDocPath = await getRoomFolder(
        identityId: room.identityId, roomId: room.id, type: type);

    String newPath = await getNewFilePath(appDocPath, xfile.path);
    List<int> fileBytes = [];
    if (type == MessageMediaType.image && compress) {
      img.Image? sourceInput = await img.decodeImageFile(xfile.path);
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
            quality: VideoQuality.MediumQuality,
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
    File newFile = File(newPath);
    await newFile.writeAsBytes(fileBytes);
    String selectedMediaServer =
        Get.find<SettingController>().selectedMediaServer.value;
    Uri uri = Uri.parse(selectedMediaServer);
    late FileEncryptInfo fileInfo;
    if (uri.host == 'relay.keychat.io') {
      fileInfo = await AwsS3.instance
          .encryptAndUploadByRelay(newFile, onSendProgress: onSendProgress);
    } else {
      try {
        fileInfo = await uploadToBlossom(
            input: newFile, onSendProgress: onSendProgress);
      } catch (e) {
        Get.dialog(CupertinoAlertDialog(
          title: Text('Upload Failed'),
          content: Column(
            children: [
              Text(
                  'Check your blossom servers, make sure your subscription is valid.'),
              Text('Make sure your server support uploading encrypted files.'),
              Text('Tab:Me -> Chat Settings -> Media Relay'),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: Text('OK'),
              onPressed: () {
                Get.back();
              },
            ),
          ],
        ));
        return null;
      }
    }

    Directory appFolder = await Utils.getAppFolder();
    String relativePath = newFile.path.replaceAll(appFolder.path, '');
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

  Future downloadForMessage(Message message, MsgFileInfo mfi,
      {Function(MsgFileInfo fi)? callback,
      Function(int count, int total)? onReceiveProgress}) async {
    Uri uri = Uri.parse(message.content);
    String outputFilePath = await getOutputFilePath(message, mfi, uri);
    File newFile = File(outputFilePath);
    bool exist = await newFile.exists();
    try {
      // file not exist
      if (exist == false) {
        mfi.status = FileStatus.downloading;
        mfi.updateAt = DateTime.now();
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
            onReceiveProgress: onReceiveProgress);
      } else {
        // file exist, check the hash, then save the file using a new name
        List<int> bytes = await newFile.readAsBytes();
        String existFileHash = await rust_nostr.sha256HashBytes(data: bytes);

        // not the same file, check hash first
        if (existFileHash != mfi.hash) {
          // If the hash doesn't match, rename the file and re-download
          logger.i('File hash mismatch: $existFileHash != ${mfi.hash}');
          String fileName = newFile.path.split('/').last;
          String fileNameWithoutExt = fileName.contains('.')
              ? fileName.substring(0, fileName.lastIndexOf('.'))
              : fileName;
          String extension = fileName.contains('.')
              ? fileName.substring(fileName.lastIndexOf('.'))
              : '';

          // Generate random string for filename
          int randomString = Utils.randomInt(4);
          String newFileName = '${fileNameWithoutExt}_$randomString$extension';

          // Re-download the file
          mfi.status = FileStatus.downloading;
          mfi.updateAt = DateTime.now();
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
              onReceiveProgress: onReceiveProgress);
        }
      }

      Directory appFolder = await Utils.getAppFolder();
      mfi.status = FileStatus.decryptSuccess;
      mfi.updateAt = DateTime.now();
      mfi.localPath = newFile.path.replaceAll(appFolder.path, '');
      message.realMessage = mfi.toString();
      bool isCurrentPage = DBProvider.instance.isCurrentPage(message.roomId);
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
      mfi.status = FileStatus.failed;
      mfi.updateAt = DateTime.now();
      message.realMessage = mfi.toString();
      await updateMessageAndCallback(message, mfi, callback);
    }
  }

  Future<String> getOutputFilePath(
      Message message, MsgFileInfo mfi, Uri uri) async {
    String dir = await getRoomFolder(
        identityId: message.identityId,
        roomId: message.roomId,
        type: message.mediaType);
    late String outputFilePath;
    if (mfi.sourceName != null) {
      outputFilePath = '$dir${mfi.sourceName}';
    } else {
      outputFilePath = '$dir${uri.path.split('/').last}';
      if (mfi.suffix != null) {
        outputFilePath += mfi.suffix!;
      }
    }
    return outputFilePath;
  }

  static Future<void> updateMessageAndCallback(Message message, MsgFileInfo mfi,
      [Function(MsgFileInfo fi)? callback]) async {
    await MessageService.instance.updateMessage(message);
    if (callback != null) {
      callback(mfi);
    } else {
      await MessageService.instance.refreshMessageInPage(message);
    }
  }

  String getFileSizeDisplay(int size) {
    const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB'];
    int digitGroups = 0;
    while (size >= 1024) {
      size ~/= 1024;
      digitGroups++;
    }
    return '$size ${units[digitGroups]}';
  }

  String getDisplayFileName(String filePath, [int maxLength = 10]) {
    String fullName = filePath;
    if (filePath.length < maxLength) return filePath;
    if (filePath.contains('/')) {
      fullName = filePath.split('/').last;
    }
    if (!fullName.contains('.')) return fullName;
    String name = fullName.split('.').first;
    String suffix = fullName.split('.').last;

    if (name.length > 10) {
      name = '${name.substring(0, 5)}...${name.substring(name.length - 5)}';
    }
    return '$name.$suffix';
  }

  Future deleteFolderByRoomId(int identity, int roomId) async {
    String path = await getRoomFolder(identityId: identity, roomId: roomId);
    Directory directory = Directory(path);
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }

  Future<FileEncryptInfo> uploadToBlossom(
      {required File input, void Function(int, int)? onSendProgress}) async {
    FileEncryptInfo fe = await FileService.instance.encryptFile(input);

    fe.size = fe.output.length;
    // Generate a new key pair
    var random = await rust_nostr.generateSecp256K1();
    String eventString = await rust_nostr.signEvent(
        senderKeys: random.prikey,
        content: fe.hash,
        createdAt: BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        kind: 24242,
        tags: [
          ["t", "upload"],
          ["x", fe.hash],
          [
            "expiration",
            (DateTime.now().add(Duration(days: 30)).millisecondsSinceEpoch ~/
                    1000)
                .toString()
          ],
        ]);
    String server = Get.find<SettingController>().selectedMediaServer.value;
    String? errorMessage;
    try {
      Dio dio = Dio();
      Response response = await dio.put(
        '$server/upload',
        data: Stream.fromIterable(fe.output.map((e) => [e])),
        onSendProgress: onSendProgress,
        options: Options(
          sendTimeout: Duration(seconds: 120),
          headers: {
            'Content-Type': 'application/octet-stream',
            'Authorization': 'Nostr ${base64Encode(utf8.encode(eventString))}',
          },
        ),
      );

      if (response.statusCode == 200) {
        logger.i('Success ${random.pubkey}: ${response.data}');
        fe.url = response.data['url'] ?? '';
        fe.size = response.data['size'] ?? fe.size;
        return fe;
      }
    } on DioException catch (e, s) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      if (e.response != null) {
        logger.e('Server $server failed: ${e.response?.data}', stackTrace: s);
        errorMessage = e.response?.data;
      } else {
        errorMessage = e.message;
        logger.e('Server $server failed: ${e.message}', stackTrace: s);
      }
    } catch (e, s) {
      logger.e('Server $server failed: ${e.toString()}', stackTrace: s);
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

  Future<String> getNewFilePath(
      String appDocPath, String sourceFilePath) async {
    String fileName = sourceFilePath.split('/').last;
    String newFilePath = appDocPath + fileName;
    File newFile = File(newFilePath);
    bool exist = await newFile.exists();
    if (!exist) {
      return newFilePath;
    }

    // Split the filename and extension
    String fileNameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    String extension = fileName.contains('.')
        ? fileName.substring(fileName.lastIndexOf('.'))
        : '';

    int counter = 1;
    while (await newFile.exists()) {
      // Create a new filename with counter
      String newFileName = '${fileNameWithoutExt}_$counter$extension';
      newFilePath = appDocPath + newFileName;
      newFile = File(newFilePath);
      counter++;
    }

    return newFilePath;
  }

// pick image only
  Future<XFile?> pickImage(ImageSource imageSource) async {
    final ImagePicker picker = ImagePicker();
    return await picker.pickImage(source: imageSource, imageQuality: 75);
  }

// Pick singe image or video.
  Future<XFile?> pickMedia() async {
    final ImagePicker picker = ImagePicker();
    return await picker.pickMedia(imageQuality: 50);
  }

// Pick a video only
  Future<XFile?> pickVideo(ImageSource imageSource) async {
    final ImagePicker picker = ImagePicker();
    return await picker.pickVideo(
        source: imageSource, maxDuration: const Duration(minutes: 1));
  }

  Future<File?> downloadFile(String url,
      [Function(int count, int total)? onReceiveProgress]) async {
    Dio dio = Dio();
    Directory outputDir = await getTemporaryDirectory();
    String fileName = url.split('/').last;
    String output = outputDir.path + fileName;
    try {
      await dio.download(url, output, onReceiveProgress: onReceiveProgress);
      return File(output);
    } on DioException catch (e) {
      if (e.response != null) {
        logger.e('repsponse: ${e.response?.toString()}', error: e);
      } else {
        logger.e('error no repsponse', error: e);
      }
    }
    return null;
  }

  Future<File> downloadAndDecrypt(
      {required String url,
      required String suffix,
      required int identityId,
      required int roomId,
      required String key,
      required String iv,
      required MessageMediaType type,
      String? fileName,
      Function(int count, int total)? onReceiveProgress}) async {
    File? input = await downloadFile(url, onReceiveProgress);
    if (input == null) throw Exception('File_download_faild');
    String dir =
        await getRoomFolder(identityId: identityId, roomId: roomId, type: type);
    late String outputFile;
    if (fileName != null) {
      outputFile = '$dir$fileName';
    } else {
      outputFile = '$dir${input.path.split('/').last}';
      if (suffix.isNotEmpty) {
        outputFile += '.$suffix';
      }
    }

    final output = File(outputFile);
    return await FileService.instance.decryptFile(
      input: input,
      output: output,
      key: key,
      iv: iv,
    );
  }

  Future deleteAllByIdentity(int identity) async {
    Directory appFolder = await Utils.getAppFolder();
    Directory dir =
        Directory('${appFolder.path}/${KeychatGlobal.baseFilePath}/$identity');
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  Future deleteAllFolder() async {
    Directory appFolder = await Utils.getAppFolder();
    Directory dir = Directory('${appFolder.path}/${Config.env}/');
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
      logger.i("delete other file");
    }
  }

  bool isImageFile(String path) {
    if (path.isEmpty) return false;
    final regex = RegExp(
        r'\.(jpg|jpeg|png|gif|svg|bmp|webp|tiff|tif|ico|heic|heif|raw|cr2|nef|arw|dng)$',
        caseSensitive: false);
    return regex.hasMatch(path);
  }

  bool isVideoFile(String path) {
    if (path.isEmpty) return false;
    final regex = RegExp(
        r'\.(mp4|mov|avi|mkv|webm|m4v|flv|wmv|3gp|ts|mts|m2ts|vob|ogv|rm|rmvb|asf|f4v)$',
        caseSensitive: false);
    return regex.hasMatch(path);
  }
}
