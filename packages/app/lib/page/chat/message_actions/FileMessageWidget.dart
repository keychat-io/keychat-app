import 'dart:convert' show jsonDecode;

import 'package:app/app.dart';
import 'package:app/page/components.dart';
import 'package:app/service/file.service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'FileMessagePreview.dart';

class FileMessageWidget extends StatefulWidget {
  final Message message;
  final Widget Function({Widget? child, String? text}) errorCallback;
  const FileMessageWidget(this.message, this.errorCallback, {super.key});

  @override
  _FileMessageWidgetState createState() => _FileMessageWidgetState();
}

class _FileMessageWidgetState extends State<FileMessageWidget> {
  bool? decodeError;
  MsgFileInfo? msgFileInfo;

  @override
  void initState() {
    super.initState();

    try {
      if (widget.message.realMessage == null) {
        throw Exception('realMessage is null');
      }
      MsgFileInfo mfi =
          MsgFileInfo.fromJson(jsonDecode(widget.message.realMessage!));
      setState(() {
        msgFileInfo = mfi;
      });
    } catch (e) {
      setState(() {
        decodeError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (decodeError == true || msgFileInfo == null) {
      return widget.errorCallback(
          text: '[File Decode Error]: ${widget.message.content}');
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 350),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        title: Text(
          msgFileInfo?.fileName ??
              msgFileInfo?.suffix?.toUpperCase() ??
              '[File]',
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: textSmallGray(
          context,
          'Size: ${FileService.instance.getFileSizeDisplay(msgFileInfo?.size ?? 0)}',
        ),
        trailing: IconButton(
          onPressed: handleOnTap,
          icon: SizedBox(
            width: 36,
            height: 36,
            child: msgFileInfo?.localPath == null
                ? Image.asset('assets/images/file-download.png',
                    fit: BoxFit.contain)
                : Image.asset('assets/images/file.png', fit: BoxFit.contain),
          ),
        ),
        onTap: handleOnTap,
      ),
    );
  }

  void handleOnTap() {
    if (msgFileInfo != null) {
      Get.bottomSheet(FileMessagePreview(widget.message, msgFileInfo!));
    }
  }
}
