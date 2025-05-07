import 'dart:convert' show base64Encode, utf8;
import 'dart:io' show Directory, File, FileSystemEntity;
import 'dart:typed_data' show Uint8List;
import 'package:app/global.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/embedded/msg_file_info.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/utils.dart';
import 'package:app/utils/config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:aws/aws.dart';
import 'package:video_compress/video_compress.dart';
import '../models/message.dart';
import '../models/room.dart';

AwsS3 s3 = AwsS3(
    accessKey: dotenv.get('AWS_ACCESSKEY', fallback: ""),
    secretKey: dotenv.get('AWS_SECRETKEY', fallback: ""),
    bucket: dotenv.get('AWS_BUCKET', fallback: ""),
    region: dotenv.get('AWS_REGION', fallback: ""))
  ..host = dotenv.get('AWS_HOST', fallback: "");

class FileUtils {
  static String getAbsolutelyFilePath(String appFolder, String localPath) {
    if (localPath.startsWith('/var/mobile')) {
      String file = localPath.split(KeychatGlobal.baseFilePath).last;
      return '$appFolder/${KeychatGlobal.baseFilePath}$file';
    }
    return appFolder + localPath;
  }

  static String getVideoThumbPath(String videoFilePath) {
    String fullFileName = videoFilePath.split('/').last;
    String fileDir = videoFilePath.replaceAll(fullFileName, '');
    String fileName = fullFileName.split('.').first;
    return '$fileDir${fileName}_thumb.jpg';
  }

  static Future<File> getOrCreateThumbForVideo(String videoFilePath) async {
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
      quality: 50,
    );
    await thumbnailFile.writeAsBytes(await thumbnail.readAsBytes());
    return File(thumbnailFilePath);
  }

  static onSendProgress(String status, int count, int total) {
    if (count == total && total != 0) {
      EasyLoading.showSuccess('Upload success');
      return;
    }
    double progress = count / total;
    if (progress > 0.2) {
      EasyLoading.showProgress(progress, status: status);
    }
  }

  static Widget getImageView(File file,
      [double width = 150, double height = 150]) {
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

  static Future<String> getRoomFolder(
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

  static Future<List<File>> getRoomImageAndVideo(
      int identityId, int roomId) async {
    String imageDirectory = await FileUtils.getRoomFolder(
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
    String videoDirectory = await FileUtils.getRoomFolder(
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

  static deleteFilesByTime(String path, DateTime fromAt) {
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

  static encryptAndSendFile(
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
        MediaInfo? compressedFile = await VideoCompress.compressVideo(
          xfile.path,
          quality: VideoQuality.HighestQuality,
          deleteOrigin: true,
        );

        // compressed video
        if (compressedFile?.path != null) {
          fileBytes = await File(compressedFile!.path!).readAsBytes();
        }
      }
    }
    if (fileBytes.isEmpty) {
      fileBytes = await xfile.readAsBytes();
    }
    File newFile = File(newPath);
    await newFile.writeAsBytes(fileBytes);
    FileEncryptInfo fileInfo = await s3.encryptAndUploadByRelay(newFile,
        onSendProgress: onSendProgress);

    Directory appFolder = await Utils.getAppFolder();
    String relativePath = newFile.path.replaceAll(appFolder.path, '');
    await RoomService.instance.sendFileMessage(
        relativePath: relativePath, fileInfo: fileInfo, room: room, type: type);
  }

  static Future downloadForMessage(Message message, MsgFileInfo mfi,
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
        String existFileHash = FileService.calculateFileHash(bytes);
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
          String randomString = Utils.randomString(4);
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

  static Future<String> getOutputFilePath(
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

  static String getFileSizeDisplay(int size) {
    const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB'];
    int digitGroups = 0;
    while (size >= 1024) {
      size ~/= 1024;
      digitGroups++;
    }
    return '$size ${units[digitGroups]}';
  }

  static String getDisplayFileName(String filePath, [int maxLength = 10]) {
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

  static Future deleteFolderByRoomId(int identity, int roomId) async {
    String path = await getRoomFolder(identityId: identity, roomId: roomId);
    Directory directory = Directory(path);
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }

  static Future<FileEncryptInfo> signEventAndUpload(File input,
      {void Function(int, int)? onSendProgress}) async {
    FileEncryptInfo res = await FileService.encryptFile(input);
    res.size = res.output.length;

    rust_nostr.Secp256k1Account randomId = await rust_nostr.generateSecp256K1();

    String eventString = await rust_nostr.signEvent(
        senderKeys: randomId.prikey,
        content: res.hash,
        createdAt: BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        kind: 24242,
        tags: [
          ["t", "upload"],
          ["x", res.hash]
        ]);
    FormData formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(res.output, filename: res.hash),
    });

    try {
      Dio dio = Dio();
      Response response = await dio.post(
        'https://nostrmedia.com/upload',
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            'Authorization': 'Nostr ${base64Encode(utf8.encode(eventString))}',
          },
        ),
      );

      if (response.statusCode == 200) {
        logger.i('Upload successful ${response.data}');
        return res;
      }
    } on DioException catch (e, s) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      if (e.response != null) {
        logger.e(e.response?.data, stackTrace: s);
      } else {
        // Something happened in setting up or sending the request that triggered an Error
        logger.e(e.message, stackTrace: s);
        throw Exception('File_upload_faild: ${e.message ?? ''}');
      }
    }

    throw Exception('File_upload_faild');
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
}

Future<String> getNewFilePath(String appDocPath, String sourceFilePath) async {
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
  String dir = await FileUtils.getRoomFolder(
      identityId: identityId, roomId: roomId, type: type);
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
  return await FileService.decryptFile(
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
  String extension = path.split('.').last.toLowerCase();
  return {'jpg', 'jpeg', 'png', 'gif', 'svg'}.contains(extension);
}

bool isVideoFile(String path) {
  String extension = path.split('.').last.toLowerCase();
  return {'mp4', 'mov', 'avi', 'mkv'}.contains(extension);
}
