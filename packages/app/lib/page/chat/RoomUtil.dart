import 'dart:convert' show jsonDecode;
import 'package:any_link_preview/any_link_preview.dart';
import 'package:app/constants.dart';
import 'package:app/global.dart';
import 'package:app/models/contact.dart';
import 'package:app/models/embedded/msg_reply.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/keychat/group_message.dart';
import 'package:app/models/keychat/prekey_message_model.dart';
import 'package:app/models/keychat/qrcode_user_model.dart';
import 'package:app/models/nostr_event_status.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/browser/Browser_controller.dart';
import 'package:app/page/chat/ChatMediaFilesPage.dart';
import 'package:app/page/chat/contact_page.dart';
import 'package:app/page/chat/message_actions/BotOneTimePaymentRequestWidget.dart';
import 'package:app/page/chat/message_actions/BotPricePerMessageRequestWidget.dart';
import 'package:app/page/chat/message_actions/FileMessageWidget.dart';
import 'package:app/page/chat/message_actions/GroupInvitationInfoWidget.dart';
import 'package:app/page/chat/message_actions/GroupInvitationRequestingWidget.dart';
import 'package:app/page/chat/message_actions/GroupInviteAction.dart';
import 'package:app/page/chat/message_actions/GroupInviteConfirmAction.dart';
import 'package:app/page/chat/message_actions/SetRoomRelayAction.dart';
import 'package:app/page/chat/message_actions/VideoMessageWidget.dart';
import 'package:app/page/widgets/image_preview_widget.dart';
import 'package:app/service/signal_chat_util.dart';
import 'package:app/service/websocket.service.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:keychat_ecash/red_pocket.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:app/service/contact.service.dart';
import 'package:app/service/storage.dart';

import 'package:app/controller/chat.controller.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/embedded/msg_file_info.dart';

import 'package:app/models/message.dart';
import 'package:app/models/room.dart';
import 'package:app/page/components.dart';
import 'package:app/page/widgets/image_min_preview_widget.dart';
import 'package:app/service/file_util.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart' hide Contact;
import 'package:settings_ui/settings_ui.dart';

class RoomUtil {
  static Future<bool> messageReceiveCheck(
      Room room, NostrEventModel event, Duration delay, int maxRetry) async {
    if (maxRetry == 0) return false;
    maxRetry--;
    await Future.delayed(delay);
    String id = event.id;
    NostrEventStatus? nes = await DBProvider.database.nostrEventStatus
        .filter()
        .eventIdEqualTo(id)
        .sendStatusEqualTo(EventSendEnum.success)
        .findFirst();
    if (nes != null) {
      return true;
    }
    Get.find<WebsocketService>().writeNostrEvent(
        event: event,
        eventString: event.toJsonString(),
        roomId: room.id,
        toRelays: room.sendingRelays);
    logger.i('_messageReceiveCheck: ${event.id}, maxRetry: $maxRetry');
    return await messageReceiveCheck(room, event, delay, maxRetry);
  }

  static GroupMessage getGroupMessage(Room room, String message,
      {int? subtype,
      required String pubkey,
      String? ext,
      String? sig,
      MsgReply? reply}) {
    GroupMessage gm = GroupMessage(message: message, pubkey: pubkey, sig: sig)
      ..subtype = subtype
      ..ext = ext;

    if (reply != null) {
      gm.subtype = KeyChatEventKinds.dm;
      gm.ext = reply.toString(); // EventId
    }
    return gm;
  }

  static String getHelloMessage(String name) {
    return '''
😄 Hi, I'm $name.
Let's start an encrypted chat.''';
  }

