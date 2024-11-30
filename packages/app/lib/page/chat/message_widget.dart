import 'dart:convert' show jsonDecode;
import 'dart:io' show File;
import 'package:app/app.dart';
import 'package:app/bot/bot_client_message_model.dart';
import 'package:app/controller/chat.controller.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/controller/setting.controller.dart';
import 'package:app/models/nostr_event_status.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/chat/ForwardSelectRoom.dart';
import 'package:app/page/chat/LongTextPreviewPage.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/theme.dart';
import 'package:app/page/widgets/notice_text_widget.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:isar/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

// import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart';
import 'package:settings_ui/settings_ui.dart';

import '../../models/db_provider.dart';
import '../../service/file_util.dart';
import '../../service/message.service.dart';
import '../common.dart' show getFormatTimeForMessage;
import '../components.dart';
import 'chat_bubble.dart';
import 'chat_bubble_clipper_4.dart';

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
  late Color toDisplayNameColor;
  late MarkdownStyleSheet markdownStyleSheet;

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
      required this.toDisplayNameColor,
      required this.markdownStyleSheet,
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
        message.isMeSend ? _getMessageContainer() : toTextContainer(),
        // encryptInfo(),
        Obx(() => getFromAndToWidget(context, message))
      ],
    );
  }

  Widget encryptInfo() {
    if (chatController.room.type != RoomType.common) {
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
                  future: rust_cashu.decodeToken(encodedToken: mfi.ecashToken!),
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
                    if (kDebugMode)
                      Text('ID: ${message.msgid}',
                          overflow: TextOverflow.ellipsis, style: style),
                    Text('From: ${message.from}',
                        overflow: TextOverflow.ellipsis, style: style),
                    Text('To: ${message.to}',
                        overflow: TextOverflow.ellipsis, style: style),
                    if (message.msgKeyHash != null)
                      Text('EncryptionKeyHash: ${message.msgKeyHash}',
                          overflow: TextOverflow.ellipsis, style: style),
                    Text(
                        'SendAt: ${formatTime(message.createdAt.millisecondsSinceEpoch)}',
                        overflow: TextOverflow.ellipsis,
                        style: style),
                  ]),
            ))
        : const SizedBox();
  }

  Widget? getMessageStatus() {
    if (!message.isMeSend) return null;

    if (message.sent == SendStatusType.success ||
        message.sent == SendStatusType.partialSuccess) return null;
    if (message.sent == SendStatusType.sending) {
      if (message.createdAt.isAfter(DateTime.now().subtract(const Duration(
          seconds: KeychatGlobal.messageFailedAfterSeconds + 1)))) {
        return null;
      } else {
        NostrEventStatus? exist = DBProvider.database.nostrEventStatus
            .filter()
            .eventIdEqualTo(message.msgid)
            .isReceiveEqualTo(false)
            .sendStatusEqualTo(EventSendEnum.success)
            .findFirstSync();
        if (exist != null) return null;
      }
    }

    // message send failed
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

  Widget _getMessageContainer() {
    var child = GestureDetector(
        onLongPress: _handleTextLongPress,
        child: message.reply == null
            ? RoomUtil.getTextViewWidget(
                message, chatController, markdownStyleSheet, _textCallback)
            : _getReplyWidget());

    if (message.isMeSend) {
      Widget? messageStatus = getMessageStatus();
      return Container(
        margin: EdgeInsets.only(
            top: 10, bottom: 10, left: messageStatus == null ? 40.0 : 0),
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
                    Flexible(fit: FlexFit.loose, child: child),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              myAavtar
            ]),
      );
    }
    if (isGroup) {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Text(contact.displayName,
                    maxLines: 1,
                    style: TextStyle(fontSize: 14, color: toDisplayNameColor))),
            child
          ]);
    }
    return child;
  }

  Future _handleShowRawdata(BuildContext context) async {
    Get.back();
    if (message.eventIds.isEmpty) {
      EasyLoading.showInfo('Metadata Cleaned');
      return;
    }

    if (message.eventIds.length == 1 && message.rawEvents.length == 1) {
      var (ess, event) =
          await _getRawMessageData(message.eventIds[0], message.rawEvents[0]);

      // fix message sent status
      if (message.sent != SendStatusType.success) {
        List success = ess
            .where((element) => element.sendStatus == EventSendEnum.success)
            .toList();
        if (success.isNotEmpty) {
          message.sent = SendStatusType.success;
          await MessageService.instance.updateMessageAndRefresh(message);
        }
      }

      BotClientMessageModel? bcmm;
      TokenInfo? token;
      if (message.isMeSend &&
          chatController.roomObs.value.type == RoomType.bot) {
        try {
          bcmm = BotClientMessageModel.fromJson(jsonDecode(message.content));
          if (bcmm.payToken != null) {
            token = await rust_cashu.decodeToken(encodedToken: bcmm.payToken!);
          }
        } catch (e) {}
      }
      _showRawData(message, ess, event,
          botClientMessageModel: bcmm, payToken: token);
      return;
    }
    List<List<NostrEventStatus>> result1 = [];
    List<NostrEventModel?> result2 = [];
    for (int i = 0; i < message.eventIds.length; i++) {
      String? rawString =
          message.rawEvents.length > i ? message.rawEvents[i] : null;
      var (ess, event) =
          await _getRawMessageData(message.eventIds[i], rawString);
      result1.add(ess);
      result2.add(event);
    }

    List<RoomMember> members = chatController.members;
    _showRawDatas(message, result1, members, result2);
  }

  Future<(List<NostrEventStatus>, NostrEventModel?)> _getRawMessageData(
      String eventId, String? rawEvent) async {
    List<NostrEventStatus> ess = await DBProvider.database.nostrEventStatus
        .filter()
        .eventIdEqualTo(eventId)
        .findAll();
    NostrEventModel? event;
    if (rawEvent == null) return (ess, event);
    try {
      event = NostrEventModel.fromJson(jsonDecode(rawEvent));
    } catch (e) {}
    return (ess, event);
  }

  void messageOnDoubleTap() {
    Get.to(() => LongTextPreviewPage(message.realMessage ?? message.content),
        fullscreenDialog: true, transition: Transition.fadeIn);
  }

  TableRow tableRow(String title, String text) {
    return TableRow(children: [
      TableCell(
          child: Padding(
              padding:
                  const EdgeInsets.only(left: 10, right: 4, top: 8, bottom: 4),
              child: Text(title,
                  style: Theme.of(Get.context!)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: fontColor.withOpacity(0.7))))),
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
                      room: chatController.room,
                      chatController: chatController));
                }
                await chatController.openPageAction();
              },
              child: getRandomAvatar(contact.pubkey, height: 40, width: 40),
            ),
          ),
          Expanded(
              child: Stack(
                  alignment: AlignmentDirectional.topStart,
                  children: [_getMessageContainer()]))
        ],
      ),
    );
  }

  Widget _getReplyWidget() {
    Widget? subTitleChild;
    if (message.reply!.id == null) {
      subTitleChild = GestureDetector(
          onDoubleTap: () {
            Get.to(() => LongTextPreviewPage(message.reply!.content),
                fullscreenDialog: true, transition: Transition.fadeIn);
          },
          child: Text(message.reply!.content,
              style: Theme.of(Get.context!)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: fontColor.withOpacity(0.7), height: 1),
              maxLines: 5));
    } else {
      Message? msg =
          MessageService.instance.getMessageByMsgIdSync(message.reply!.id!);
      if (msg != null) {
        if (msg.mediaType == MessageMediaType.image) {
          MsgFileInfo mfi = MsgFileInfo.fromJson(jsonDecode(msg.realMessage!));
          subTitleChild = RoomUtil.getImageViewWidget(
              msg, chatController, mfi, _textCallback);
        } else {
          String content = msg.mediaType == MessageMediaType.text
              ? (msg.realMessage ?? msg.content)
              : msg.mediaType.name;
          subTitleChild = Text(content,
              style: Theme.of(Get.context!)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: fontColor, height: 1.2),
              maxLines: 5);
        }
      }
    }

    return _textCallback(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (message.isMeSend
                    ? MaterialTheme.lightScheme().surface
                    : Theme.of(Get.context!).colorScheme.surface)
                .withOpacity(0.5),
            border: Border(
                left: BorderSide(color: Colors.purple.shade200, width: 2.0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.reply!.user,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(Get.context!)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.purple, height: 1)),
              subTitleChild ??
                  Text(message.reply!.content,
                      style: Theme.of(Get.context!)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: fontColor, height: 1))
            ],
          ),
        ),
        RoomUtil.getMarkdownView(
            message.realMessage ?? message.content, markdownStyleSheet)
      ],
    ));
  }

  Widget _textCallback({String? text, Widget? child}) {
    child ??= Text(text ?? 'null', style: TextStyle(color: fontColor));
    return GestureDetector(
      onDoubleTap: messageOnDoubleTap,
      child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: screenWidth),
          child: ChatBubble(
              clipper: ChatBubbleClipper4(
                  type: message.isMeSend
                      ? BubbleType.sendBubble
                      : BubbleType.receiverBubble),
              alignment: message.isMeSend
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              backGroundColor: backgroundColor,
              child: child)),
    );
  }

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
            await MessageService.instance.deleteMessageById(message.id);
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
    'mls': 'MLS Protocol',
    'signal': 'Signal Protocol',
    'nip4': 'NIP4',
    'nip17': 'NIP17',
    'nip4WrapNip4': 'NIP4(NIP4(raw message))',
    'nip4WrapSignal': 'NIP4(Signal Protocol(raw message))'
  };
  _showRawData(
      Message message, List<NostrEventStatus> ess, NostrEventModel? event,
      {BotClientMessageModel? botClientMessageModel,
      rust_cashu.TokenInfo? payToken}) {
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
                      relayStatusList(buildContext, ess),
                      const SizedBox(height: 10),
                      if (message.mediaType == MessageMediaType.file ||
                          message.mediaType == MessageMediaType.image ||
                          message.mediaType == MessageMediaType.video)
                        getFileTable(buildContext, message),
                      if (botClientMessageModel != null &&
                          botClientMessageModel.priceModel != null)
                        Container(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Pay To Chat',
                                      style: Theme.of(buildContext)
                                          .textTheme
                                          .titleMedium),
                                  Card(
                                    child: Table(
                                      columnWidths: const {
                                        0: FixedColumnWidth(100.0)
                                      },
                                      children: [
                                        tableRow(
                                            "Model",
                                            botClientMessageModel.priceModel ??
                                                ''),
                                        tableRow("Amount",
                                            '${payToken?.amount.toString() ?? 0} ${payToken?.unit ?? 'sat'}'),
                                        tableRow("Mint", payToken?.mint ?? ''),
                                      ],
                                    ),
                                  )
                                ])),
                      const SizedBox(height: 10),
                      Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: NoticeTextWidget.success(
                              'Encrypted by ${encryptText[message.encryptType.name]}')),
                      if (event != null)
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
                              // tableRow('Encrypt',
                              //     encryptText[message.encryptType.name]),
                              tableRow("ID", event.id),
                              tableRow("From", event.pubkey),
                              tableRow("To", event.tags[0][1]),
                              tableRow(
                                  "Time",
                                  timestampToDateTime(event.createdAt)
                                      .toString()),
                              tableRow("Source Content", message.content),
                              if (message.subEvent != null)
                                tableRow("Sub Event", message.subEvent!),
                              tableRow("Encrypted Content", event.content),
                              if (message.msgKeyHash != null)
                                tableRow("Encryption Keys Hash",
                                    message.msgKeyHash ?? ''),
                              tableRow("Sig", event.sig),
                            ])),
                    ]))));
  }

  // for small group message, send to multi members
  _showRawDatas(Message message, List<List<NostrEventStatus>> ess,
      List<RoomMember> members, List<NostrEventModel?> eventLogs) {
    List result = [];
    for (var i = 0; i < ess.length; i++) {
      // NostrEvent event = NostrEvent.fromJson(jsonDecode(eventLog.snapshot));
      NostrEventModel? eventModel;
      if (eventLogs.length > i) {
        eventModel = eventLogs[i];
      }
      List<NostrEventStatus>? es = ess[i];
      if (eventModel == null) continue;
      RoomMember? to = members
          .where((element) => element.idPubkey == eventModel!.toIdPubkey)
          .firstOrNull;
      if (to == null) continue;

      var data = {
        'ess': es,
        'to': to,
        'eventModel': eventModel,
      };

      result.add(data);
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
                    itemCount: result.length,
                    itemBuilder: (context, index) {
                      Map map = result[index];
                      // String idPubkey = maps.keys.toList()[index];
                      RoomMember? rm = map['to'];
                      List<NostrEventStatus> eventSendStatus = map['ess'] ?? [];
                      NostrEventModel? eventModel = map['eventModel'];
                      List<NostrEventStatus> success = eventSendStatus
                          .where((element) =>
                              element.sendStatus == EventSendEnum.success)
                          .toList();
                      String idPubkey = eventModel?.toIdPubkey ??
                          eventModel?.tags[0][1] ??
                          '';
                      return ExpansionTile(
                        title: Row(
                          children: <Widget>[
                            RoomUtil.getStatusCheckIcon(
                                eventSendStatus.length, success.length),
                            const SizedBox(width: 10),
                            Text('To: ${rm?.name ?? idPubkey}'),
                          ],
                        ),
                        subtitle: Text(idPubkey),
                        children: <Widget>[
                          relayStatusList(context, eventSendStatus),
                          if (eventModel != null)
                            ListTile(title: Text(eventModel.toJsonString())),
                        ],
                      );
                    })
              ],
            )));
  }

  void _handleForward(BuildContext context) async {
    List<Room> rooms =
        Get.find<HomeController>().getRoomsByIdentity(message.identityId);

    String content = message.mediaType == MessageMediaType.text
        ? (message.realMessage ?? message.content)
        : '[${message.mediaType.name}]';
    Room? forwardRoom = await Get.to(
        () => ForwardSelectRoom(rooms, content, 'Select a Chat'),
        fullscreenDialog: true,
        transition: Transition.downToUp);
    Get.back();
    if (forwardRoom == null) return;
    EasyLoading.show(status: 'Sending...');
    if (message.mediaType == MessageMediaType.text) {
      await RoomService.instance.sendTextMessage(forwardRoom, content);
      EasyLoading.dismiss();
      EasyLoading.showSuccess('Sent');
      return;
    }
    if (message.mediaType == MessageMediaType.image ||
        message.mediaType == MessageMediaType.video ||
        message.mediaType == MessageMediaType.file) {
      MsgFileInfo mfi = MsgFileInfo.fromJson(jsonDecode(message.realMessage!));
      await RoomService.instance.forwardFileMessage(
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
                        String conent = message.content;
                        if (message.realMessage != null &&
                            chatController.roomObs.value.type == RoomType.bot) {
                          conent = message.realMessage!;
                        }
                        Clipboard.setData(ClipboardData(text: conent));
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
