import 'dart:io' show Directory, File, FileSystemEntity;
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

import 'package:aws/aws.dart';
import 'package:video_compress/video_compress.dart';
import '../models/message.dart';
import '../models/room.dart';

AwsS3 s3 = AwsS3(
    accessKey: dotenv.get('AWS_ACCESSKEY'),
    secretKey: dotenv.get('AWS_SECRETKEY'),
    bucket: dotenv.get('AWS_BUCKET'),
    region: dotenv.get('AWS_REGION'))
  ..host = dotenv.get('AWS_HOST');

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
    // logger.d('progress: $progress, count: $count ,total: $total');
    EasyLoading.showProgress(progress, status: status);
  }

  static Widget getImageView(File file,
      [double width = 150, double height = 150]) {
    bool isSVG = file.path.endsWith('.svg');

    return isSVG
        ? SvgPicture.file(
            file,
            width: width,
            height: height,
            fit: BoxFit.fitWidth,
          )
        : Image.file(
            file,
            width: width,
            fit: BoxFit.fitWidth,
          );
  }

  static Future<String> getRoomFolder(
      {required int identityId,
      required int roomId,
      MessageMediaType? type}) async {
    Directory appFolder = await getApplicationDocumentsDirectory();
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
    if (type == MessageMediaType.image) {
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
          quality: VideoQuality.MediumQuality,
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
    await File(newPath).writeAsBytes(fileBytes);
    File localFile = File(newPath);
    FileEncryptInfo fileInfo = await s3.encryptAndUploadByRelay(localFile,
        onSendProgress: onSendProgress);

    Directory appFolder = await getApplicationDocumentsDirectory();

    String relativePath = localFile.path.replaceAll(appFolder.path, '');
    await RoomService.instance.sendFileMessage(
        relativePath: relativePath, fileInfo: fileInfo, room: room, type: type);
  }

  static Future downloadForMessage(Message message, MsgFileInfo mfi,
      {Function(MsgFileInfo fi)? callback,
      Function(int count, int total)? onReceiveProgress}) async {
    String dir = await getRoomFolder(
        identityId: message.identityId,
        roomId: message.roomId,
        type: message.mediaType);
    Uri uri = Uri.parse(message.content);
    String outputFilePath = '$dir${uri.path.split('/').last}';

    if (mfi.suffix != null) {
      outputFilePath += mfi.suffix!;
    }

    File newFile = File(outputFilePath);
    bool exist = await newFile.exists();
    try {
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
            onReceiveProgress: onReceiveProgress);
      }

      Directory appFolder = await getApplicationDocumentsDirectory();
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
      return;
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
      mfi.status = FileStatus.failed;
      mfi.updateAt = DateTime.now();
      message.realMessage = mfi.toString();
      await updateMessageAndCallback(message, mfi, callback);
      return;
    }
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
}

Future<String> getNewFilePath(String appDocPath, String sourceFilePath) async {
  String fileName = sourceFilePath.split('/').last;
  String fileSuffix = fileName.split('.').last;
  String newFileName = '${DateTime.now().millisecondsSinceEpoch}.$fileSuffix';
  return appDocPath + newFileName;
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
    Function(int count, int total)? onReceiveProgress}) async {
  File? input = await downloadFile(url, onReceiveProgress);
  if (input == null) throw Exception('File_download_faild');
  String dir = await FileUtils.getRoomFolder(
      identityId: identityId, roomId: roomId, type: type);
  String outputFile = '$dir${input.path.split('/').last}';
  if (suffix.isNotEmpty) {
    outputFile += '.$suffix';
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
  Directory appFolder = await getApplicationDocumentsDirectory();
  Directory dir =
      Directory('${appFolder.path}/${KeychatGlobal.baseFilePath}/$identity');
  if (dir.existsSync()) {
    await dir.delete(recursive: true);
  }
}

Future deleteAllFolder() async {
  Directory appFolder = await getApplicationDocumentsDirectory();
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