  // auto to delete messages and event logs
  static Future executeAutoDelete() async {
    // delete nostr event log
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.nostrEventStatus
          .filter()
          .createdAtLessThan(DateTime.now().subtract(const Duration(days: 30)))
          .deleteAll();
    });
    // excute auto delete message by user setting
    int timestamp =
        await Storage.getIntOrZero(StorageKeyString.autoDeleteMessageDays);
    if (timestamp > 0 &&
        DateTime.now()
                .difference(DateTime.fromMillisecondsSinceEpoch(timestamp))
                .inDays <
            1) {
      logger.i('auto_delete_message been executed today. Skip');
      return;
    }
    await Storage.setInt(StorageKeyString.autoDeleteMessageDays,
        DateTime.now().millisecondsSinceEpoch);
    logger.i('The auto tasks been executed');
    List<Room> list = await DBProvider.database.rooms
        .filter()
        .autoDeleteDaysGreaterThan(0)
        .findAll();
    for (Room room in list) {
      await RoomUtil.excuteAutoDeleteRoomMessages(
          room.identityId, room.id, room.autoDeleteDays);
    }

    // room setting > global setting
    DateTime fromAt = DateTime.now().subtract(const Duration(days: 180));
    var start = BigInt.from(fromAt.millisecondsSinceEpoch);
    rust_cashu.removeTransactions(
        unixTimestampMsLe: start, kind: TransactionStatus.success);
    rust_cashu.removeTransactions(
        unixTimestampMsLe: start, kind: TransactionStatus.expired);
    rust_cashu.removeTransactions(
        unixTimestampMsLe: start, kind: TransactionStatus.failed);
  }

  static Future excuteAutoDeleteRoomMessages(
      int identityId, int roomId, int days) async {
    if (days <= 0) return;
    DateTime fromAt = DateTime.now().subtract(Duration(days: days));

    Isar database = DBProvider.database;
    await database.writeTxn(() async {
      await database.messages
          .filter()
          .roomIdEqualTo(roomId)
          .createdAtLessThan(fromAt)
          .deleteAll();
    });

    String dir =
        await FileUtils.getRoomFolder(identityId: identityId, roomId: roomId);
    FileUtils.deleteFilesByTime(dir, fromAt);
  }

  static SettingsTile autoCleanMessage(ChatController cc) {
    autoDeleteHandle(int day) {
      cc.roomObs.value.autoDeleteDays = day;
      RoomService.instance.updateRoom(cc.roomObs.value);
      cc.roomObs.refresh();
      EasyLoading.showSuccess('Saved');
      if (day > 0) {
        excuteAutoDeleteRoomMessages(
                cc.roomObs.value.identityId, cc.roomObs.value.id, day)
            .then((value) => cc.loadAllChat());
      }
    }

    return SettingsTile.navigation(
        leading: const Icon(
          CupertinoIcons.calendar,
        ),
        title: const Text("Auto Delete Messages"),
        value: Text(Utils.getDaysText(cc.roomObs.value.autoDeleteDays)),
        onPressed: (context) {
          showModalBottomSheetWidget(
              context,
              'Auto Delete Messages',
              Obx(() => SettingsList(platform: DevicePlatform.iOS, sections: [
                    SettingsSection(
                        title: const Text(
                            'Messages will been deleted before days'),
                        tiles: [0, 1, 7, 30, 90]
                            .map(
                              (e) => SettingsTile(
                                onPressed: (context) {
                                  autoDeleteHandle(e);
                                },
                                title: Text(Utils.getDaysText(e)),
                                trailing: cc.roomObs.value.autoDeleteDays == e
                                    ? const Icon(
                                        Icons.done,
                                        color: Colors.green,
                                      )
                                    : null,
                              ),
                            )
                            .toList())
                  ])));
        });
  }

  static SettingsTile pinRoomSection(ChatController chatController) {
    return SettingsTile.switchTile(
      initialValue: chatController.roomObs.value.pin,
      leading: const Icon(
        CupertinoIcons.pin,
      ),
      title: const Text('Sticky on Top'),
      onToggle: (value) async {
        chatController.roomObs.value.pin = value;
        chatController.roomObs.value.pinAt = DateTime.now();
        await RoomService.instance.updateRoom(chatController.roomObs.value);
        chatController.roomObs.refresh();
        EasyLoading.showSuccess('Saved');
        await Get.find<HomeController>()
            .loadIdentityRoomList(chatController.roomObs.value.identityId);
      },
    );
  }

  static SettingsTile muteSection(ChatController chatController) {
    return SettingsTile.switchTile(
      initialValue: chatController.roomObs.value.isMute,
      leading: const Icon(
        Icons.notifications_none,
      ),
      title: const Text('Mute Notifications'),
      description: const Text(
          'If muted, receiving pubkey will not be uploaded to the notification server.'),
      onToggle: (value) async {
        EasyThrottle.throttle('mute_notification', const Duration(seconds: 3),
            () async {
          Room room = chatController.roomObs.value;
          List<String> pubkeys = [];

          if (room.type == RoomType.group) {
            if (room.isMLSGroup && room.onetimekey != null) {
              pubkeys.add(room.onetimekey!);
            } else if (room.mykey.value?.pubkey != null) {
              pubkeys.add(room.mykey.value!.pubkey);
            }
          } else {
            List<String>? data = ContactService.instance.getMyReceiveKeys(room);
            if (data != null) pubkeys.addAll(data);
          }
          bool res = false;
          if (value) {
            res = await NotifyService.removePubkeys(pubkeys);
          } else {
            res = await NotifyService.addPubkeys(pubkeys);
          }
          if (!res) {
            EasyLoading.showError('Failed, Please try again');
            return;
          }
          if (room.type == RoomType.common) {
            await ContactService.instance.updateReceiveKeyIsMute(room, value);
          }
          chatController.roomObs.value.isMute = value;
          await RoomService.instance
              .updateRoomAndRefresh(chatController.roomObs.value);
          EasyLoading.showSuccess('Saved');
          await Get.find<HomeController>()
              .loadIdentityRoomList(room.identityId);
        });
      },
    );
  }

  static Widget getSubtitleDisplay(
      Room room, DateTime messageExpired, Message? lastMessage) {
    if (room.signalDecodeError) {
      return const Text('Decode Error', style: TextStyle(color: Colors.pink));
    }
    if (lastMessage == null) {
      return const Text('');
    }
    late String text;
    if (lastMessage.mediaType == MessageMediaType.text) {
      text = lastMessage.realMessage ?? lastMessage.content;
    } else {
      text = '${[lastMessage.mediaType.name]}';
    }
    if (lastMessage.isMeSend) {
      text = 'You: $text';
    }
    if (room.isMute && room.unReadCount > 1) {
      text = '[${room.unReadCount} messages] $text';
    }
    var style = TextStyle(
        color:
            Theme.of(Get.context!).colorScheme.onSurface.withValues(alpha: 0.6),
        fontSize: 14);
    if (lastMessage.isMeSend && lastMessage.sent == SendStatusType.failed) {
      style = style.copyWith(color: Colors.red);
    }

    return Text(text,
        maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
  }

  static Widget getRelaySubtitle(Message message) {
    if (message.mediaType == MessageMediaType.text) {
      return Text(
        message.realMessage ?? message.content,
        maxLines: 3,
        style: Theme.of(Get.context!).textTheme.bodyMedium,
      );
    }
    if (message.mediaType == MessageMediaType.image) {
      try {
        var mfi = MsgFileInfo.fromJson(jsonDecode(message.realMessage!));
        if (mfi.localPath != null) {
          return ImageMinPreviewWidget(mfi.localPath!);
        }
      } catch (e, s) {
        logger.e(e.toString(), stackTrace: s);
      }
    }

    return Text(
      message.mediaType.name,
      style: Theme.of(Get.context!).textTheme.bodyMedium,
    );
  }

  static Future showRoomActionSheet(BuildContext context, Room room,
      {Function? onDeleteHistory, Function? onDeletRoom}) async {
    if (GetPlatform.isMobile) {
      HapticFeedback.lightImpact();
    }
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
          title: Text(
            room.getRoomName(),
            style: const TextStyle(fontSize: 18),
          ),
          actions: <CupertinoActionSheetAction>[
            CupertinoActionSheetAction(
              onPressed: () async {
                await RoomService.instance
                    .markAllRead(identityId: room.identityId, roomId: room.id);
                Get.back();
              },
              child: const Text('Mark as Read'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                await RoomService.instance.deleteRoomMessage(room);
                Get.find<HomeController>()
                    .loadIdentityRoomList(room.identityId);
                if (onDeleteHistory != null) {
                  onDeleteHistory();
                }
                Get.back();
              },
              child: const Text('Clear History'),
            ),
            if (room.type == RoomType.common)
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () async {
                  try {
                    EasyLoading.show(status: 'Loading...');
                    await RoomService.instance.deleteRoom(room);
                    if (onDeletRoom != null) {
                      onDeletRoom();
                    }
                    EasyLoading.showSuccess('Success');
                    await Get.find<HomeController>()
                        .loadIdentityRoomList(room.identityId);
                  } catch (e, s) {
                    EasyLoading.dismiss();
                    logger.e(e.toString(), error: e, stackTrace: s);
                    EasyLoading.showError(e.toString());
                  }
                  Get.back();
                },
                child: const Text('Delete Room'),
              ),
            CupertinoActionSheetAction(
              onPressed: () {
                Get.back();
              },
              child: const Text('Cancel'),
            )
          ]),
    );
  }

  static SettingsTile mediaSection(ChatController chatController) {
    return SettingsTile.navigation(
      leading: const Icon(
        CupertinoIcons.folder,
      ),
      title: const Text('Photos, Videos & Files'),
      onPressed: (context) async {
        Get.to(() => ChatMediaFilesPage(chatController.roomObs.value));
      },
    );
  }

  static SettingsTile messageLimitSection(ChatController chatController) {
    return SettingsTile.navigation(
      leading: const Icon(
        CupertinoIcons.folder,
      ),
      title: const Text('Message limit'),
      value: Text('${chatController.messageLimit.value}'),
    );
  }

  static SettingsTile clearHistory(ChatController chatController) {
    return SettingsTile(
      leading: const Icon(
        Icons.clear_all,
      ),
      title: const Text(
        'Clear History',
      ),
      onPressed: (context) {
        Get.dialog(CupertinoAlertDialog(
          title: const Text("Clean all messages?"),
          actions: <Widget>[
            CupertinoDialogAction(
              child: const Text(
                'Cancel',
              ),
              onPressed: () {
                Get.back();
              },
            ),
            CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text(
                  'Delete',
                ),
                onPressed: () async {
                  Get.back();
                  try {
                    EasyLoading.show(status: 'Processing');
                    await RoomService.instance
                        .deleteRoomMessage(chatController.roomObs.value);
                    chatController.messages.clear();
                    EasyLoading.showSuccess('Successfully');
                  } catch (e) {
                    EasyLoading.showError(e.toString());
                  }
                }),
          ],
        ));
      },
    );
  }

  static SettingsTile fromContactClick(String pubkey, int identityId,
      [String? greeting]) {
    return SettingsTile(
      title: FutureBuilder(
          future:
              RoomService.instance.getRoomAndContainSession(pubkey, identityId),
          builder: (context, snapshot) {
            Room? room = snapshot.data;
            if (room == null) {
              return FilledButton(
                onPressed: () async {
                  Identity identity =
                      Get.find<HomeController>().identities[identityId]!;
                  await RoomService.instance.createRoomAndsendInvite(pubkey,
                      identity: identity, greeting: greeting);
                },
                child: const Text('Add'),
              );
            }
            return FilledButton(
              onPressed: () async {
                await Get.offAndToNamed('/room/${room.id}', arguments: room);
                Get.find<HomeController>()
                    .loadIdentityRoomList(room.identityId);
              },
              child: const Text('Send Message'),
            );
          }),
    );
  }

  static Future processUserQRCode(QRUserModel model,
      [bool fromAddPage = false]) async {
    if (model.time <
        DateTime.now().millisecondsSinceEpoch -
            1000 * 3600 * KeychatGlobal.oneTimePubkeysLifetime) {
      EasyLoading.showToast('QR Code expired');
      return;
    }
    Identity identity = Get.find<HomeController>().getSelectedIdentity();

    String pubkey = rust_nostr.getHexPubkeyByBech32(bech32: model.pubkey);
    String npub = rust_nostr.getBech32PubkeyByHex(hex: model.pubkey);
    String globalSign = model.globalSign;
    var pmm = PrekeyMessageModel(
        signalId: model.curve25519PkHex,
        nostrId: model.pubkey,
        time: model.time,
        name: model.name,
        sig: globalSign,
        message: '');

    await SignalChatUtil.verifySignedMessage(
        pmm: pmm, signalIdPubkey: model.curve25519PkHex);

    Contact contact =
        Contact(pubkey: pubkey, npubkey: npub, identityId: identity.id)
          ..curve25519PkHex = model.curve25519PkHex
          ..name = model.name;

    var page = ContactPage(
      identityId: identity.id,
      contact: contact,
      title: 'Add Contact',
    )..model = model;
    if (fromAddPage) {
      await Get.off(() => page);
      return;
    }
    await Get.to(() => page);
  }

  static String getGroupModeName(GroupType type) {
    switch (type) {
      case GroupType.mls:
        return 'Large Group';
      case GroupType.kdf:
        return 'Medium Group';
      case GroupType.sendAll:
        return 'Small Group';
      default:
    }
    return 'common';
  }

  static String getGroupModeDescription(GroupType type) {
    switch (type) {
      case GroupType.kdf:
        return '''1. Anti-Forgery ✅
2. End-to-End Encryption ✅
3. Forward Secrecy ✅
4. Backward Secrecy 🟢60% 
5. Metadata Privacy 🟢80%
6. Recommended Group Limit: <60
''';
      case GroupType.mls:
        return '''1. Anti-Forgery ✅
2. End-to-End Encryption ✅
3. Forward Secrecy ✅
4. Backward Secrecy 🟢80%
5. Metadata Privacy 🟢80%
''';
      case GroupType.shareKey:
        return '''1. Members < 30
2. All members hold the same private key''';
      case GroupType.sendAll:
        return '''1. Anti-Forgery ✅ 
2. End-to-End Encryption ✅
3. Forward Secrecy ✅ 
4. Backward Secrecy ✅ 
5. Metadata Privacy ✅
6. Recommended Group Limit: <6
7. Sending a message is essentially sending multiple one-on-one chats. More stamps are required.
''';
    }
  }

  static MessageEncryptType getEncryptMode(NostrEventModel event,
      [NostrEventModel? sourceEvent]) {
    if (sourceEvent == null) return event.encryptType;
    if (event.kind == EventKinds.nip17) return MessageEncryptType.nip17;
    if (event.isNip4) return MessageEncryptType.nip4WrapNip4;
    if (event.isSignal) return MessageEncryptType.nip4WrapSignal;

    return event.encryptType;
  }

  static Widget getStatusCheckIcon(int max, int success) {
    if (max == success && max > 0) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }

    if (success == 0) return const Icon(Icons.error_outline, color: Colors.red);

    return const Icon(Icons.circle, color: Colors.lightGreen);
  }

  static Widget getStatusArrowIcon(int max, int success, bool down) {
    IconData icon = down ? Icons.arrow_downward : Icons.arrow_upward_outlined;
    if (max == success && max > 0) {
      return Icon(icon, color: Colors.green);
    }

    if (success == 0) return Icon(icon, color: Colors.red);

    return Icon(icon, color: Colors.lightGreen);
  }

  static List<Room> sortRoomList(List<Room> rooms) {
    HomeController hc = Get.find<HomeController>();
    rooms.sort((a, b) {
      if (a.pin || b.pin) {
        if (a.pin && b.pin) {
          return b.pinAt!.compareTo(a.pinAt!);
        }
        return a.pin ? -1 : 1;
      }
      if (a.unReadCount > 0 && b.unReadCount == 0) {
        return -1;
      }
      if (a.unReadCount == 0 && b.unReadCount > 0) {
        return 1;
      }

      if (hc.roomLastMessage[a.id] == null) return 1;
      if (hc.roomLastMessage[b.id] == null) return -1;
      return hc.roomLastMessage[b.id]!.createdAt
          .compareTo(hc.roomLastMessage[a.id]!.createdAt);
    });
    return rooms;
  }

  static Widget getMarkdownView(String text, MarkdownStyleSheet styleSheet) {
    return MarkdownBody(
        data: text,
        selectable: false,
        softLineBreak: true,
        onTapLink: (text, href, title) {
          if (href != null) {
            Utils.hideKeyboard(Get.context!);
            Get.find<BrowserController>().lanuchWebview(content: href);
          }
        },
        styleSheetTheme: MarkdownStyleSheetBaseTheme.cupertino,
        styleSheet: styleSheet);
    // return Linkify(
    //   onOpen: (link) {
    //     final Uri uri = Uri.parse(link.url);
    //     Utils.hideKeyboard(Get.context!);
    //     launchUrl(uri);
    //     return;
    //   },
    //   style: Theme.of(Get.context!)
    //       .textTheme
    //       .bodyLarge
    //       ?.copyWith(color: fontColor, fontSize: 16),
    //   text: text,
    //   linkStyle: const TextStyle(decoration: TextDecoration.none, fontSize: 15),
    // );
  }

  static Widget _getLinkPreviewWidget(
      Message message,
      Widget Function({Widget? child, String? text}) errorCallback,
      MarkdownStyleSheet styleSheet) {
    String content = message.content;
    return AnyLinkPreview(
        key: Key(content),
        cache: const Duration(days: 7),
        link: content,
        onTap: () {
          Utils.hideKeyboard(Get.context!);
          Get.find<BrowserController>().lanuchWebview(content: content);
        },
        placeholderWidget:
            errorCallback(child: getMarkdownView(content, styleSheet)),
        showMultimedia: false,
        errorBody: '',
        errorWidget:
            errorCallback(child: getMarkdownView(content, styleSheet)));
  }

  static Widget _getActionWidget(
      Widget child,
      Message message,
      MarkdownStyleSheet styleSheet,
      Widget Function({Widget? child, String? text}) errorCallback) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _getTextItemView(message, styleSheet, errorCallback),
        const SizedBox(height: 10),
        child
      ],
    );
  }

  static _getTextItemView(Message message, MarkdownStyleSheet styleSheet,
      Widget Function({Widget? child, String? text}) errorCallback) {
    if (AnyLinkPreview.isValidLink(message.content) &&
        !isEmail(message.content)) {
      return _getLinkPreviewWidget(message, errorCallback, styleSheet);
    }
    return errorCallback(
        child: getMarkdownView(
            message.realMessage ?? message.content, styleSheet));
  }

  static Widget _imageTextView(Message message, ChatController chatController,
      Widget Function({Widget? child, String? text}) errorCallback) {
    if (message.realMessage != null) {
      try {
        var mfi = MsgFileInfo.fromJson(jsonDecode(message.realMessage!));
        return getImageViewWidget(message, chatController, mfi, errorCallback);
        // ignore: empty_catches
      } catch (e) {}
    }

    return errorCallback(text: '[Image Crashed]');
  }

  static Widget getImageViewWidget(
      Message message,
      ChatController chatController,
      MsgFileInfo fileInfo,
      Widget Function({Widget? child, String? text}) errorCallback) {
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
          errorCallback(text: 'Loading...'),
          const SpinKitFadingCircle(
            color: Color(0xfff0aa35),
            size: 25.0,
          )
        ]);
      case FileStatus.decryptSuccess:
        return fileInfo.localPath == null
            ? errorCallback(text: '[Image Loading]')
            : ImagePreviewWidget(
                localPath: fileInfo.localPath!,
                cc: chatController,
                errorCallback: errorCallback);
      case FileStatus.failed:
        return Row(
          children: [
            errorCallback(text: '[Image Crashed]'),
            SizedBox(
                height: 30,
                child: IconButton(
                    iconSize: 18,
                    onPressed: () {
                      EasyLoading.showToast('Start downloading');
                      message.isRead = true;
                      FileUtils.downloadForMessage(message, fileInfo);
                    },
                    icon: const Icon(
                      Icons.refresh,
                    )))
          ],
        );
      default:
        return errorCallback(text: '[Image Crashed]');
    }
  }

  static Widget getTextViewWidget(
      Message message,
      ChatController chatController,
      MarkdownStyleSheet styleSheet,
      Widget Function({Widget? child, String? text}) errorCallback) {
    try {
      switch (message.mediaType) {
        case MessageMediaType.text:
          return _getTextItemView(message, styleSheet, errorCallback);
        case MessageMediaType.video:
          return VideoMessageWidget(message, errorCallback);
        case MessageMediaType.image:
          return _imageTextView(message, chatController, errorCallback);
        case MessageMediaType.file:
          return FileMessageWidget(message, errorCallback);
        case MessageMediaType.cashuA:
          if (message.cashuInfo != null) {
            return RedPocket(
                key: Key('mredpocket:${message.id}'), message: message);
          }
        case MessageMediaType.setPostOffice:
          return _getActionWidget(SetRoomRelayAction(chatController, message),
              message, styleSheet, errorCallback);
        case MessageMediaType.groupInvite:
          return _getActionWidget(
              GroupInviteAction(message, chatController.room.getIdentity()),
              message,
              styleSheet,
              errorCallback);
        case MessageMediaType.groupInviteConfirm:
          return _getActionWidget(
              GroupInviteConfirmAction(
                  chatController.room.getRoomName(), message),
              message,
              styleSheet,
              errorCallback);
        // bot
        case MessageMediaType.botPricePerMessageRequest:
          return _getActionWidget(
              BotPricePerMessageRequestWidget(chatController, message),
              message,
              styleSheet,
              errorCallback);
        case MessageMediaType.botOneTimePaymentRequest:
          return _getActionWidget(
              BotOneTimePaymentRequestWidget(chatController, message),
              message,
              styleSheet,
              errorCallback);
        case MessageMediaType.groupInvitationInfo:
          return GroupInvitationInfoWidget(
              chatController, message, errorCallback);
        case MessageMediaType.groupInvitationRequesting:
          return GroupInvitationRequestingWidget(
              chatController, message, errorCallback);
        default:
      }
    } catch (e, s) {
      logger.e('sub content: ', error: e, stackTrace: s);
    }

    return _getTextItemView(message, styleSheet, errorCallback);
  }
}
