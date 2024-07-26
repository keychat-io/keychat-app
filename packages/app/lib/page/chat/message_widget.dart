import 'dart:convert' show jsonDecode;
import 'dart:io' show File;
import 'package:any_link_preview/any_link_preview.dart';
import 'package:app/app.dart';
import 'package:app/controller/chat.controller.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/controller/setting.controller.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/chat/ForwardSelectRoom.dart';
import 'package:app/page/chat/LongTextPreviewPage.dart';
import 'package:app/page/chat/message_actions/GroupInviteAction.dart';
import 'package:app/page/chat/message_actions/SetRoomRelayAction.dart';
import 'package:app/page/theme.dart';
import 'package:app/page/widgets/image_preview_widget.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rustCashu;

// import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/db_provider.dart';
import '../../service/file_util.dart';
import '../../service/message.service.dart';
import '../common.dart' show getFormatTimeForMessage;
import '../components.dart';
import 'chat_bubble.dart';
import 'chat_bubble_clipper_4.dart';

import 'message_actions/FileMessageWidget.dart';
import 'message_actions/VideoMessageWidget.dart';

// ignore: must_be_immutable
class MessageWidget extends StatelessWidget {
  late Message message;
  late Widget myAavtar;
  final Color fontColor;
  final Color backgroundColor;
  late int index;
  late ChatController chatController;
  List<String> addTimeList = [];
  RoomMember? roomMember;
  late Contact contact;
  late double screenWidth;
  late bool isGroup;

