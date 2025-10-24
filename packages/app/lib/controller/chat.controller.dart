import 'dart:async' show Future, Timer, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Directory, File;

import 'package:app/controller/home.controller.dart';
import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/page/chat/RoomDraft.dart';
import 'package:app/page/components.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/file.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/signal_chat.service.dart';
import 'package:app/utils.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat_ecash/CreateInvoice/CreateInvoice_page.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart'
    show Transaction, TransactionStatus;
import 'package:mime/mime.dart' show extensionFromMime;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:super_clipboard/super_clipboard.dart';

const int maxMessageId = 999999999999;

String newlineChar = String.fromCharCode(13);

class ChatController extends GetxController {
  ChatController(Room room, {this.searchMessageId = -1}) {
    roomObs.value = room;
  }
  RxList<Message> messages = <Message>[].obs;
  RxList<Message> inputReplys = <Message>[].obs;
  RxString inputText = ''.obs;
  RxBool inputTextIsAdd = true.obs;
  RxInt messageLimit = 0.obs;

  Rx<Room> roomObs = Room(identityId: 0, toMainPubkey: '', npub: '').obs;

  RxInt statsSend = 0.obs;
  RxInt statsReceive = 0.obs;
  RxList<Room> kpaIsNullRooms = <Room>[].obs; // for signal group chat
  int searchMessageId = -1; // click message from search page
  int messageLimitPerPage = 30;

  // hide add button
  RxBool hideAdd = true.obs;
  // hide emoji
  RxBool hideEmoji = true.obs;
  // hide send button
  RxBool hideSend = true.obs;

  RxBool hideAddIcon = false.obs;

  RxBool isPressVoice = false.obs;

  // show Message's from and to address
  RxBool showFromAndTo = false.obs;

  // Prevent duplicate upload flag
  bool _isUploading = false;

  // private chat
  Rx<Contact> roomContact = Contact(pubkey: '', identityId: 0).obs;

  // group chat
  RxMap<String, RoomMember> members = <String, RoomMember>{}.obs;
  RxMap<String, RoomMember> enableMembers = <String, RoomMember>{}.obs;

  Map<String, Room> memberRooms = {}; // sendToAllGroup: rooms for each member

  // bot commands
  RxList<Map<String, dynamic>> botCommands = <Map<String, dynamic>>[].obs;

  late TextEditingController textEditingController;

  late FocusNode chatContentFocus;
  late FocusNode keyboardFocus;
  late ScrollController textFieldScrollController;
  late final ScrollController scrollController;
  late IndicatorController indicatorController;

  DateTime lastMessageAddedAt = DateTime.now();

  final List<String> featuresIcons = [
    'assets/images/photo.png',
    'assets/images/camera.png',
    'assets/images/video.png',
    'assets/images/file.png',
    'assets/images/bitcoin.png',
    'assets/images/lightning.png',
  ];

  //image video camera-image  camera-video file satos
  final List<String> featuresTitles = [
    'Album',
    'Camera',
    'Video',
    'File',
    'Sat',
    'Invoice',
  ];

  List<Function> featuresOnTaps = [];

  @override
  Future<void> onInit() async {
    scrollController = ScrollController();
    chatContentFocus = FocusNode();
    keyboardFocus = FocusNode();
    if (GetPlatform.isDesktop) {
      chatContentFocus.requestFocus();
      messageLimitPerPage = 100;
    }

    textFieldScrollController = ScrollController();
    textEditingController = TextEditingController();
    indicatorController = IndicatorController();

    // load draft
    final textFiledDraft = RoomDraft.instance.getDraft(roomObs.value.id);
    if (textEditingController.text.isEmpty && textFiledDraft != null) {
      textEditingController.text = textFiledDraft;
    }

    textEditingController.addListener(() {
      final newText = textEditingController.text;
      if (newText.contains(newlineChar)) {
        textEditingController.text = newText.replaceAll(newlineChar, '\n');
        return;
      }

      inputTextIsAdd.value = newText.length >= inputText.value.length;
      inputText.value = newText;
      RoomDraft.instance.setDraft(roomObs.value.id, newText);
    });
    await _initRoom();
    await loadAllChat(searchMsgIndex: searchMessageId);
    unawaited(isLatestMessageNip04());
    unawaited(isLatestMessageNip17());
    initChatPageFeatures();
    super.onInit();
  }

  void addMessage(Message message) {
    if (messages.isNotEmpty && messages.first.id == message.id) {
      return;
    }
    var index = 0;
    if (messages.isNotEmpty) {
      if (messages[0].createdAt.isAfter(message.createdAt)) {
        index = 1;
      }
    }
    lastMessageAddedAt = DateTime.now();

    messages.insert(index, message);
    if (scrollController.hasClients &&
        scrollController.position.pixels <= 400) {
      jumpToBottom(100);
    }
  }

