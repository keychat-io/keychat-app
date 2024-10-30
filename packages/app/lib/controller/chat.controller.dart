import 'dart:async' show Future, Timer;
import 'dart:convert';
import 'dart:io' show Directory, File, FileSystemEntity;

import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/chat/RoomDraft.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/file_util.dart' as file_util;
import 'package:app/service/message.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar/isar.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rust_signal;
import 'package:permission_handler/permission_handler.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../models/db_provider.dart';
import '../service/contact.service.dart';
import '../service/file_util.dart';
import '../service/room.service.dart';

const int messageLimitPerPage = 30;
String newlineChar = String.fromCharCode(13);

class ChatController extends GetxController {
  RxList<Message> messages = <Message>[].obs;
  List<Message> messagesMore = <Message>[];
  RxList<Message> inputReplys = <Message>[].obs;

  Rx<RoomMember> meMember =
      RoomMember(idPubkey: '', name: '', roomId: -1).obs; // it's me
  RxString inputText = ''.obs;
  RxBool inputTextIsAdd = true.obs;
  RxInt messageLimit = 0.obs;

  Rx<Room> roomObs = Room(
          identityId: 0,
          toMainPubkey: '',
          npub: '',
          type: RoomType.common,
          status: RoomStatus.init)
      .obs;

  RxInt statsSend = 0.obs;
  RxInt statsReceive = 0.obs;
  RxInt unreadIndex = (-1).obs;
  RxList<Room> kpaIsNullRooms = <Room>[].obs; // for signal group chat
  RxInt searchMsgIndex = (-1).obs;
  Rx<DateTime> searchDt = DateTime.now().obs;

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

  // private chat
  Rx<Contact> roomContact = Contact(pubkey: '', npubkey: '', identityId: 0).obs;

  // group chat
  RxList<RoomMember> members = <RoomMember>[].obs;
  RxList<RoomMember> enableMembers = <RoomMember>[].obs;
  Map<String, Room> memberRooms = {}; // sendToAllGroup: rooms for each member

  // bot commands
  RxList<Map<String, dynamic>> botCommands = <Map<String, dynamic>>[].obs;

  late TextEditingController textEditingController;

  late FocusNode chatContentFocus;
  late FocusNode keyboardFocus;
  late AutoScrollController autoScrollController;
  late ScrollController textFieldScrollController;
  Room room;
  BuildContext? context;

  final List<IconData> featuresIcons = [
    Icons.image,
    Icons.camera_alt,
    Icons.movie,
    Icons.upload_file_sharp,
    Icons.currency_bitcoin,
  ];

  //image video camera-image  camera-video file satos
  final List<String> featuresTitles = [
    'Album',
    'Camera',
    'Video',
    'File',
    'SAT',
  ];

  List<Function> featuresOnTaps = [];
  WebsocketService ws = Get.find<WebsocketService>();

  ChatController(this.room) {
    roomObs.value = room;
  }

  addMessage(Message message) {
    if (messages.isNotEmpty && messages.first.id == message.id) {
      return;
    }
    int index = 0;
    if (messages.isNotEmpty) {
      if (messages[0].createdAt.isAfter(message.createdAt)) {
        index = 1;
      }
    }
    if (autoScrollController.position.pixels <= 300) {
      messages.insert(index, message);
    } else {
      messagesMore.add(message);
    }

    try {
      bool isCurrent = DBProvider().isCurrentPage(message.roomId);
      if (!isCurrent) return;
      if (autoScrollController.position.pixels < 100) {
        jumpToBottom(100);
      }
    } catch (e, s) {
      logger.e('jump error', error: e, stackTrace: s);
    }
  }