  MessageWidget(
      {super.key,
      required this.myAavtar,
      required this.index,
      required this.contact,
      required this.isGroup,
      required this.chatController,
      required this.fontColor,
      required this.backgroundColor,
      required this.screenWidth,
      this.roomMember}) {
    message = chatController.messages[index];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Visibility(
          visible: (index == chatController.messages.length - 1) ||
              message.createdAt.minute !=
                  chatController.messages[index + 1].createdAt.minute,
          child: Container(
            margin: const EdgeInsets.only(top: 2),
            child: Text(
              getFormatTimeForMessage(message.createdAt),
              style: TextStyle(
                  color: Get.isDarkMode
                      ? Colors.grey.shade700
                      : Colors.grey.shade400,
                  fontSize: 10),
            ),
          ),
        ),
        getMessageWidget(message),
        // encryptInfo(),
        Obx(() => getFromAndToWidget(context, message))
      ],
    );
  }

  Widget encryptInfo() {
    if (chatController.room.type != RoomType.common) {
      return Container();
    }
    if (contact.isBot) {
      return Container();
    }
    if (chatController.roomContact.value.name == 'Note to Self') {
      return Container();
    }
    return _getEncryptMode(message);
  }

  Widget _getEncryptMode(Message message) {
    return !message.isSystem && message.encryptType == MessageEncryptType.nip4
        ? Container(
            padding: message.isMeSend
                ? const EdgeInsets.only(right: 50)
                : const EdgeInsets.only(left: 50),
            child: Row(
              mainAxisAlignment: message.isMeSend
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                Text('Weak Encrypt Mode',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(Get.context!)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6))),
              ],
            ))
        : const SizedBox();
  }

  Widget getFileTable(BuildContext buildContext, Message message) {
    late MsgFileInfo mfi;
    try {
      mfi = MsgFileInfo.fromJson(jsonDecode(message.realMessage!));
    } catch (e) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              'File Info',
              style: Theme.of(buildContext).textTheme.bodyLarge,
            )),
        Card(
          child: Column(children: [
            Table(
                // defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                // mainAxisAlignment: MainAxisAlignment.,
                columnWidths: const {
                  0: FixedColumnWidth(100.0),
                },
                children: [
                  tableRow("Path", mfi.localPath ?? ''),
                  // tableRow("Status", mfi.status.name),
                  tableRow("Time", mfi.updateAt?.toIso8601String() ?? ''),
                  // tableRow(
                  //   "Type",
                  //   mfi.suffix ?? '',
                  // ),
                  tableRow("Size", FileUtils.getFileSizeDisplay(mfi.size)),
                  tableRow("IV", mfi.iv ?? ''),
                  tableRow("Key", mfi.key ?? ''),
                ]),
            if (mfi.ecashToken != null)
              FutureBuilder(
                  future: rustCashu.decodeToken(encodedToken: mfi.ecashToken!),
                  builder: (context, snapshot) =>
                      snapshot.connectionState == ConnectionState.done
                          ? ListTile(
                              title: const Text('Fee (Pay to FileServer)'),
                              // subtitle: Text(snapshot.data?.mint ?? ''),
                              trailing: Text(
                                  ('${snapshot.data?.amount ?? 0} ${snapshot.data?.unit ?? 'sat'}')
                                      .toString(),
                                  style: Theme.of(context).textTheme.bodyLarge),
                            )
                          : Container()),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: TextButton(
                  onPressed: () {
                    String str = '''
{"url": "${mfi.url}",
"IV": "${mfi.iv}",
"Key": "${mfi.key}"}
''';
                    Clipboard.setData(ClipboardData(text: str));
                    EasyLoading.showToast('Copied');
                  },
                  child: const Text('Copy'),
                ))
          ]),
        ),
        const SizedBox(
          height: 20,
        ),
        Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              'Raw Message',
              style: Theme.of(buildContext).textTheme.bodyLarge,
            )),
      ],
    );
  }

  getFromAndToWidget(BuildContext context, Message message) {
    var style = TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6));
    return chatController.showFromAndTo.value
        ? Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('From: ${message.from}',
                        overflow: TextOverflow.ellipsis, style: style),
                    Text('To: ${message.to}',
                        overflow: TextOverflow.ellipsis, style: style),
                    Text('EncryptionKeyHash: ${message.msgKeyHash ?? ''}',
                        overflow: TextOverflow.ellipsis, style: style),
                  ]),
            ))
        : const SizedBox();
  }

  // Widget getGifphyWidget(Message message) {
  //   return CachedNetworkImage(
  //       imageUrl: message.content,
  //       httpHeaders: const {'accept': 'image/*'},
  //       progressIndicatorBuilder: (context, url, downloadProgress) => const Row(
  //             mainAxisAlignment: MainAxisAlignment.end,
  //             children: [
  //               Text('🤖Loading image'),
  //               SpinKitFadingCircle(
  //                 color: Color(0xfff0aa35),
  //                 size: 25.0,
  //               )
  //             ],
  //           ),
  //       errorWidget: (context, url, error) => _getTextContainer(
  //           getLinkify(message.content, fontColor),
  //           isMeSend: message.isMeSend));
  // }

  Widget _getImageViewWidget(String content, MsgFileInfo fileInfo,
      Function(String text) textCallback) {
    if (fileInfo.updateAt != null &&
        fileInfo.status == FileStatus.downloading) {
      bool isTimeout = DateTime.now()
          .subtract(const Duration(seconds: 60))
          .isAfter(fileInfo.updateAt!);
      if (isTimeout) {
        fileInfo.status = FileStatus.failed;
      }
    }
    switch (fileInfo.status) {
      case FileStatus.downloading:
        return Row(children: [
          textCallback('🤖 Loading...'),
          const SpinKitFadingCircle(
            color: Color(0xfff0aa35),
            size: 25.0,
          )
        ]);
      case FileStatus.decryptSuccess:
        return fileInfo.localPath == null
            ? textCallback('[Image Loading]')
            : ImagePreviewWidget(
                localPath: fileInfo.localPath!,
                cc: chatController,
                textCallback: textCallback);
      case FileStatus.failed:
        return Row(
          children: [
            textCallback('[Image Crashed]'),
            SizedBox(
                height: 30,
                child: IconButton(
                    iconSize: 18,
                    onPressed: () {
                      EasyLoading.showToast('Start downloading');
                      FileUtils.downloadForMessage(message, fileInfo);
                    },
                    icon: const Icon(
                      Icons.refresh,
                    )))
          ],
        );
      default:
        return textCallback('[Image Crashed]');
    }
  }

  Widget getLinkify(String text, Color fontColor) {
    return Linkify(
      onOpen: (link) {
        final Uri uri = Uri.parse(link.url);
        Utils.hideKeyboard(Get.context!);
        launchUrl(uri);
        return;
      },
      text: text,
      style: Theme.of(Get.context!)
          .textTheme
          .bodyLarge
          ?.copyWith(color: fontColor, fontSize: 16),
      linkStyle: const TextStyle(decoration: TextDecoration.none, fontSize: 16),
    );
  }

  Widget? getMessageStatus() {
    if (!message.isMeSend) return null;

    if (message.sent == SendStatusType.success ||
        message.sent == SendStatusType.partialSuccess) return null;
    if (message.sent == SendStatusType.sending &&
        message.createdAt.isAfter(DateTime.now().subtract(const Duration(
            seconds: KeychatGlobal.messageFailedAfterSeconds)))) {
      return null;
    }

    return IconButton(
        splashColor: Colors.transparent,
        onPressed: () {
          if (message.isSystem || message.mediaType != MessageMediaType.text) {
            EasyLoading.showToast('Message sent failed');
            return;
          }
          Get.dialog(
            CupertinoAlertDialog(
              title: const Text(
                'Resend message',
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Get.back();
                  },
                ),
                if (!message.isSystem &&
                    message.mediaType == MessageMediaType.text)
                  CupertinoDialogAction(
                    child: const Text('Resend'),
                    onPressed: () async {
                      Get.back();
                      // 如果resend reply content 是个JSON, 需要解析成reply的结构
                      if (message.reply != null) {
                        Identity identity = Get.find<HomeController>()
                            .identities[chatController.room.identityId]!;
                        message.fromContact = FromContact(
                            identity.secp256k1PKHex, identity.displayName);
                        var decodeContent = jsonDecode(message.content);
                        message.realMessage = message.reply!.content;
                        chatController.inputReplys.value = [message];
                        chatController.hideAdd.value = true;
                        chatController.inputReplys.refresh();
                        chatController.textEditingController.text =
                            decodeContent['msg'];
                      } else {
                        chatController.textEditingController.text =
                            message.content;
                      }
                      chatController.chatContentFocus.requestFocus();
                    },
                  ),
              ],
            ),
          );
        },
        icon: const SizedBox(
          child: Icon(
            Icons.error,
            color: Colors.red,
            size: 28,
          ),
        ));
  }

  Widget getMessageWidget(Message message) {
    return message.isMeSend ? myTextContainer() : toTextContainer();
  }

  Widget getSubContent() {
    try {
      switch (message.mediaType) {
        case MessageMediaType.text:
          return _getTextItemView();
        case MessageMediaType.video:
          return VideoMessageWidget(message, _textCallback);
        case MessageMediaType.image:
          return _imageTextView();
        case MessageMediaType.file:
          return FileMessageWidget(message, _textCallback);
        case MessageMediaType.cashuA:
          if (message.cashuInfo != null) {
            return RedPocket(
                key: Key('mredpocket:${message.id}'), message: message);
          }
        case MessageMediaType.setPostOffice:
          return _getActionWidget(SetRoomRelayAction(chatController, message));
        case MessageMediaType.groupInvite:
          return _getActionWidget(
              GroupInviteAction(message, chatController.room.getIdentity()));
        default:
      }
    } catch (e, s) {
      logger.e('sub content: ', error: e, stackTrace: s);
    }

    return _getTextItemView();
  }

  Widget _getTextView(Message message) {
    return message.reply == null
        ? GestureDetector(
            onLongPress: _handleTextLongPress, child: getSubContent())
        : GestureDetector(
            onLongPress: _handleTextLongPress, child: _getReplyWidget(message));
  }

  Future _handleShowRawdata(BuildContext context) async {
    Get.back(); // 关闭 popup
    if (message.eventIds.isEmpty) {
      EasyLoading.showInfo('Metadata Cleaned');
      return;
    }
    List<NostrEventModel> list = [];
    List<EventLog> eventLogs = [];
    Map<String, List<MessageBill>> messageBills = {};
    for (String id in message.eventIds) {
      EventLog? eventLog = await DBProvider().getEventLogByEventId(id);
      if (eventLog == null) continue;
      try {
        NostrEventModel event =
            NostrEventModel.fromJson(jsonDecode(eventLog.snapshot));
        list.add(event);
        List<MessageBill> bills = await MessageService().getMessageBills(id);
        messageBills[id] = bills;
        eventLogs.add(eventLog);
        // ignore: empty_catches
      } catch (e) {}
    }
    if (list.isEmpty) {
      EasyLoading.showInfo('Not found');
      return;
    }
    if (list.length == 1) {
      _showRawData(message, list[0], eventLogs, messageBills[list[0].id]!);
      return;
    }
    List<RoomMember> members = chatController.members;
    _showRawDatas(message, eventLogs, members, messageBills);
  }

  void messageOnDoubleTap() {
    Get.to(() => LongTextPreviewPage(message.realMessage ?? message.content),
        fullscreenDialog: true, transition: Transition.fadeIn);
  }

  // 消息正文，状态和 icon
  Widget myTextContainer() {
    Widget? messageStatus = getMessageStatus();
    return Container(
      margin: EdgeInsets.only(
          top: 10, bottom: 10, left: messageStatus == null ? 48.0 : 0),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Flex(
                direction: Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (messageStatus != null) messageStatus,
                  Flexible(fit: FlexFit.loose, child: _getTextView(message)),
                ],
              ),
            ),
            const SizedBox(
              width: 4,
            ),
            myAavtar
          ]),
    );
  }

  TableRow tableRow(String title, String text) {
    return TableRow(children: [
      TableCell(
          child: Padding(
              padding:
                  const EdgeInsets.only(left: 10, right: 5, top: 10, bottom: 5),
              child: Text(
                title,
              ))),
      TableCell(
          child: Padding(
              padding:
                  const EdgeInsets.only(left: 5, right: 10, top: 10, bottom: 5),
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: text));
                  EasyLoading.showToast('Copied');
                },
                child: Text(
                  text,
                ),
              )))
    ]);
  }

  Widget toTextContainer() {
    return Container(
      padding: const EdgeInsets.only(top: 10.0, bottom: 10, right: 48.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: EdgeInsets.only(top: isGroup ? 4 : 0, right: 4),
            child: GestureDetector(
              onLongPress: () {
                String userName = isGroup
                    ? (roomMember?.name ?? 'Unknow')
                    : chatController.room.getRoomName();
                chatController.addMetionName(userName);
                chatController.chatContentFocus.unfocus();
                FocusScope.of(Get.context!)
                    .requestFocus(chatController.chatContentFocus);
              },
              onTap: () async {
                if (contact.pubkey.isEmpty) return;
                if (isGroup) {
                  await Get.to(() => ContactPage(
                      identityId: message.identityId,
                      contact: contact,
                      title: 'Group Member',
                      greeting: 'From Group: ${chatController.room.name}'));
                } else {
                  await Get.to(() => ShowContactDetail(
                        contact: contact,
                        room: chatController.room,
                        chatController: chatController,
                      ));
                }
                await chatController.openPageAction();
              },
              child: getRandomAvatar(contact.pubkey, height: 40, width: 40),
            ),
          ),
          Expanded(
              child: Stack(alignment: AlignmentDirectional.topStart, children: [
            isGroup
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                        Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: Text(
                              contact.displayName,
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Get.isDarkMode
                                      ? Colors.white54
                                      : Colors.black54),
                            )),
                        _getTextView(message)
                      ])
                : _getTextView(message)
          ]))
        ],
      ),
    );
  }

  Widget _getLinkPreviewWidget(Message message) {
    String content = message.content;
    return AnyLinkPreview(
        key: Key(content),
        link: content,
        errorTitle: content,
        errorBody: 'Click to open',
        onTap: () {
          Utils.hideKeyboard(Get.context!);
          launchUrl(Uri.parse(content));
        },
        placeholderWidget: _getTextContainer(getLinkify(content, fontColor),
            isMeSend: message.isMeSend),
        displayDirection: UIDirection.uiDirectionVertical,
        backgroundColor: Get.isDarkMode ? Colors.black26 : Colors.grey[300],
        errorImage:
            "https://raw.githubusercontent.com/keychat-io/docs/main/docs/_media/empty2.png",
        errorWidget: _getTextContainer(getLinkify(content, fontColor),
            isMeSend: message.isMeSend));
  }

  Widget _getReplyWidget(Message message) {
    Widget? subTitleChild;
    if (message.reply!.id == null) {
      subTitleChild = Text(message.reply!.content,
          style: Theme.of(Get.context!)
              .textTheme
              .bodyMedium
              ?.copyWith(color: fontColor.withOpacity(0.7), height: 1),
          maxLines: 5);
    } else {
      Message? msg = MessageService().getMessageByMsgIdSync(message.reply!.id!);
      if (msg != null) {
        if (msg.mediaType == MessageMediaType.image) {
          MsgFileInfo mfi = MsgFileInfo.fromJson(jsonDecode(msg.realMessage!));
          subTitleChild = _getImageViewWidget(msg.content, mfi, _textCallback);
        } else {
          String content = msg.mediaType == MessageMediaType.text
              ? (msg.realMessage ?? msg.content)
              : msg.mediaType.name;
          subTitleChild = Text(content,
              style: Theme.of(Get.context!).textTheme.bodyMedium?.copyWith(
                    color: fontColor.withOpacity(0.7),
                    height: 1,
                  ),
              maxLines: 5);
        }
      }
    }

    return _getTextContainer(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (message.isMeSend
                        ? MaterialTheme.lightScheme().surface
                        : Theme.of(Get.context!).colorScheme.surface)
                    .withOpacity(0.5),
                border: const Border(
                  left: BorderSide(
                    color: Colors.blue,
                    width: 2.0,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.reply!.user,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(Get.context!)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.blue, height: 1)),
                  subTitleChild ??
                      Text(message.reply!.content,
                          style: Theme.of(Get.context!)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: fontColor, height: 1))
                ],
              ),
            ),
            getLinkify(message.realMessage ?? message.content, fontColor)
          ],
        ),
        isMeSend: message.isMeSend);
  }

  _getTextContainer(Widget child, {required bool isMeSend}) {
    return GestureDetector(
      onDoubleTap: messageOnDoubleTap,
      child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenWidth,
          ),
          child: ChatBubble(
            clipper: ChatBubbleClipper4(
                type: isMeSend
                    ? BubbleType.sendBubble
                    : BubbleType.receiverBubble),
            alignment: isMeSend ? Alignment.centerRight : Alignment.centerLeft,
            backGroundColor: backgroundColor,
            child: child,
          )),
    );
  }

  _getTextItemView() {
    if (AnyLinkPreview.isValidLink(message.content) &&
        !isEmail(message.content)) {
      return _getLinkPreviewWidget(message);
    }
    return _getTextContainer(
        getLinkify(message.realMessage ?? message.content, fontColor),
        isMeSend: message.isMeSend);
  }

  _textCallback(String text) {
    return _getTextContainer(Text(text, style: TextStyle(color: fontColor)),
        isMeSend: message.isMeSend);
  }

  Widget _imageTextView() {
    if (message.realMessage != null) {
      try {
        var mfi = MsgFileInfo.fromJson(jsonDecode(message.realMessage!));
        return _getImageViewWidget(message.content, mfi, _textCallback);
        // ignore: empty_catches
      } catch (e) {}
    }

    return _textCallback('[Image Crashed]');
  }

  //删除对话框
  Future<void> _showDeleteDialog(Message message) async {
    Get.dialog(CupertinoAlertDialog(
      title: const Text('Delete This Message?'),
      actions: <Widget>[
        CupertinoDialogAction(
          child: const Text('Cancel'),
          onPressed: () {
            Get.back();
          },
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          child: const Text('Delete'),
          onPressed: () async {
            await MessageService().deleteMessageById(message.id);
            chatController.messages.remove(message);
            Get.back();
            try {
              if (message.mediaType == MessageMediaType.file ||
                  message.mediaType == MessageMediaType.image ||
                  message.mediaType == MessageMediaType.video) {
                var mfi =
                    MsgFileInfo.fromJson(jsonDecode(message.realMessage!));
                if (mfi.localPath != null) {
                  String filePath =
                      '${Get.find<SettingController>().appFolder.path}${mfi.localPath}';
                  bool fileExists = File(filePath).existsSync();
                  if (fileExists) {
                    await File(filePath).delete();
                    if (message.mediaType == MessageMediaType.video) {
                      String thumbail = FileUtils.getVideoThumbPath(filePath);
                      bool thumbExists = await File(thumbail).exists();
                      if (thumbExists) {
                        await File(thumbail).delete();
                      }
                    }
                  }
                }
              }
            } catch (e, s) {
              logger.e('delete message file error', error: e, stackTrace: s);
            }
          },
        )
      ],
    ));
  }

  Map encryptText = {
    'signal': 'Signal-Double-Ratchet-Algorithm',
    'nip4': 'NIP4',
    'nip17': 'NIP17',
    'nip4WrapNip4': 'NIP4(NIP4(raw message))',
    'nip4WrapSignal': 'NIP4(Signal-Double-Ratchet-Algorithm(raw message))'
  };
  _showRawData(Message message, NostrEventModel event, List<EventLog> eventLogs,
      [List<MessageBill> bills = const []]) {
    BuildContext buildContext = Get.context!;
    return showModalBottomSheetWidget(
        buildContext,
        'RawData',
        SingleChildScrollView(
            // padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      relayStatusList(buildContext, eventLogs, bills),
                      const SizedBox(
                        height: 20,
                      ),
                      if (message.mediaType == MessageMediaType.file ||
                          message.mediaType == MessageMediaType.image ||
                          message.mediaType == MessageMediaType.video)
                        getFileTable(buildContext, message),
                      NoticeTextWidget.success(
                          'Encrypted by ${encryptText[message.encryptType.name]}'),
                      const SizedBox(
                        height: 5,
                      ),
                      Card(
                          child: Table(
                              // defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              // mainAxisAlignment: MainAxisAlignment.,
                              columnWidths: const {
                            0: FixedColumnWidth(100.0),
                          },
                              // border:
                              //     TableBorder.all(width: 0.5, color: Colors.grey.shade400),
                              children: [
                            tableRow("ID", event.id),
                            tableRow("Source Content", message.content),
                            tableRow("Encrypted Content", event.content),
                            tableRow("From", event.pubkey),
                            tableRow("To", event.tags[0][1]),
                            tableRow(
                                "Time",
                                timestampToDateTime(event.createdAt)
                                    .toString()),
                            if (message.msgKeyHash != null)
                              tableRow("Encryption Keys Hash",
                                  message.msgKeyHash ?? ''),
                            tableRow("Sig", event.sig),
                          ])),
                    ]))));
  }

  _showRawDatas(
      Message message, List<EventLog> eventLogs, List<RoomMember> members,
      [Map<String, List<MessageBill>> bills = const {}]) {
    Map<String, dynamic> maps = {};
    for (var eventLog in eventLogs) {
      // NostrEvent event = NostrEvent.fromJson(jsonDecode(eventLog.snapshot));
      List<RoomMember>? to = members
          .where((element) => element.idPubkey == eventLog.toIdPubkey)
          .toList();
      if (to.isEmpty) continue;

      var data = {
        'status': eventLog.resCode == 200,
        'eventId': eventLog.eventId,
        'snapshot': eventLog.snapshot,
        'eventLog': eventLog,
        'to': to.first
      };

      maps[to.first.idPubkey] = data;
    }
    BuildContext buildContext = Get.context!;

    return showModalBottomSheetWidget(
        buildContext,
        'RawData',
        SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
            child: Column(
              children: [
                // getFileTable(buildContext, message),
                ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: maps.keys.length,
                    itemBuilder: (context, index) {
                      String idPubkey = maps.keys.toList()[index];
                      RoomMember? rm = maps[idPubkey]['to'];
                      bool status = maps[idPubkey]['status'];
                      String snapshot = maps[idPubkey]['snapshot'];
                      EventLog eventLog = maps[idPubkey]['eventLog'];
                      return ExpansionTile(
                        title: Row(
                          children: <Widget>[
                            status
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.error_outline,
                                    color: Colors.red),
                            const SizedBox(width: 10), //增加空白间距
                            Text('To: ${rm?.name ?? idPubkey}'),
                          ],
                        ),
                        subtitle: Text(idPubkey),
                        children: <Widget>[
                          relayStatusList(context, [eventLog],
                              bills[eventLog.eventId] ?? []),
                          ListTile(title: Text(snapshot)),
                        ],
                      );
                    })
              ],
            )));
  }

  Widget _getActionWidget(Widget statusWidget) {
    return Wrap(
      direction: Axis.vertical,
      spacing: 10,
      children: [_getTextItemView(), statusWidget],
    );
  }

  void _handleForward(BuildContext context) async {
    List<dynamic> list =
        Get.find<HomeController>().tabBodyDatas[message.identityId]?.rooms ??
            [];
    if (list.isEmpty) return;

    List<Room> rooms = [];
    for (var i = 0; i < list.length; i++) {
      if (list[i] is String) continue;
      if (list[i] is List<Room>) {
        rooms.addAll(list[i] as List<Room>);
      }
      if (list[i] is Room) {
        rooms.add(list[i] as Room);
      }
    }

    String content = message.mediaType == MessageMediaType.text
        ? (message.realMessage ?? message.content)
        : '[${message.mediaType.name}]';
    Room? forwardRoom = await Get.to(() => ForwardSelectRoom(rooms, content),
        fullscreenDialog: true, transition: Transition.downToUp);
    Get.back(); // close popup
    if (forwardRoom == null) return;
    EasyLoading.show(status: 'Sending...');
    if (message.mediaType == MessageMediaType.text) {
      await RoomService().sendTextMessage(forwardRoom, content);
      EasyLoading.dismiss();
      EasyLoading.showSuccess('Sent');
      return;
    }
    if (message.mediaType == MessageMediaType.image ||
        message.mediaType == MessageMediaType.video ||
        message.mediaType == MessageMediaType.file) {
      MsgFileInfo mfi = MsgFileInfo.fromJson(jsonDecode(message.realMessage!));
      await RoomService().forwardFileMessage(
        room: forwardRoom,
        content: message.content,
        mfi: mfi,
        mediaType: message.mediaType,
      );
      EasyLoading.showSuccess('Sent');
      return;
    }
  }

  void _handleReply(BuildContext context) {
    Get.back();
    if (message.isMeSend) {
      Identity identity = Get.find<HomeController>()
          .identities[chatController.room.identityId]!;
      message.fromContact =
          FromContact(identity.secp256k1PKHex, identity.displayName);
    } else {
      message.fromContact = FromContact(contact.pubkey, contact.displayName);
    }
    chatController.inputReplys.value = [message];
    chatController.hideAdd.value = true;
    chatController.inputReplys.refresh();
    FocusScope.of(chatController.context ?? context)
        .requestFocus(chatController.chatContentFocus);
  }

  void _handleTextLongPress() async {
    if (GetPlatform.isMobile) {
      await Haptics.vibrate(HapticsType.heavy);
    }
    show300hSheetWidget(
      Get.context!,
      'actions',
      SettingsList(
          platform: DevicePlatform.iOS,
          physics: const NeverScrollableScrollPhysics(),
          sections: [
            SettingsSection(
                title: message.mediaType == MessageMediaType.text
                    ? Text(
                        '「${message.realMessage ?? message.content}」',
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text('「${message.mediaType.name.toUpperCase()}」'),
                tiles: [
                  SettingsTile.navigation(
                      title: const Text('Copy'),
                      leading: const Icon(Icons.copy),
                      onPressed: (context) async {
                        Clipboard.setData(ClipboardData(text: message.content));
                        EasyLoading.showToast('Copied');
                        Get.back();
                      }),
                  SettingsTile.navigation(
                      onPressed: _handleReply,
                      leading: const Icon(CupertinoIcons.reply),
                      title: const Text('Reply')),
                  if (message.isSystem == false &&
                      (message.mediaType == MessageMediaType.text ||
                          message.mediaType == MessageMediaType.image ||
                          message.mediaType == MessageMediaType.video ||
                          message.mediaType == MessageMediaType.file))
                    SettingsTile.navigation(
                        onPressed: _handleForward,
                        leading:
                            const Icon(CupertinoIcons.arrowshape_turn_up_right),
                        title: const Text('Forward')),
                  SettingsTile.navigation(
                      leading: const Icon(Icons.code),
                      onPressed: _handleShowRawdata,
                      title: const Text('Raw Data')),
                  SettingsTile.navigation(
                      leading: const Icon(
                        Icons.delete,
                        color: Colors.red,
                      ),
                      onPressed: (BuildContext context) {
                        Get.back();
                        _showDeleteDialog(message);
                      },
                      title: Text(
                        'Delete',
                        style: Theme.of(Get.context!)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.red),
                      ))
                ]),
          ]),
    );
  }
}
