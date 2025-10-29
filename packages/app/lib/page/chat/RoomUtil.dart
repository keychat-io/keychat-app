import 'dart:convert' show jsonDecode;

import 'package:app/constants.dart';
import 'package:app/controller/chat.controller.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/chat/ChatMediaFilesPage.dart';
import 'package:app/page/chat/ForwardSelectRoom.dart';
import 'package:app/page/chat/contact_page.dart';
import 'package:app/page/chat/message_actions/ProfileRequestWidget.dart';
import 'package:app/page/components.dart';
import 'package:app/page/widgets/image_min_preview_widget.dart';
import 'package:app/page/widgets/image_preview_widget.dart';
import 'package:app/service/file.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/signal_chat_util.dart';
import 'package:app/service/storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat_ecash/red_pocket_cashu.dart';
import 'package:keychat_ecash/red_pocket_lightning.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:markdown_widget/markdown_widget.dart';
import 'package:settings_ui/settings_ui.dart';

class RoomUtil {
  static Future<void> forwardTextMessage(
    Identity identity,
    String content, {
    bool showContent = true,
  }) async {
    final forwardRooms = await Get.to<List<Room>>(
      () => ForwardSelectRoom(content, identity, showContent: showContent),
      fullscreenDialog: true,
      transition: Transition.downToUp,
    );
    if (forwardRooms == null || forwardRooms.isEmpty) return;

    EasyLoading.show(status: 'Sending...');
    await RoomService.instance.sendMessageToMultiRooms(
      message: content,
      realMessage: content,
      rooms: forwardRooms,
      identity: identity,
      mediaType: MessageMediaType.text,
    );
    EasyLoading.dismiss();
    EasyLoading.showSuccess('Sent');
    return;
  }

  static Future<void> forwardMediaMessage(
    Identity identity, {
    required MessageMediaType mediaType,
    required String content,
    required String realMessage,
  }) async {
    final forwardRooms = await Get.to<List<Room>>(
      () => ForwardSelectRoom(content, identity),
      fullscreenDialog: true,
      transition: Transition.downToUp,
    );
    if (forwardRooms == null || forwardRooms.isEmpty) return;

    EasyLoading.show(status: 'Sending...');

    final mfi = MsgFileInfo.fromJson(jsonDecode(realMessage));
    for (final room in forwardRooms) {
      await RoomService.instance.sendMessage(
        room,
        content,
        realMessage: mfi.toString(),
        mediaType: mediaType,
      );
    }
    EasyLoading.showSuccess('Sent');
    return;
  }

  static Future<void> forwardMediaMessageToRooms(
    List<Room> rooms,
    Message message,
  ) async {
    if (rooms.isEmpty ||
        message.realMessage == null ||
        message.realMessage!.isEmpty) {
      return;
    }
    try {
      EasyLoading.show(status: 'Sending...');
      final mfi = MsgFileInfo.fromJson(jsonDecode(message.realMessage!));
      for (final room in rooms) {
        await RoomService.instance.sendMessage(
          room,
          message.content,
          realMessage: mfi.toString(),
          mediaType: message.mediaType,
        );
      }
      EasyLoading.showSuccess('Sent');
    } catch (e, s) {
      logger.e('forwardMediaMessageToRooms error: $e', stackTrace: s);
      EasyLoading.showError('Failed to forward message');
    }
  }