  void addMetionName(String name) {
    var text = textEditingController.text.trim();
    if (text.isEmpty) {
      text = '@$name ';
      textEditingController.text = text;
      return;
    }

    final lastChar = text.substring(text.length - 1);
    if (lastChar != '@') {
      textEditingController.text = '${text.trim()} @$name ';
      return;
    }

    if (lastChar == '@' && text.length == 1) {
      text = '@$name ';
      textEditingController.text = text;
      return;
    }
    if (lastChar == '@') {
      if (text.length > 1) {
        text = text.substring(0, text.length - 1);
      }
      textEditingController.text = '${text.trim()} @$name ';
      return;
    }
  }

  Future<void> deleteMessage(Message message) async {
    await MessageService.instance.deleteMessageById(message.id);
    messages.remove(message);
  }

  RoomMember? getMemberByIdPubkey(String idPubkey) {
    return members[idPubkey];
  }

  Future<List<File>> getImageList(Directory directory) async {
    final files = directory.listSync(recursive: true);
    final imageFiles = <File>[];
    for (final file in files) {
      if (file is File && FileService.instance.isImageFile(file.path)) {
        imageFiles.add(file);
      }
    }
    imageFiles
        .sort((a, b) => b.statSync().changed.compareTo(a.statSync().changed));
    if (imageFiles.length > 30) return imageFiles.sublist(0, 30);
    return imageFiles;
  }

  Future<List<Room>> getKpaIsNullRooms() async {
    final rooms = <Room>[];
    if (!roomObs.value.isSendAllGroup) return rooms;
    final cs = Get.find<ChatxService>();

    for (final element in memberRooms.values) {
      final kpa = await cs.getRoomKPA(element);
      if (kpa == null) {
        rooms.add(element);
      }
    }
    return rooms;
  }

  Future<void> getRoomStats() async {
    statsSend.value = await DBProvider.database.messages
        .filter()
        .roomIdEqualTo(roomObs.value.id)
        .isMeSendEqualTo(true)
        .count();
    statsReceive.value = await DBProvider.database.messages
        .filter()
        .roomIdEqualTo(roomObs.value.id)
        .isMeSendEqualTo(false)
        .count();
  }

  Future<void> handleSubmitted() async {
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return;
    }