  void addMetionName(String name) {
    String text = textEditingController.text.trim();
    if (text.isEmpty) {
      text = '@$name ';
      textEditingController.text = text;
      return;
    }

    String lastChar = text.substring(text.length - 1);
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

  deleteMessage(Message message) async {
    await MessageService().deleteMessageById(message.id);
    messages.remove(message);
  }

  emoticonClick(String name) {
    textEditingController.text = name;
  }

  Contact getContactByMessage(Message message) {
    if (room.type == RoomType.common) {
      return roomContact.value;
    }
    var roomMember = members
        .firstWhereOrNull((element) => element.idPubkey == message.idPubkey);
    roomMember ??= RoomMember(
        idPubkey: message.from, name: 'Deleted', roomId: roomObs.value.id);

    return Contact(
        pubkey: roomMember.idPubkey, npubkey: '', identityId: room.identityId)
      ..petname = roomMember.name;
  }

  Future<List<File>> getImageList(Directory directory) async {
    List<FileSystemEntity> files = directory.listSync(recursive: true);
    List<File> imageFiles = [];
    for (var file in files) {
      if (file is File && file_util.isImageFile(file.path)) {
        imageFiles.add(file);
      }
    }
    imageFiles
        .sort((a, b) => b.statSync().changed.compareTo(a.statSync().changed));
    if (imageFiles.length > 30) return imageFiles.sublist(0, 30);
    return imageFiles;
  }

  Future<List<Room>> getKpaIsNullRooms() async {
    List<Room> rooms = [];
    if (!room.isSendAllGroup) return rooms;
    ChatxService cs = Get.find<ChatxService>();

    for (var element in memberRooms.values) {
      rust_signal.KeychatProtocolAddress? kpa = await cs.getRoomKPA(element);
      if (kpa == null) {
        rooms.add(element);
      }
    }
    return rooms;
  }

  RoomMember? getRoomMemberByMessage(Message message) {
    return members
        .firstWhereOrNull((element) => element.idPubkey == message.idPubkey);
  }

  getRoomStats() async {
    statsSend.value = await DBProvider.database.messages
        .filter()
        .roomIdEqualTo(room.id)
        .isMeSendEqualTo(true)
        .count();
    statsReceive.value = await DBProvider.database.messages
        .filter()
        .roomIdEqualTo(room.id)
        .isMeSendEqualTo(false)
        .count();
  }

  Future handleSubmitted() async {
    String text = textEditingController.text.trim();
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
        await Haptics.vibrate(HapticsType.light);
      }
      await RoomService().sendTextMessage(roomObs.value, text, reply: reply);
      inputReplys.clear();
      hideAddIcon.value = false;
      // hideSend.value = true;
      inputText.value = '';
      inputTextIsAdd.value = true;
      jumpToBottom(100);
    } catch (e, s) {
      textEditingController.text = text;
      String msg = Utils.getErrorMessage(e);
      logger.e('Failed: $msg', error: e, stackTrace: s);
      EasyLoading.showError(msg, duration: const Duration(seconds: 3));
    }
  }

  initChatPageFeatures() {
    featuresOnTaps = [
      () => pickAndUploadImage(ImageSource.gallery),
      _handleSendWithCamera,
      () => pickAndUploadVideo(ImageSource.gallery),
      _handleFileUpload,
      _handleSendSats,
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

  jumpToBottom(int milliseconds) {
    Timer(const Duration(milliseconds: 300), () {
      if (autoScrollController.hasClients) {
        autoScrollController.animateTo(
          0.0,
          duration: Duration(milliseconds: milliseconds),
          curve: Curves.easeIn,
        );
      }
    });
  }

  jumpToBottom2([int height = 10]) {
    Timer(const Duration(milliseconds: 300), () {
      if (autoScrollController.positions.isNotEmpty &&
          autoScrollController.hasClients) {
        autoScrollController.jumpTo(0.0);
      }
    });
  }

  Future loadAllChat() async {
    DateTime from = DateTime.now();
    List<Message> list = await MessageService().getMessagesByView(
        roomId: roomObs.value.id,
        from: from,
        isRead: true,
        limit: messageLimitPerPage);
    List<Message> unreads = await MessageService().getMessagesByView(
        roomId: roomObs.value.id, from: from, isRead: false, limit: 200);
    if (unreads.isNotEmpty) {
      if (unreads.length > 12) {
        unreadIndex.value = unreads.length - 1;
      }
      RoomService().markAllRead(identityId: room.identityId, roomId: room.id);
    }
    unreads.addAll(list);
    messages.value = sortMessageById(unreads.toList());
    messages.sort(((a, b) => b.createdAt.compareTo(a.createdAt)));
    messages.refresh();
  }

  loadAllChatFromSearchScroll() {
    messages.clear();
    DateTime from = searchDt.value;
    var list = MessageService().listMessageBySearchSroll(
        roomId: roomObs.value.id, from: from, limit: 7);
    messages.addAll(sortMessageById(list));
    messages.sort(((a, b) => b.createdAt.compareTo(a.createdAt)));
    messages.refresh();
  }

  loadLatestMessage() async {
    late DateTime from;
    if (messages.isEmpty) {
      from = DateTime.now();
    } else {
      from = messages.first.createdAt;
    }
    List<Message> list = await MessageService()
        .listLatestMessage(roomId: roomObs.value.id, from: from);
    Map<int, Message> msgs = {};
    for (var element in messages) {
      msgs[element.id] = element;
    }
    List<Message> list2 = msgs.values.toList();
    list2.addAll(list);
    list2.sort(((a, b) => b.createdAt.compareTo(a.createdAt)));
    messages.value = list2;
  }

  List<Message> loadMoreChatFromSearchSroll() {
    if (messages.isEmpty) return [];

    DateTime from = messages.first.createdAt;
    Message? message = MessageService().listLastestMessage(
      roomId: roomObs.value.id,
    );
    if (message != null && message.createdAt == from) {
      return [];
    }
    var list = MessageService().listMessageByTimeSync(
        roomId: roomObs.value.id, from: from, limit: messageLimitPerPage);
    return list;
  }

  Future loadMoreChatHistory() async {
    if (messages.isEmpty) return;

    DateTime from = messages.last.createdAt;
    var list = await MessageService().listMessageByTime(
        roomId: roomObs.value.id, from: from, limit: messageLimitPerPage);
    messages.addAll(sortMessageById(list));
    messages.sort(((a, b) => b.createdAt.compareTo(a.createdAt)));
    messages.refresh();
  }

  @override
  void onClose() {
    messages.clear();
    chatContentFocus.dispose();
    keyboardFocus.dispose();
    textEditingController.dispose();
    textFieldScrollController.dispose();
    autoScrollController.dispose();
    super.onClose();
  }

  @override
  void onInit() async {
    chatContentFocus = FocusNode();
    keyboardFocus = FocusNode();
    chatContentFocus.addListener(() {
      if (GetPlatform.isMobile) {
        jumpToBottom2(10);
      }
    });
    if (GetPlatform.isDesktop) {
      chatContentFocus.requestFocus();
    }

    textFieldScrollController = ScrollController();
    textEditingController = TextEditingController();
    autoScrollController = AutoScrollController(
      viewportBoundaryGetter: () =>
          Rect.fromLTRB(0, 0, 0, MediaQuery.of(Get.context!).padding.bottom),
      axis: Axis.vertical,
    );

    autoScrollController.addListener(() {
      bool isCurrent = DBProvider().isCurrentPage(room.id);
      if (!isCurrent) {
        messagesMore.clear();
        searchMsgIndex.value = -1;
      }
      if (messagesMore.isNotEmpty &&
          autoScrollController.position.pixels <= 100) {
        messages.addAll(sortMessageById(messagesMore));
        messages.sort(((a, b) => b.createdAt.compareTo(a.createdAt)));
        messages.refresh();
        messagesMore.clear();
      }
    });

    // load draft
    String? textFiledDraft = RoomDraft.instance.getDraft(room.id);
    if (textEditingController.text.isEmpty && textFiledDraft != null) {
      textEditingController.text = textFiledDraft;
    }

    textEditingController.addListener(() {
      String newText = textEditingController.text;
      if (newText.contains(newlineChar)) {
        textEditingController.text = newText.replaceAll(newlineChar, '\n');
        return;
      }

      inputTextIsAdd.value = newText.length >= inputText.value.length;
      inputText.value = newText;
      RoomDraft.instance.setDraft(room.id, newText);
    });
    await _initRoom(room);
    await loadAllChat();

    if (searchMsgIndex.value > 0) {
      loadAllChatFromSearchScroll();
    }
    initChatPageFeatures();
    super.onInit();
  }

  @override
  onReady() {
    Future.delayed(const Duration(milliseconds: 200), () {
      jumpToBottom2(10);
    });
  }

  openPageAction() async {
    await loadLatestMessage();
    RoomService().markAllRead(identityId: room.identityId, roomId: room.id);
  }

  pickAndUploadImage(ImageSource imageSource) async {
    EasyLoading.show(status: 'Loading...');
    XFile? xfile;
    try {
      final ImagePicker picker = ImagePicker();
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
    Get.dialog(CupertinoAlertDialog(
      content: SizedBox(
        width: 300,
        child: FileUtils.getImageView(File(xfile.path)),
      ),
      actions: [
        CupertinoDialogAction(
          child: const Text('Cancel'),
          onPressed: () {
            Get.back();
          },
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () async {
            await _handleSendMediaFile(xfile!, MessageMediaType.image, true);
            Get.back();
          },
          child: const Text('OK'),
        ),
      ],
    ));
  }

  pickAndUploadVideo(ImageSource imageSource) async {
    EasyLoading.show(status: 'Loading...');
    XFile? xfile;
    try {
      final ImagePicker picker = ImagePicker();
      xfile = await picker.pickVideo(source: imageSource);
    } catch (e, s) {
      logger.e('pickVideo', error: e, stackTrace: s);
    } finally {
      EasyLoading.dismiss();
    }

    if (xfile == null) return;
    try {
      EasyLoading.showProgress(0.05, status: 'Encrypting and Uploading...');
      await FileUtils.encryptAndSendFile(
          roomObs.value, xfile, MessageMediaType.video, false,
          onSendProgress: (count, total) => FileUtils.onSendProgress(
              'Encrypting and Uploading...', count, total));
      hideAdd.value = true; // close features section
      EasyLoading.dismiss();
    } catch (e, s) {
      EasyLoading.dismiss();
      String msg = Utils.getErrorMessage(e);
      EasyLoading.showError('status: $msg',
          duration: const Duration(seconds: 3));
      logger.e('encrypt And SendFile', error: e, stackTrace: s);
    } finally {
      hideAdd.trigger(true);
    }
  }

  processClickBlank() {
    hideAdd.value = true;
    hideEmoji.value = true;
    Utils.hideKeyboard(Get.context!);
    // chatContentFocus.unfocus();
  }

  Future resetMembers() async {
    members.value = await room.getMembers();
    enableMembers.value = members
        .toList()
        .where((element) => element.status == UserStatusType.invited)
        .toList();
    if (room.isSendAllGroup) {
      memberRooms = await room.getEnableMemberRooms();
      kpaIsNullRooms.value = await getKpaIsNullRooms(); // get null list
    }
  }

  setMeMember(String name) async {
    var me = meMember.value;
    me.name = name;
    meMember.value = me;
  }

  ChatController setRoom(Room newRoom) {
    room = newRoom;
    roomObs.value = newRoom;
    if (newRoom.contact != null) {
      roomContact.value = newRoom.contact!;
    }
    roomObs.refresh();
    return this;
  }

  sortMessageById(List<Message> list) {
    for (int i = 0; i < list.length - 1; i++) {
      Message a = list[i];
      Message b = list[i + 1];
      if (a.createdAt == b.createdAt && b.id > a.id) {
        list[i] = b;
        list[i + 1] = a;
      }
    }
    return list;
  }

  updateMessageStatus(Message message) {
    for (var i = 0; i < messages.length; i++) {
      Message element = messages[i];
      if (element.isMeSend == true && element.id == message.id) {
        messages[i] = message;
        break;
      }
    }
  }

  _handleFileUpload() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'files',
      // extensions: <String>['jpg', 'png'],
    );
    final XFile? xfile =
        await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (xfile == null) {
      return;
    }

    if (file_util.isImageFile(xfile.path)) {
      return _handleSendMediaFile(xfile, MessageMediaType.image, true);
    }

    if (file_util.isVideoFile(xfile.path)) {
      return _handleSendMediaFile(xfile, MessageMediaType.video, false);
    }
    _handleSendMediaFile(xfile, MessageMediaType.file, false);
  }

  Future _handleSendMediaFile(
      XFile xfile, MessageMediaType mediaType, bool compress) async {
    EasyThrottle.throttle('sendMediaFile', const Duration(seconds: 1),
        () async {
      try {
        EasyLoading.showProgress(0.1, status: 'Encrypting and Uploading...');
        await FileUtils.encryptAndSendFile(
            roomObs.value, xfile, mediaType, compress,
            onSendProgress: (count, total) => FileUtils.onSendProgress(
                'Encrypting and Uploading...', count, total));
        hideAdd.value = true; // close features section
        EasyLoading.dismiss();
      } catch (e, s) {
        EasyLoading.dismiss();
        EasyLoading.showError('${Utils.getErrorMessage(e)}',
            duration: const Duration(seconds: 3));
        logger.e('encrypt And SendFile', error: e, stackTrace: s);
      } finally {
        hideAdd.trigger(true);
      }
    });
  }

  _handleSendSats() async {
    CashuInfoModel? cashuInfo =
        await Get.bottomSheet(const CashuSendPage(true));
    if (cashuInfo == null) return;
    try {
      await RoomService().sendTextMessage(room, cashuInfo.token,
          realMessage: cashuInfo.toString(),
          mediaType: MessageMediaType.cashuA);
      hideAdd.value = true; // close features section
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      logger.e(msg, error: e, stackTrace: s);
      EasyLoading.showError(msg);
    }
  }

  _handleSendWithCamera() async {
    PermissionStatus result = await Permission.camera.status;
    if (!result.isGranted) {
      result = await Permission.camera.request();
    }
    if (result.isGranted) {
      await pickAndUploadImage(ImageSource.camera);
      hideAdd.value = true; // close features section
    } else {
      EasyLoading.showToast('Camera permission not grant');
      await Future.delayed(const Duration(milliseconds: 1000), () => {});
      openAppSettings();
    }
  }

  _initRoom(Room room) async {
    if (room.type == RoomType.group) {
      return await _initGroupInfo();
    }
    // private chat
    if (room.type == RoomType.common) {
      if (room.contact == null) {
        Contact contact = await ContactService().getOrCreateContact(
            roomObs.value.identityId, roomObs.value.toMainPubkey);
        roomObs.value.contact = contact;
        roomContact.value = contact;
      } else {
        roomContact.value = room.contact!;
      }
    }

    // bot info
    _initBotInfo();
  }

  _initBotInfo() async {
    if (roomObs.value.type == RoomType.group) return;
    if (roomObs.value.encryptMode == EncryptMode.signal) return;
    NostrEventModel? res = await NostrAPI().fetchMetadata([room.toMainPubkey]);
    if (res == null) return;
    Map<String, dynamic> metadata =
        Map<String, dynamic>.from(jsonDecode(res.content));
    if (room.botInfoUpdatedAt >= res.createdAt) {
      botCommands.value =
          List<Map<String, dynamic>>.from(metadata['commands'] ?? []);
      return;
    }
    // not a bot account
    if (metadata['type'] == null) return;
    if (!metadata['type'].toString().toLowerCase().endsWith('bot')) {
      return;
    }
    room.type = RoomType.bot;
    room.status = RoomStatus.enabled;

    room.botInfoUpdatedAt = res.createdAt;
    botCommands.value =
        List<Map<String, dynamic>>.from(metadata['commands'] ?? []);

    var metadataString = jsonEncode(metadata);
    room.botInfo = metadataString;
    room.name = metadata['name'] ?? room.name;
    room.description = metadata['description'];

    // save config for botPricePerMessageRequest
    if (metadata['botPricePerMessageRequest'] != null) {
      try {
        var config = jsonEncode(metadata['botPricePerMessageRequest']);
        await MessageService()
            .saveSystemMessage(room, config, suffix: '', isMeSend: false);
      } catch (e) {
        logger.e(e.toString(), error: e, stackTrace: StackTrace.current);
      }
    }
    await RoomService().updateRoomAndRefresh(room);
  }

  Future<void> _initGroupInfo() async {
    await resetMembers();
    Identity identity = room.getIdentity();
    RoomMember? rm = await room.getMemberByIdPubkey(identity.secp256k1PKHex);
    meMember.value = rm ??
        RoomMember(
            idPubkey: identity.secp256k1PKHex,
            name: identity.displayName,
            roomId: room.id)
      ..curve25519PkHex = identity.curve25519PkHex;

    // for kdf group
    room.checkAndCleanSignalKeys();
  }
}