  static GroupMessage getGroupMessage(
    Room room,
    String message, {
    required String pubkey,
    int? subtype,
    String? ext,
    String? sig,
    MsgReply? reply,
  }) {
    final gm = GroupMessage(message: message, pubkey: pubkey, sig: sig)
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
  static Future<void> executeAutoDelete() async {
    try {
      // delete nostr event log
      await DBProvider.database.writeTxn(() async {
        await DBProvider.database.nostrEventStatus
            .filter()
            .createdAtLessThan(
              DateTime.now().subtract(const Duration(days: 60)),
            )
            .deleteAll();
      });
      // excute auto delete message by user setting
      final timestamp = Storage.getIntOrZero(
        StorageKeyString.autoDeleteMessageDays,
      );
      if (timestamp > 0 &&
          DateTime.now()
                  .difference(DateTime.fromMillisecondsSinceEpoch(timestamp))
                  .inDays <
              1) {
        logger.i('auto_delete_message been executed today. Skip');
        return;
      }
      await Storage.setInt(
        StorageKeyString.autoDeleteMessageDays,
        DateTime.now().millisecondsSinceEpoch,
      );
      logger.i('The auto tasks been executed');
      final list = await DBProvider.database.rooms
          .filter()
          .autoDeleteDaysGreaterThan(0)
          .findAll();
      for (final room in list) {
        await RoomUtil.excuteAutoDeleteRoomMessages(
          room.identityId,
          room.id,
          room.autoDeleteDays,
        );
      }

      // room setting > global setting
      final fromAt = DateTime.now().subtract(const Duration(days: 365));
      final start = BigInt.from(fromAt.second);
      await rust_cashu.removeTransactions(
        unixTimestampLe: start,
        status: TransactionStatus.success,
      );
    } catch (e, s) {
      logger.e('executeAutoDelete:$e', stackTrace: s);
    }
  }

  static Future<void> excuteAutoDeleteRoomMessages(
    int identityId,
    int roomId,
    int days,
  ) async {
    if (days <= 0) return;
    final fromAt = DateTime.now().subtract(Duration(days: days));

    final database = DBProvider.database;
    await database.writeTxn(() async {
      await database.messages
          .filter()
          .roomIdEqualTo(roomId)
          .createdAtLessThan(fromAt)
          .deleteAll();
    });

    final dir = await FileService.instance.getRoomFolder(
      identityId: identityId,
      roomId: roomId,
    );
    FileService.instance.deleteFilesByTime(dir, fromAt);
  }

  static SettingsTile autoCleanMessage(ChatController cc) {
    void autoDeleteHandle(int day) {
      cc.roomObs.value.autoDeleteDays = day;
      RoomService.instance.updateRoom(cc.roomObs.value);
      cc.roomObs.refresh();
      EasyLoading.showSuccess('Saved');
      if (day > 0) {
        excuteAutoDeleteRoomMessages(
          cc.roomObs.value.identityId,
          cc.roomObs.value.id,
          day,
        ).then((value) => cc.loadAllChat());
      }
    }

    return SettingsTile.navigation(
      leading: const Icon(
        CupertinoIcons.calendar,
      ),
      title: const Text('Auto Delete Messages'),
      value: Text(Utils.getDaysText(cc.roomObs.value.autoDeleteDays)),
      onPressed: (context) {
        showModalBottomSheetWidget(
          context,
          'Auto Delete Messages',
          Obx(
            () => SettingsList(
              platform: DevicePlatform.iOS,
              physics: const NeverScrollableScrollPhysics(),
              sections: [
                SettingsSection(
                  title: const Text(
                    'Messages will been deleted before days',
                  ),
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
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static SettingsTile pinRoomSection(ChatController cc) {
    return SettingsTile.switchTile(
      initialValue: cc.roomObs.value.pin,
      leading: const Icon(
        CupertinoIcons.pin,
      ),
      title: const Text('Sticky on Top'),
      onToggle: (value) async {
        cc.roomObs.value.pin = value;
        cc.roomObs.value.pinAt = DateTime.now();
        await RoomService.instance.updateRoom(cc.roomObs.value);
        cc.roomObs.refresh();
        EasyLoading.showSuccess('Saved');
        Get.find<HomeController>().loadIdentityRoomList(
          cc.roomObs.value.identityId,
        );
      },
    );
  }

  static SettingsTile muteSection(ChatController cc) {
    return SettingsTile.switchTile(
      initialValue: cc.roomObs.value.isMute,
      leading: const Icon(
        Icons.notifications_none,
      ),
      title: const Text('Mute Notifications'),
      onToggle: (value) async {
        await RoomService.instance.mute(cc.roomObs.value, value);
      },
    );
  }

  static Widget getSubtitleDisplay(
    BuildContext context,
    Room room,
    DateTime messageExpired,
    Message? lastMessage,
  ) {
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
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      fontSize: 14,
    );
    if (lastMessage.isMeSend && lastMessage.sent == SendStatusType.failed) {
      style = style.copyWith(color: Colors.red);
    }

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
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
        final mfi = MsgFileInfo.fromJson(jsonDecode(message.realMessage!));
        if (mfi.localPath != null) {
          return ImageMinPreviewWidget(mfi.localPath!);
        }
      } catch (e, s) {
        logger.e('img decoded error:$e', stackTrace: s);
      }
    }

    return Text(
      message.mediaType.name,
      style: Theme.of(Get.context!).textTheme.bodyMedium,
    );
  }

  static Future<void> showRoomActionSheet(
    BuildContext context,
    Room room, {
    Function? onDeleteHistory,
    Function? onDeletRoom,
  }) async {
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
              await RoomService.instance.markAllRead(room);
              Get.back<void>();
            },
            child: const Text('Mark as Read'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              await RoomService.instance.deleteRoomMessage(room);
              Get.find<HomeController>().loadIdentityRoomList(room.identityId);
              if (onDeleteHistory != null) {
                onDeleteHistory();
              }
              Get.back<void>();
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
                  Get.find<HomeController>().loadIdentityRoomList(
                    room.identityId,
                  );
                } catch (e, s) {
                  EasyLoading.dismiss();
                  logger.e(e.toString(), error: e, stackTrace: s);
                  EasyLoading.showError(e.toString());
                }
                Get.back<void>();
              },
              child: const Text('Delete Room'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Get.back<void>();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  static SettingsTile mediaSection(ChatController cc) {
    return SettingsTile.navigation(
      leading: const Icon(
        CupertinoIcons.folder,
      ),
      title: const Text('Photos, Videos & Files'),
      onPressed: (context) async {
        Get.to(() => ChatMediaFilesPage(cc.roomObs.value));
      },
    );
  }

  static SettingsTile messageLimitSection(ChatController cc) {
    return SettingsTile.navigation(
      leading: const Icon(
        CupertinoIcons.folder,
      ),
      title: const Text('Message limit'),
      value: Text('${cc.messageLimit.value}'),
    );
  }

  static SettingsTile clearHistory(ChatController cc) {
    return SettingsTile(
      leading: const Icon(
        Icons.clear_all,
      ),
      title: const Text(
        'Clear History',
      ),
      onPressed: (context) {
        Get.dialog(
          CupertinoAlertDialog(
            title: const Text('Clean all messages?'),
            actions: <Widget>[
              CupertinoDialogAction(
                child: const Text(
                  'Cancel',
                ),
                onPressed: () {
                  Get.back<void>();
                },
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text(
                  'Delete',
                ),
                onPressed: () async {
                  Get.back<void>();
                  try {
                    EasyLoading.show(status: 'Processing');
                    await RoomService.instance.deleteRoomMessage(
                      cc.roomObs.value,
                    );
                    cc.messages.clear();
                    EasyLoading.showSuccess('Successfully');
                  } catch (e) {
                    EasyLoading.showError(e.toString());
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static SettingsTile fromContactClick(
    String pubkey,
    int identityId, {
    String? greeting,
    Contact? contact,
  }) {
    return SettingsTile(
      title: FutureBuilder(
        future: RoomService.instance.getRoomAndContainSession(
          pubkey,
          identityId,
        ),
        builder: (context, snapshot) {
          final room = snapshot.data;
          if (room == null) {
            return FilledButton(
              onPressed: () async {
                final identity =
                    Get.find<HomeController>().allIdentities[identityId]!;
                await RoomService.instance.createRoomAndsendInvite(
                  pubkey,
                  identity: identity,
                  greeting: greeting,
                );
              },
              child: const Text('Start a Private Chat'),
            );
          }
          return FilledButton(
            onPressed: () async {
              if (contact != null) room.contact = contact;
              await Utils.offAndToNamedRoom(room);
              Get.find<HomeController>().loadIdentityRoomList(room.identityId);
            },
            child: const Text('Send Message'),
          );
        },
      ),
    );
  }

  static Future<void> processUserQRCode(
    QRUserModel model, [
    bool fromAddPage = false,
    Identity? identity,
  ]) async {
    if (model.time <
        DateTime.now().millisecondsSinceEpoch -
            1000 * 3600 * KeychatGlobal.oneTimePubkeysLifetime) {
      EasyLoading.showToast('QR Code expired');
      return;
    }
    identity ??= Get.find<HomeController>().getSelectedIdentity();

    final pubkey = rust_nostr.getHexPubkeyByBech32(bech32: model.pubkey);
    final npub = rust_nostr.getBech32PubkeyByHex(hex: model.pubkey);
    final globalSign = model.globalSign;
    final pmm = PrekeyMessageModel(
      signalId: model.curve25519PkHex,
      nostrId: model.pubkey,
      time: model.time,
      name: model.name,
      sig: globalSign,
      avatar: model.avatar,
      lightning: model.lightning,
      message: '',
    );

    await SignalChatUtil.verifySignedMessage(
      pmm: pmm,
      signalIdPubkey: model.curve25519PkHex,
    );

    final contact = Contact(pubkey: pubkey, identityId: identity.id)
      ..npubkey = npub
      ..curve25519PkHex = model.curve25519PkHex
      ..name = model.name
      ..avatarRemoteUrl = model.avatar
      ..lightning = model.lightning;

    final page = ContactPage(
      identityId: identity.id,
      contact: contact,
      title: 'Add Contact',
    )..model = model;
    if (fromAddPage) {
      await Get.off<void>(() => page);
      return;
    }
    await Get.to<void>(() => page);
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
        return '''
1. Anti-Forgery ✅
2. End-to-End Encryption ✅
3. Forward Secrecy ✅
4. Backward Secrecy 🟢60% 
5. Metadata Privacy 🟢80%
6. Recommended Group Limit: <60
''';
      case GroupType.mls:
        return '''
1. Anti-Forgery ✅
2. End-to-End Encryption ✅
3. Forward Secrecy ✅
4. Backward Secrecy 🟢80%
5. Metadata Privacy 🟢80%
''';
      case GroupType.shareKey:
        return '''
1. Members < 30
2. All members hold the same private key''';
      case GroupType.sendAll:
        return '''
1. Anti-Forgery ✅ 
2. End-to-End Encryption ✅
3. Forward Secrecy ✅ 
4. Backward Secrecy ✅ 
5. Metadata Privacy ✅
6. Recommended Group Limit: <6
7. Sending a message is essentially sending multiple one-on-one chats. More stamps are required.
''';
    }
  }

  static MessageEncryptType getEncryptMode(
    NostrEventModel event, [
    NostrEventModel? sourceEvent,
  ]) {
    if (sourceEvent == null) return event.encryptType;
    if (event.kind == EventKinds.nip17 ||
        sourceEvent.kind == EventKinds.nip17) {
      return MessageEncryptType.nip17;
    }
    if (event.isNip4) return MessageEncryptType.nip4WrapNip4;
    if (event.isSignal) return MessageEncryptType.nip4WrapSignal;

    return event.encryptType;
  }

  static Widget getStatusCheckIcon(int max, int success) {
    if (max == success && max > 0) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }

    if (success == 0) return const Icon(Icons.error_outline, color: Colors.red);

    return const Icon(Icons.check_circle, color: Colors.lightGreen);
  }

  static List<Room> sortRoomList(List<Room> rooms) {
    final hc = Get.find<HomeController>();
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
      return hc.roomLastMessage[b.id]!.createdAt.compareTo(
        hc.roomLastMessage[a.id]!.createdAt,
      );
    });
    return rooms;
  }

  static Widget getMarkdownView(String data, MarkdownConfig config, [int? id]) {
    return MarkdownBlock(
      key: id != null ? ObjectKey('mk:$id') : null,
      data: data,
      selectable: false,
      config: config,
      generator: MarkdownGenerator(
        linesMargin: const EdgeInsets.symmetric(vertical: 4),
      ),
    );
  }

  static Widget _getActionWidget(
    Widget child,
    Message message,
    MarkdownConfig markdownConfig,
    Widget Function({Widget? child, String? text}) errorCallback,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        errorCallback(
          child: getMarkdownView(
            message.realMessage ?? message.content,
            markdownConfig,
            message.id,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  static Widget _imageTextView(
    Message message,
    ChatController cc,
    Widget Function({Widget? child, String? text}) errorCallback,
  ) {
    if (message.realMessage != null) {
      try {
        final mfi = MsgFileInfo.fromJson(jsonDecode(message.realMessage!));
        return getImageViewWidget(message, cc, mfi, errorCallback);
        // ignore: empty_catches
      } catch (e) {}
    }

    return errorCallback(text: '[Image Crashed]');
  }

  static Widget getImageViewWidget(
    Message message,
    ChatController cc,
    MsgFileInfo fileInfo,
    Widget Function({Widget? child, String? text}) errorCallback,
  ) {
    if (fileInfo.updateAt != null &&
        fileInfo.status == FileStatus.downloading) {
      final isTimeout = DateTime.now()
          .subtract(const Duration(seconds: 60))
          .isAfter(fileInfo.updateAt!);
      if (isTimeout) {
        fileInfo.status = FileStatus.failed;
      }
    }
    switch (fileInfo.status) {
      case FileStatus.downloading:
        return Row(
          children: [
            errorCallback(text: 'Downloading...'),
            const SpinKitFadingCircle(
              color: Color(0xfff0aa35),
              size: 25,
            ),
          ],
        );
      case FileStatus.decryptSuccess:
        return fileInfo.localPath == null
            ? errorCallback(text: '[Image Loading]')
            : ImagePreviewWidget(
                localPath: fileInfo.localPath!,
                cc: cc,
                errorCallback: errorCallback,
              );
      case FileStatus.failed:
        return Row(
          children: [
            errorCallback(text: '[Image Crashed]'),
            IconButton(
              onPressed: () {
                EasyLoading.showToast('Start downloading');
                message.isRead = true;
                FileService.instance.downloadForMessage(message, fileInfo);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        );
      default:
        return errorCallback(text: '[Image Crashed]');
    }
  }

  /// Returns a Widget for displaying text based on the specified parameters.
  ///
  /// This method creates and configures a text display widget with appropriate
  /// styling and formatting options.
  static Widget getTextViewWidget(
    Message message,
    ChatController cc,
    MarkdownConfig markdownConfig,
    Widget Function({Widget? child, String? text}) errorCallback,
  ) {
    try {
      switch (message.mediaType) {
        case MessageMediaType.text:
          return errorCallback(
            child: getMarkdownView(
              message.realMessage ?? message.content,
              markdownConfig,
              message.id,
            ),
          );
        case MessageMediaType.video:
          return VideoMessageWidget(message, errorCallback);
        case MessageMediaType.image:
          return _imageTextView(message, cc, errorCallback);
        case MessageMediaType.file:
          return FileMessageWidget(message, errorCallback);
        case MessageMediaType.cashu:
          if (message.cashuInfo != null) {
            return RedPocketCashu(
              key: Key('cashu:${message.id}'),
              message: message,
            );
          }
        case MessageMediaType.lightningInvoice:
          if (message.cashuInfo != null) {
            return RedPocketLightning(
              key: Key('lightning:${message.id}'),
              message: message,
            );
          }
        case MessageMediaType.setPostOffice:
          return _getActionWidget(
            SetRoomRelayAction(cc, message),
            message,
            markdownConfig,
            errorCallback,
          );
        case MessageMediaType.groupInvite:
          return _getActionWidget(
            GroupInviteAction(message, cc.roomObs.value.getIdentity()),
            message,
            markdownConfig,
            errorCallback,
          );
        case MessageMediaType.groupInviteConfirm:
          return _getActionWidget(
            GroupInviteConfirmAction(cc.roomObs.value.getRoomName(), message),
            message,
            markdownConfig,
            errorCallback,
          );
        // bot
        case MessageMediaType.botPricePerMessageRequest:
          return _getActionWidget(
            BotPricePerMessageRequestWidget(cc, message),
            message,
            markdownConfig,
            errorCallback,
          );
        case MessageMediaType.botOneTimePaymentRequest:
          return _getActionWidget(
            BotOneTimePaymentRequestWidget(cc, message),
            message,
            markdownConfig,
            errorCallback,
          );
        case MessageMediaType.groupInvitationInfo:
          return GroupInvitationInfoWidget(cc, message, errorCallback);
        case MessageMediaType.groupInvitationRequesting:
          return GroupInvitationRequestingWidget(cc, message, errorCallback);
        case MessageMediaType.profileRequest:
          return ProfileRequestWidget(
            cc,
            message,
            cc.roomObs.value,
            errorCallback,
          );
        case MessageMediaType.contact:
          // TODO: Handle this case.
          throw UnimplementedError();
        case MessageMediaType.pdf:
          // TODO: Handle this case.
          throw UnimplementedError();
        case MessageMediaType.botText:
          // TODO: Handle this case.
          throw UnimplementedError();
        case MessageMediaType.botSelectionRequest:
          // TODO: Handle this case.
          throw UnimplementedError();
      }
    } catch (e, s) {
      logger.e('sub content: ', error: e, stackTrace: s);
    }

    return errorCallback(
      child: getMarkdownView(
        message.realMessage ?? message.content,
        markdownConfig,
        message.id,
      ),
    );
  }

  static Future<void> appendMessageOrCreate(
    String error,
    Room room,
    String content,
    NostrEventModel nostrEvent, {
    String? fromIdPubkey,
  }) async {
    final message = await DBProvider.database.messages
        .filter()
        .msgidEqualTo(nostrEvent.id)
        .findFirst();
    if (message == null) {
      await RoomService.instance.receiveDM(
        room,
        nostrEvent,
        decodedContent:
            '''
$error

track: $content''',
        senderPubkey: fromIdPubkey,
      );
      return;
    }
    message.content = '''${message.content}

$error ''';
    await MessageService.instance.updateMessageAndRefresh(message);
  }
}