    final text = textEditingController.text.trim();
    if (text.isEmpty) {
      return;
    }
    textEditingController.clear();
    try {
      MsgReply? reply;

      if (inputReplys.isNotEmpty) {
        reply = MsgReply()
          ..content = inputReplys.first.realMessage ?? inputReplys.first.content
          ..user = inputReplys.first.fromContact?.name ?? '';
        // if it is not text, show media type name
        if (inputReplys.first.mediaType != MessageMediaType.text) {
          reply.id = inputReplys.first.msgid;
        }
      }
      if (GetPlatform.isMobile) {
        unawaited(HapticFeedback.lightImpact());
      }
      await RoomService.instance.sendMessage(roomObs.value, text, reply: reply);
      inputReplys.clear();
      hideAddIcon.value = false;
      // hideSend.value = true;
      inputText.value = '';
      inputTextIsAdd.value = true;
      await RoomService.instance.markAllReadSimple(roomObs.value);
    } catch (e, s) {
      textEditingController.text = text;
      final msg = Utils.getErrorMessage(e);
      logger.e('Failed: $msg', error: e, stackTrace: s);
      EasyLoading.showError(msg, duration: const Duration(seconds: 3));
    }
  }

  void initChatPageFeatures() {
    featuresOnTaps = [
      () => pickAndUploadImage(ImageSource.gallery),
      _handleSendWithCamera,
      () => pickAndUploadVideo(ImageSource.gallery),
      () => FileService.instance.handleFileUpload(roomObs.value),
      _handleSendSats,
      _handleSendLightning,
    ];
    // disable webrtc
    // bool isCommonRoom = roomObs.value.type == RoomType.common;
    // if (isCommonRoom) {
    //   featuresIcons.addAll(
    //       [CupertinoIcons.video_camera_solid, CupertinoIcons.phone_fill]);
    //   featuresTitles.add('Video Call');
    //   featuresTitles.add('Audio Call');
    //   featuresOnTaps.add(() => webRTCCall(CallingType.video));
    //   featuresOnTaps.add(() => webRTCCall(CallingType.audio));
    // }
  }

  void jumpToBottom(int milliseconds) {
    Timer(const Duration(milliseconds: 300), () async {
      if (scrollController.hasClients) {
        await scrollController.animateTo(
          0,
          duration: Duration(milliseconds: milliseconds),
          curve: Curves.easeIn,
        );
      }
    });
  }

  Future<void> loadAllChat({int searchMsgIndex = -1}) async {
    // fetch some old messages
    var msgIndex = searchMsgIndex;
    if (msgIndex >= 0) {
      if (msgIndex > 3) {
        msgIndex = msgIndex - 3;
      }
      await _loadLatestMessages(msgIndex);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (scrollController.hasClients) {
          scrollController.jumpTo(scrollController.position.maxScrollExtent);
        }
      });
      return;
    }
    final list = await MessageService.instance.getMessagesByView(
      roomId: roomObs.value.id,
      maxId: maxMessageId,
      isRead: true,
      limit: messageLimitPerPage,
    );
    final unreads = await MessageService.instance.getMessagesByView(
      roomId: roomObs.value.id,
      maxId: maxMessageId,
      isRead: false,
      limit: 999,
    );
    if (unreads.isNotEmpty) {
      unawaited(
        RoomService.instance.markAllRead(
          roomObs.value,
        ),
      );
    }
    unreads.addAll(list);
    final mlist = sortMessageById(unreads.toList())
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    messages.value = mlist;
    unawaited(checkPendingEcash());
  }

  Future<int> _loadLatestMessages(int searchMsgIndex) async {
    final sortedNewMessages =
        await MessageService.instance.listLatestMessageByTime(
      roomId: roomObs.value.id,
      messageId: searchMsgIndex,
      limit: messageLimitPerPage,
    );

    if (sortedNewMessages.isEmpty) {
      EasyLoading.showToast('No more messages');
      return 0;
    }

    sortedNewMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    messages
      ..insertAll(0, sortedNewMessages)
      ..value = List.from(messages);
    return sortedNewMessages.length;
  }

  Future<void> checkPendingEcash() async {
    for (final message in messages) {
      if (message.mediaType == MessageMediaType.cashu ||
          message.mediaType == MessageMediaType.lightningInvoice) {
        if (message.cashuInfo?.status == TransactionStatus.pending) {
          await checkEcashStatus(message, message.cashuInfo?.id);
        }
      }
    }
  }

  Future<void> checkEcashStatus(Message message, String? id) async {
    if (message.cashuInfo == null || id == null) {
      return;
    }

    try {
      logger.d('checkLNStatus id: $id');
      final ln = await rust_cashu.checkTransaction(id: id);
      if (message.cashuInfo!.status == ln.status) {
        return;
      }
      message.cashuInfo!.status = ln.status;
      await MessageService.instance.updateMessageAndRefresh(message);
    } catch (e, s) {
      final msg = Utils.getErrorMessage(e);
      logger.e('checkStatus error: $msg', stackTrace: s);
    }
  }

  List<Message> loadMoreChatFromSearchSroll() {
    if (messages.isEmpty) return [];

    final from = messages.first.createdAt;
    final message =
        MessageService.instance.listLastestMessage(roomId: roomObs.value.id);
    if (message != null && message.createdAt == from) {
      return [];
    }
    final list = MessageService.instance.listMessageByTimeSync(
      roomId: roomObs.value.id,
      from: from,
      limit: messageLimitPerPage,
    );
    return list;
  }

  Future<void> pullToLoadMessages() async {
    if (messages.isEmpty) return;
    if (indicatorController.edge == IndicatorEdge.leading) {
      _loadLatestMessages(messages.first.id);
      return;
    }
    // trailing
    final sortedNewMessages =
        await MessageService.instance.listOldMessageByTime(
      roomId: roomObs.value.id,
      messageId: messages.last.id,
      limit: messageLimitPerPage,
    );

    if (sortedNewMessages.isEmpty) {
      EasyLoading.showToast('No more messages');
      return;
    }

    sortedNewMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    messages.addAll(sortedNewMessages);
    messages.value = List.from(messages);
  }

  @override
  void onClose() {
    messages.clear();
    chatContentFocus.dispose();
    keyboardFocus.dispose();
    textEditingController.dispose();
    textFieldScrollController.dispose();
    indicatorController.dispose();
    super.onClose();
  }

  // check if the latest message is nip04
  Future<void> isLatestMessageNip04() async {
    if (messages.isEmpty) return;

    if (roomObs.value.type == RoomType.common &&
        roomObs.value.encryptMode == EncryptMode.nip04) {
      final lastMessage = messages.firstWhereOrNull((msg) => !msg.isMeSend);
      if (lastMessage == null) return;
      if (lastMessage.encryptType == MessageEncryptType.nip4) {
        await Get.dialog<void>(
          CupertinoAlertDialog(
            title: const Text('Deprecated Encryption'),
            content: const Text('''
Your friends uses a deprecated encryption method-NIP04.
Keychat is using NIP17 and SignalProtocol, and your friends may not be able to decrypt the messages you reply to.
'''),
            actions: [
              CupertinoDialogAction(
                onPressed: Get.back,
                child: const Text('OK'),
              ),
              CupertinoDialogAction(
                child: const Text('Share One-Time Link'),
                onPressed: () async {
                  Get.back<void>();
                  await showMyQrCode(
                    Get.context!,
                    roomObs.value.getIdentity(),
                    true,
                  );
                },
              ),
            ],
          ),
        );
      }
    }
  }

  // check if the latest message is nip04
  Future<void> isLatestMessageNip17() async {
    if (messages.isEmpty) return;

    if (roomObs.value.type == RoomType.common &&
        roomObs.value.encryptMode != EncryptMode.signal) {
      final myLastMessage = messages.firstWhereOrNull((msg) => msg.isMeSend);
      final hisLastMessage = messages.firstWhereOrNull((msg) => !msg.isMeSend);
      if (myLastMessage == null || hisLastMessage == null) return;
      if (hisLastMessage.encryptType == MessageEncryptType.nip17 &&
          myLastMessage.encryptType == MessageEncryptType.nip17) {
        await Get.dialog<void>(
          CupertinoAlertDialog(
            title: const Text('Start a Private Chat'),
            content: const Text('''
The current message encryption mode uses the NIP17 protocol. 
Add as a friend and start the signal protocol chat
'''),
            actions: [
              CupertinoDialogAction(
                onPressed: Get.back,
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                child: const Text('Start Private Chat'),
                onPressed: () async {
                  Get.back<void>();
                  await SignalChatService.instance
                      .resetSignalSession(roomObs.value);
                },
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> pickAndUploadImage(ImageSource imageSource) async {
    // Prevent duplicate clicks
    if (_isUploading) {
      EasyLoading.showToast('File uploading, please wait...');
      return;
    }

    EasyLoading.show(status: 'Loading...');
    XFile? xfile;
    try {
      final picker = ImagePicker();
      xfile = await picker.pickImage(
        source: imageSource,
        imageQuality: 70,
        maxWidth: 1920,
      );
    } catch (e, s) {
      logger.e('pickAndUploadImage', error: e, stackTrace: s);
    } finally {
      EasyLoading.dismiss();
    }

    if (xfile == null) return;
    Get.dialog(
      CupertinoAlertDialog(
        content: SizedBox(
          width: 300,
          child: FileService.instance.getImageView(File(xfile.path)),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: Get.back,
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              if (_isUploading) {
                EasyLoading.showToast('File uploading, please wait...');
                return;
              }
              _isUploading = true;
              try {
                await FileService.instance.handleSendMediaFile(
                  roomObs.value,
                  xfile!,
                  MessageMediaType.image,
                  true,
                );
                Get.back<void>();
              } finally {
                _isUploading = false;
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> pickAndUploadVideo(ImageSource imageSource) async {
    // Prevent duplicate clicks
    if (_isUploading) {
      EasyLoading.showToast('File uploading, please wait...');
      return;
    }

    EasyLoading.show(status: 'Loading...');
    XFile? xfile;
    try {
      final picker = ImagePicker();
      xfile = await picker.pickVideo(source: imageSource);
    } catch (e, s) {
      logger.e('pickVideo', error: e, stackTrace: s);
    } finally {
      EasyLoading.dismiss();
    }

    if (xfile == null) return;

    _isUploading = true;
    try {
      EasyLoading.showProgress(0.2, status: 'Encrypting and Uploading...');

      await FileService.instance.handleSendMediaFile(
        roomObs.value,
        xfile,
        MessageMediaType.video,
        true,
      );
      hideAdd.value = true; // close features section
      EasyLoading.dismiss();
    } catch (e, s) {
      EasyLoading.dismiss();
      final msg = Utils.getErrorMessage(e);
      EasyLoading.showError(msg, duration: const Duration(seconds: 3));
      logger.e('encrypt And SendFile', error: e, stackTrace: s);
    } finally {
      _isUploading = false;
      hideAdd.trigger(true);
    }
  }

  void processClickBlankArea() {
    hideAdd.value = true;
    hideEmoji.value = true;
    Utils.hideKeyboard(Get.context!);
    // chatContentFocus.unfocus();
  }

  Future<void> resetMembers() async {
    // mls group
    if (roomObs.value.isMLSGroup) {
      final list = await MlsGroupService.instance.getMembers(roomObs.value);
      enableMembers.value = list;
      members.value = list;

      final admin = await roomObs.value.getAdmin();
      if (admin != null) {
        members[admin]!.isAdmin = true;
        enableMembers[admin]!.isAdmin = true;
      }
      // update member's avatar
      await updateRoomMembersAvatar();
      return;
    }
    // signal group
    if (roomObs.value.isSendAllGroup) {
      members.value = await roomObs.value.getMembers();
      enableMembers.value = await roomObs.value.getEnableMembers();
      // update member's avatar
      await updateRoomMembersAvatar();
      memberRooms = await roomObs.value.getEnableMemberRooms();
      kpaIsNullRooms.value = await getKpaIsNullRooms(); // get null list
    }
  }

  Future<void> updateRoomMembersAvatar() async {
    for (final member in members.values) {
      final contact = await ContactService.instance.saveContactFromQrCode(
        identityId: roomObs.value.identityId,
        pubkey: member.idPubkey,
        avatarRemoteUrl: member.avatarUrl,
      );

      enableMembers[member.idPubkey]?.contact = contact;
      members[member.idPubkey]?.contact = contact;
    }
  }

  void setRoom(Room newRoom) {
    if (newRoom.contact != null) {
      roomContact(newRoom.contact);
      roomContact.refresh();
    }
    roomObs(newRoom);
    roomObs.refresh();
  }

  List<Message> sortMessageById(List<Message> list) {
    for (var i = 0; i < list.length - 1; i++) {
      final a = list[i];
      final b = list[i + 1];
      if (a.createdAt == b.createdAt && b.id > a.id) {
        list[i] = b;
        list[i + 1] = a;
      }
    }
    return list;
  }

  Future<void> _handleSendSats() async {
    final cashuInfo = await Get.bottomSheet<CashuInfoModel>(
      clipBehavior: Clip.hardEdge,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      const CashuSendPage(true),
    );
    if (cashuInfo == null) return;
    try {
      logger.d(cashuInfo.toString());
      await RoomService.instance.sendMessage(
        roomObs.value,
        cashuInfo.token,
        realMessage: cashuInfo.toString(),
        mediaType: MessageMediaType.cashu,
      );
      hideAdd.value = true; // close features section
    } catch (e, s) {
      final msg = Utils.getErrorMessage(e);
      logger.e(msg, error: e, stackTrace: s);
      EasyLoading.showError(msg);
    }
  }

  Future<void> _handleSendLightning() async {
    final invoice = await Get.bottomSheet<Transaction>(
      clipBehavior: Clip.hardEdge,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      CreateInvoicePage(),
    );
    if (invoice == null) return;

    try {
      final cim = CashuInfoModel()
        ..amount = invoice.amount.toInt()
        ..token = invoice.token
        ..mint = invoice.mintUrl
        ..status = invoice.status
        ..hash = invoice.id
        ..expiredAt = DateTime.fromMillisecondsSinceEpoch(
          invoice.timestamp.toInt() * 1000,
        );
      await RoomService.instance.sendMessage(
        roomObs.value,
        invoice.token,
        realMessage: cim.toString(),
        mediaType: MessageMediaType.lightningInvoice,
      );
      hideAdd.value = true; // close features section
    } catch (e, s) {
      final msg = Utils.getErrorMessage(e);
      logger.e(msg, error: e, stackTrace: s);
      EasyLoading.showError(msg);
    }
  }

  Future<void> _handleSendWithCamera() async {
    if (GetPlatform.isMacOS) {
      EasyLoading.showToast('Camera not supported on MacOS');
      return;
    }

    // Prevent duplicate clicks
    if (_isUploading) {
      EasyLoading.showToast('File uploading, please wait...');
      return;
    }

    var isGranted = true;
    if (GetPlatform.isMobile || GetPlatform.isWindows) {
      isGranted = await Permission.camera.request().isGranted;
    }
    if (isGranted) {
      await pickAndUploadImage(ImageSource.camera);
      hideAdd.value = true; // close features section
    } else {
      EasyLoading.showToast('Camera permission not grant');
      await Future.delayed(const Duration(milliseconds: 1000), () => {});
      openAppSettings();
    }
  }

  Future<void> _initBotInfo() async {
    final list =
        await NostrAPI.instance.fetchMetadata([roomObs.value.toMainPubkey]);
    if (list.isEmpty) return;
    final res = list.last;
    final metadata = Map<String, dynamic>.from(
      jsonDecode(res.content) as Map<String, dynamic>,
    );
    if (roomObs.value.botInfoUpdatedAt >= res.createdAt) {
      botCommands.value = List<Map<String, dynamic>>.from(
        (metadata['commands'] ?? []) as Iterable,
      );
      return;
    }
    // not a bot account
    if (metadata['type'] == null) return;
    if (!metadata['type'].toString().toLowerCase().endsWith('bot')) {
      return;
    }
    roomObs.value.type = RoomType.bot;
    roomObs.value.status = RoomStatus.enabled;

    roomObs.value.botInfoUpdatedAt = res.createdAt;
    botCommands.value = List<Map<String, dynamic>>.from(
      (metadata['commands'] ?? []) as Iterable,
    );

    final metadataString = jsonEncode(metadata);
    roomObs.value.botInfo = metadataString;
    roomObs.value.name = metadata['name'] as String? ?? roomObs.value.name;
    roomObs.value.description = metadata['description'] as String?;

    // save config for botPricePerMessageRequest
    if (metadata['botPricePerMessageRequest'] != null) {
      try {
        final config = jsonEncode(metadata['botPricePerMessageRequest']);
        await MessageService.instance.saveSystemMessage(
          roomObs.value,
          config,
          suffix: '',
          isMeSend: false,
        );
      } catch (e) {
        logger.e(
          'botPricePerMessageRequest: $e',
          error: e,
          stackTrace: StackTrace.current,
        );
      }
    }
    await RoomService.instance.updateRoomAndRefresh(roomObs.value);
  }

  Future<void> _initRoom() async {
    // group
    if (roomObs.value.type == RoomType.group) {
      if (roomObs.value.isMLSGroup) {
        Future.delayed(const Duration(seconds: 2)).then(
          (value) => {
            MlsGroupService.instance.fixMlsOnetimeKey([roomObs.value]),
          },
        );
      }
      return resetMembers();
    }
    // private chat
    if (roomObs.value.type == RoomType.common) {
      if (roomObs.value.contact == null) {
        final contact = await ContactService.instance.getOrCreateContact(
          identityId: roomObs.value.identityId,
          pubkey: roomObs.value.toMainPubkey,
        );
        roomObs.value.contact = contact;
        roomContact.value = contact;
      } else {
        roomContact.value = roomObs.value.contact!;
      }
      // use the local file first.
      if (roomContact.value.avatarLocalPath == null) {
        fetchAndUpdateMetadata(
          roomContact.value.pubkey,
          roomContact.value.identityId,
        ).then((Contact? item) {
          if (item == null) return;
          roomContact.value = item;
          roomObs.value.contact = item;
          roomObs.refresh();
          Get.find<HomeController>()
              .loadIdentityRoomList(roomContact.value.identityId);
        });
      }
      return;
    }
    if (roomObs.value.type == RoomType.bot) {
      unawaited(_initBotInfo());
    }
  }

  Contact getContactByPubkey(String pubkey) {
    if (roomObs.value.type != RoomType.group) return roomContact.value;
    return members[pubkey]?.contact ??
        Contact(identityId: roomObs.value.identityId, pubkey: pubkey);
  }

  Future<Contact> fetchAndUpdateMetadata(String pubkey, int identityId) async {
    var metadata = <String, dynamic>{};

    var contacts = await ContactService.instance.getContacts(pubkey);
    if (contacts.isEmpty) {
      final result = await ContactService.instance.createContact(
        pubkey: pubkey,
        identityId: identityId,
        autoCreateFromGroup: roomObs.value.type == RoomType.group,
      );
      contacts = [result];
    }
    // ignore fetch in a hour in kReleaseMode
    if (kReleaseMode && contacts.first.fetchFromRelayAt != null) {
      if (contacts.first.fetchFromRelayAt!
          .add(const Duration(days: 1))
          .isAfter(DateTime.now())) {
        return contacts.first;
      }
    }
    try {
      final list = await NostrAPI.instance.fetchMetadata([pubkey]);
      if (list.isEmpty) return contacts.first;
      final res = list.last;

      loggerNoLine.i('metadata: ${res.content}');
      metadata = Map<String, dynamic>.from(
        jsonDecode(res.content) as Map<String, dynamic>,
      );
      final nameFromRelay =
          (metadata['displayName'] ?? metadata['name']) as String?;
      final avatarFromRelay =
          (metadata['picture'] ?? metadata['avatar']) as String?;
      final description = (metadata['description'] ??
          metadata['about'] ??
          metadata['bio']) as String?;
      for (final contact in contacts) {
        if (contact.versionFromRelay >= res.createdAt) {
          continue;
        }

        // Handle avatar download if URL changed
        if (avatarFromRelay != null && avatarFromRelay.isNotEmpty) {
          if (avatarFromRelay.startsWith('http') ||
              avatarFromRelay.startsWith('https')) {
            contact.avatarFromRelay = avatarFromRelay;

            // Download avatar if URL changed
            if (contact.avatarFromRelay != contact.avatarFromRelayLocalPath) {
              try {
                final localPath = await FileService.instance
                    .downloadAndSaveAvatar(avatarFromRelay, pubkey);
                if (localPath != null) {
                  contact.avatarFromRelayLocalPath = localPath;
                }
              } catch (e, s) {
                logger.e(
                  'Failed to download avatar: $e',
                  error: e,
                  stackTrace: s,
                );
              }
            }
          }
        }

        contact
          ..nameFromRelay = nameFromRelay
          ..aboutFromRelay = description
          ..metadataFromRelay = res.content
          ..fetchFromRelayAt = DateTime.now()
          ..versionFromRelay = res.createdAt;
        loggerNoLine.i(
          'fetchUserMetadata: ${contact.pubkey} name: ${contact.nameFromRelay} avatar: ${contact.avatarFromRelay} ${contact.aboutFromRelay}',
        );
        await ContactService.instance.saveContact(contact);
      }
    } catch (e) {
      logger.e('fetchUserMetadata: $e', error: e);
    }
    return contacts.firstWhereOrNull((item) => item.identityId == identityId) ??
        contacts.first;
  }

  Future<bool> handlePasteboardFile() async {
    // Clipboard API is not supported on this platform.
    if (SystemClipboard.instance == null) return false;
    final reader = await SystemClipboard.instance!.read();
    if (reader.items.isEmpty) {
      return false;
    }

    final fileFormats = [
      (Formats.png, MessageMediaType.image),
      (Formats.jpeg, MessageMediaType.image),
      (Formats.webp, MessageMediaType.image),
      (Formats.svg, MessageMediaType.image),
      (Formats.gif, MessageMediaType.image),
      (Formats.tiff, MessageMediaType.image),
      (Formats.bmp, MessageMediaType.image),
      (Formats.ico, MessageMediaType.image),
      (Formats.heic, MessageMediaType.image),
      (Formats.heif, MessageMediaType.image),
      (Formats.mp4, MessageMediaType.video),
      (Formats.pdf, MessageMediaType.file),
      (Formats.mov, MessageMediaType.video),
      (Formats.m4v, MessageMediaType.video),
      (Formats.avi, MessageMediaType.video),
      (Formats.mpeg, MessageMediaType.video),
      (Formats.webm, MessageMediaType.video),
      (Formats.ogg, MessageMediaType.video),
      (Formats.wmv, MessageMediaType.video),
      (Formats.flv, MessageMediaType.video),
      (Formats.mkv, MessageMediaType.video),
      (Formats.mp3, MessageMediaType.file),
      (Formats.oga, MessageMediaType.file),
      (Formats.aac, MessageMediaType.file),
      (Formats.wav, MessageMediaType.file),
      (Formats.doc, MessageMediaType.file),
      (Formats.docx, MessageMediaType.file),
      (Formats.csv, MessageMediaType.file),
      (Formats.xls, MessageMediaType.file),
      (Formats.xlsx, MessageMediaType.file),
      (Formats.ppt, MessageMediaType.file),
      (Formats.pptx, MessageMediaType.file),
      (Formats.json, MessageMediaType.file),
      (Formats.zip, MessageMediaType.file),
      (Formats.tar, MessageMediaType.file),
      (Formats.gzip, MessageMediaType.file),
      (Formats.bzip2, MessageMediaType.file),
      (Formats.rar, MessageMediaType.file),
      (Formats.dmg, MessageMediaType.file),
      (Formats.iso, MessageMediaType.file),
      (Formats.deb, MessageMediaType.file),
      (Formats.rpm, MessageMediaType.file),
      (Formats.apk, MessageMediaType.file),
      (Formats.exe, MessageMediaType.file),
      (Formats.msi, MessageMediaType.file),
      (Formats.plainTextFile, MessageMediaType.file),
      (Formats.htmlFile, MessageMediaType.file),
      (Formats.webUnknown, MessageMediaType.file),
    ];
    if (reader.canProvide(Formats.fileUri)) {
      for (var i = 0; i < fileFormats.length; i++) {
        final format = fileFormats[i].$1;
        final mediaType = fileFormats[i].$2;
        final canProcess = reader.canProvide(format);
        if (canProcess) {
          logger.d('Clipboard can provide: $format');
          await _readFromStream(
            reader,
            format,
            mediaType,
            mediaType == MessageMediaType.video,
          );
          return true;
        }
      }
    }

    // _pasteFallinImage
    for (final format in fileFormats) {
      // skip plain text
      if (format.$1 == Formats.plainTextFile) continue;
      if (format.$1 == Formats.htmlFile) continue;
      final canProcess = reader.canProvide(format.$1);
      if (canProcess) {
        logger.d('_pasteFallinImage Clipboard can provide: $format');
        await _readFromStream(reader, format.$1, format.$2, false);
        return true;
      }
    }
    return false;
  }

  Future<void> handlePasteboard() async {
    // Clipboard API is not supported on this platform.
    if (SystemClipboard.instance == null) return;

    final reader = await SystemClipboard.instance!.read();
    if (reader.items.isEmpty) {
      return;
    }

    final isFile = reader.canProvide(Formats.fileUri);
    loggerNoLine.i('Clipboard can provide file: $isFile');
    if (isFile) {
      await handlePasteboardFile();
      return;
    }
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text;
    if (text == null || text.isEmpty) {
      await handlePasteboardFile();
      return;
    }
    // plain text
    await _handlePastePlainText(text);
  }

  Future<void> _handlePastePlainText(String text) async {
    loggerNoLine.i('Clipboard plain text: $text');
    final currentText = textEditingController.text;
    final selection = textEditingController.selection;

    String newText;
    int newCursorPosition;

    // If there's selected text, replace it
    if (selection.isValid && !selection.isCollapsed) {
      newText = currentText.substring(0, selection.start) +
          text +
          currentText.substring(selection.end);
      newCursorPosition = selection.start + text.length;
    } else {
      // If no selection, insert at cursor position
      var cursorPosition = selection.baseOffset;

      // If no cursor position is set, append to the end
      if (cursorPosition < 0) {
        cursorPosition = currentText.length;
      }

      newText = currentText.substring(0, cursorPosition) +
          text +
          currentText.substring(cursorPosition);
      newCursorPosition = cursorPosition + text.length;
    }

    textEditingController.text = newText;

    // Set cursor position after inserted text
    textEditingController.selection =
        TextSelection.fromPosition(TextPosition(offset: newCursorPosition));
  }

  Future<void> _readFromStream(
    ClipboardReader reader,
    SimpleFileFormat format,
    MessageMediaType type, [
    bool compress = true,
  ]) async {
    /// Binary formats need to be read as streams
    reader.getFile(format, (DataReaderFile file) async {
      var suggestedName = await reader.getSuggestedName();
      final mimeType = format.mimeTypes?.first;

      try {
        final imageBytes = await file.readAll();
        final sourceFileName = textEditingController.text.trim();
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        if (suggestedName == null) {
          String? suffix;
          if (mimeType != null) {
            suffix = extensionFromMime(mimeType);
          }
          if (sourceFileName.isNotEmpty && sourceFileName.contains('.')) {
            final inputName = sourceFileName.split('.').first;
            final inputSuffix = sourceFileName.split('.').last;
            suggestedName = '$inputName.${suffix ?? inputSuffix}';
            textEditingController.clear();
          }
          suffix ??= 'bin';
          suggestedName ??= 'pasteboard_$timestamp.$suffix';
        } else if (textEditingController.text.trim() == sourceFileName) {
          textEditingController.clear();
        }
        final path = '${tempDir.path}/$suggestedName';
        final teampFile = File(path);
        await teampFile.writeAsBytes(imageBytes);

        final xfile = XFile(
          path,
          bytes: imageBytes,
          mimeType: mimeType,
          name: suggestedName,
        );
        final isImage = FileService.instance.isImageFile(xfile.path);
        if (!isImage) {
          if (_isUploading) {
            EasyLoading.showToast('File uploading, please wait...');
            return;
          }
          _isUploading = true;
          try {
            await FileService.instance
                .handleSendMediaFile(roomObs.value, xfile, type, compress);
          } finally {
            _isUploading = false;
          }
          return;
        }
        await Get.dialog(
          CupertinoAlertDialog(
            content: SizedBox(
              width: 300,
              child: FileService.instance.getImageView(File(xfile.path)),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: Get.back,
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () async {
                  if (_isUploading) {
                    EasyLoading.showToast('File uploading, please wait...');
                    return;
                  }
                  _isUploading = true;
                  try {
                    await FileService.instance.handleSendMediaFile(
                      roomObs.value,
                      xfile,
                      MessageMediaType.image,
                      true,
                    );
                    Get.back<void>();
                  } finally {
                    _isUploading = false;
                  }
                },
                child: const Text('Send'),
              ),
            ],
          ),
        );
      } catch (e, s) {
        logger.e('_readFromStream: $e', stackTrace: s);
      } finally {
        Future.delayed(const Duration(seconds: 3)).then((_) {
          EasyLoading.dismiss();
        });
      }
    });
  }

  // from search page
  Future<void> loadFromMessageId(int messageId) async {
    messages.clear();
    await loadAllChat(searchMsgIndex: messageId);
  }
}
