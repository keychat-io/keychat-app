import 'dart:async' show Future, Timer;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Directory, File, FileSystemEntity;

import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/chat/RoomDraft.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/file.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar/isar.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:mime/mime.dart' show extensionFromMime;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:super_clipboard/super_clipboard.dart';

const int maxMessageId = 999999999999;

String newlineChar = String.fromCharCode(13);

class ChatController extends GetxController {
  RxList<Message> messages = <Message>[].obs;
  List<Message> messagesMore = <Message>[];
  RxList<Message> inputReplys = <Message>[].obs;
  RxString inputText = ''.obs;
  RxBool inputTextIsAdd = true.obs;
  RxInt messageLimit = 0.obs;

  final roomObs = Room(identityId: 0, toMainPubkey: '', npub: '').obs;

  RxInt statsSend = 0.obs;
  RxInt statsReceive = 0.obs;
  RxInt unreadIndex = (-1).obs;
  RxList<Room> kpaIsNullRooms = <Room>[].obs; // for signal group chat
  int searchMsgIndex = -1;
  DateTime searchDt = DateTime.now();
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

  // private chat
  Rx<Contact> roomContact = Contact(pubkey: '', npubkey: '', identityId: 0).obs;

  // group chat
  RxMap<String, RoomMember> members = <String, RoomMember>{}.obs;
  RxMap<String, RoomMember> enableMembers = <String, RoomMember>{}.obs;

  Map<String, Room> memberRooms = {}; // sendToAllGroup: rooms for each member

  // bot commands
  RxList<Map<String, dynamic>> botCommands = <Map<String, dynamic>>[].obs;

  late TextEditingController textEditingController;

  late FocusNode chatContentFocus;
  late FocusNode keyboardFocus;
  late AutoScrollController autoScrollController;
  late ScrollController textFieldScrollController;
  late RefreshController _refreshController;
  DateTime lastMessageAddedAt = DateTime.now();

  final List<String> featuresIcons = [
    'assets/images/photo.png',
    'assets/images/camera.png',
    'assets/images/video.png',
    'assets/images/file.png',
    'assets/images/BTC.png',
  ];

  //image video camera-image  camera-video file satos
  final List<String> featuresTitles = [
    'Album',
    'Camera',
    'Video',
    'File',
    'Sat'
  ];

  List<Function> featuresOnTaps = [];

  ChatController(Room room) {
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
    lastMessageAddedAt = DateTime.now();

    if (!autoScrollController.hasClients) {
      messages.insert(index, message);
      jumpToBottom(100);
      return;
    }
    try {
      if (autoScrollController.position.pixels <= 300) {
        messages.insert(index, message);
        jumpToBottom(100);
        return;
      }
      // ignore: empty_catches
    } catch (e, s) {
      logger.e(e.toString(), stackTrace: s);
    }
    messagesMore.add(message);
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

  Future<void> deleteMessage(Message message) async {
    await MessageService.instance.deleteMessageById(message.id);
    messages.remove(message);
  }

  emoticonClick(String name) {
    textEditingController.text = name;
  }

  RoomMember? getMemberByIdPubkey(String idPubkey) {
    return members[idPubkey];
  }

  Future<List<File>> getImageList(Directory directory) async {
    List<FileSystemEntity> files = directory.listSync(recursive: true);
    List<File> imageFiles = [];
    for (var file in files) {
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
    List<Room> rooms = [];
    if (!roomObs.value.isSendAllGroup) return rooms;
    ChatxService cs = Get.find<ChatxService>();

    for (var element in memberRooms.values) {
      var kpa = await cs.getRoomKPA(element);
      if (kpa == null) {
        rooms.add(element);
      }
    }
    return rooms;
  }

  getRoomStats() async {
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

  Future handleSubmitted() async {
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return;
    }

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
        HapticFeedback.lightImpact();
      }
      await RoomService.instance.sendMessage(roomObs.value, text, reply: reply);
      inputReplys.clear();
      hideAddIcon.value = false;
      // hideSend.value = true;
      inputText.value = '';
      inputTextIsAdd.value = true;
      RoomService.instance.markAllReadSimple(roomObs.value);
    } catch (e, s) {
      textEditingController.text = text;
      String msg = Utils.getErrorMessage(e);
      logger.e('Failed: $msg', error: e, stackTrace: s);
      EasyLoading.showError(msg, duration: const Duration(seconds: 3));
    }
  }

  bool _refreshInitialized = false;
  RefreshController getRefreshController() {
    if (!_refreshInitialized) {
      _refreshController = RefreshController(initialRefresh: false);
      _refreshInitialized = true;
    }
    return _refreshController;
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

  Future loadAllChat() async {
    List<Message> list = await MessageService.instance.getMessagesByView(
        roomId: roomObs.value.id,
        maxId: maxMessageId,
        isRead: true,
        limit: messageLimitPerPage);
    List<Message> unreads = await MessageService.instance.getMessagesByView(
        roomId: roomObs.value.id,
        maxId: maxMessageId,
        isRead: false,
        limit: 200);
    if (unreads.isNotEmpty) {
      if (unreads.length > 12) {
        unreadIndex.value = unreads.length - 1;
      }
      RoomService.instance.markAllRead(
          identityId: roomObs.value.identityId, roomId: roomObs.value.id);
    }
    unreads.addAll(list);
    messages.value = sortMessageById(unreads.toList());
    messages.sort(((a, b) => b.createdAt.compareTo(a.createdAt)));
    messages.value = List.from(messages);
  }

  loadAllChatFromSearchScroll() {
    messages.clear();
    DateTime from = searchDt;
    var list = MessageService.instance.listMessageBySearchSroll(
        roomId: roomObs.value.id, from: from, limit: 7);
    messages.addAll(sortMessageById(list));
    messages.sort(((a, b) => b.createdAt.compareTo(a.createdAt)));
    messages.value = List.from(messages);
  }

  loadLatestMessage() async {
    late DateTime from;
    if (messages.isEmpty) {
      from = DateTime.now();
    } else {
      from = messages.first.createdAt;
    }
    List<Message> list = await MessageService.instance
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
    Message? message = MessageService.instance.listLastestMessage(
      roomId: roomObs.value.id,
    );
    if (message != null && message.createdAt == from) {
      return [];
    }
    var list = MessageService.instance.listMessageByTimeSync(
        roomId: roomObs.value.id, from: from, limit: messageLimitPerPage);
    return list;
  }

  Future loadMoreChatHistory() async {
    if (messages.isEmpty) {
      getRefreshController().loadComplete();
      return;
    }

    // Load more messages
    DateTime from = messages.last.createdAt;
    var sortedNewMessages = await MessageService.instance.listMessageByTime(
        roomId: roomObs.value.id, from: from, limit: messageLimitPerPage);

    if (sortedNewMessages.isEmpty) {
      getRefreshController().loadComplete();
      return; // No new messages to load
    }

    sortedNewMessages.sort(((a, b) => b.createdAt.compareTo(a.createdAt)));
    messages.addAll(sortedNewMessages);
    getRefreshController().loadComplete();
    messages.value = List.from(messages);
  }

  @override
  void onClose() {
    getRefreshController().dispose();
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
    getRefreshController();
    if (GetPlatform.isDesktop) {
      chatContentFocus.requestFocus();
      messageLimitPerPage = 100;
    }

    textFieldScrollController = ScrollController();
    textEditingController = TextEditingController();
    autoScrollController = AutoScrollController(axis: Axis.vertical);

    autoScrollController.addListener(() {
      EasyDebounce.debounce(
          'autoScrollController.addListener', Duration(milliseconds: 200), () {
        bool isCurrent = DBProvider.instance.isCurrentPage(roomObs.value.id);
        if (!isCurrent) {
          messagesMore.clear();
          searchMsgIndex = -1;
        }
        if (messagesMore.isNotEmpty &&
            autoScrollController.position.pixels <= 100) {
          messages.addAll(sortMessageById(messagesMore));
          messages.sort(((a, b) => b.createdAt.compareTo(a.createdAt)));
          messages.value = List.from(messages);

          messagesMore.clear();
        }
      });
    });

    // load draft
    String? textFiledDraft = RoomDraft.instance.getDraft(roomObs.value.id);
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
      RoomDraft.instance.setDraft(roomObs.value.id, newText);
    });
    await _initRoom();
    await loadAllChat();

    if (searchMsgIndex > 0) {
      loadAllChatFromSearchScroll();
    }
    initChatPageFeatures();
    super.onInit();
  }

  @override
  onReady() {
    // jump to bottom after 200ms
    Future.delayed(const Duration(milliseconds: 200), () {
      Timer(const Duration(milliseconds: 300), () {
        if (autoScrollController.positions.isNotEmpty &&
            autoScrollController.hasClients) {
          autoScrollController.jumpTo(0.0);
        }
      });
    });
  }

  openPageAction() async {
    await loadLatestMessage();
    RoomService.instance.markAllRead(
        identityId: roomObs.value.identityId, roomId: roomObs.value.id);
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
        child: FileService.instance.getImageView(File(xfile.path)),
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
            await handleSendMediaFile(xfile!, MessageMediaType.image, true);
            Get.back();
          },
          child: const Text('Send'),
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
      EasyLoading.showProgress(0.2, status: 'Encrypting and Uploading...');
      await FileService.instance.encryptAndSendFile(
          roomObs.value, xfile, MessageMediaType.video,
          compress: true,
          onSendProgress: (count, total) => FileService.instance
              .onSendProgress('Encrypting and Uploading...', count, total));
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
    if (roomObs.value.isMLSGroup) {
      var list = await MlsGroupService.instance.getMembers(roomObs.value);
      enableMembers.value = list;
      members.value = list;
      String? admin = await roomObs.value.getAdmin();
      if (admin != null) {
        members[admin]!.isAdmin = true;
        enableMembers[admin]!.isAdmin = true;
      }
      return;
    }
    if (roomObs.value.isSendAllGroup) {
      members.value = await roomObs.value.getMembers();
      enableMembers.value = await roomObs.value.getEnableMembers();
      memberRooms = await roomObs.value.getEnableMemberRooms();
      kpaIsNullRooms.value = await getKpaIsNullRooms(); // get null list
    }
  }

  ChatController setRoom(Room newRoom) {
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

  _handleFileUpload() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null) return;
    XFile xfile = result.files.first.xFile;

    if (FileService.instance.isImageFile(xfile.path)) {
      return handleSendMediaFile(xfile, MessageMediaType.image, true);
    }

    if (FileService.instance.isVideoFile(xfile.path)) {
      return handleSendMediaFile(xfile, MessageMediaType.video, true);
    }
    handleSendMediaFile(xfile, MessageMediaType.file, false);
  }

  Future handleSendMediaFile(
      XFile xfile, MessageMediaType mediaType, bool compress) async {
    EasyThrottle.throttle('sendMediaFile', const Duration(seconds: 1),
        () async {
      try {
        String statusMessage = mediaType != MessageMediaType.image
            ? 'Encrypting and Uploading...'
            : '''1. Remove EXIF info
2. Encrypting 
3. Uploading''';
        EasyLoading.showProgress(0.0, status: statusMessage);
        EasyLoading.showProgress(0.2, status: statusMessage);
        await FileService.instance.encryptAndSendFile(
            roomObs.value, xfile, mediaType,
            compress: compress,
            onSendProgress: (count, total) => FileService.instance
                .onSendProgress(statusMessage, count, total));
        hideAdd.value = true; // close features section
        EasyLoading.dismiss();
      } catch (e, s) {
        EasyLoading.dismiss();
        EasyLoading.showError(Utils.getErrorMessage(e),
            duration: const Duration(seconds: 3));
        logger.e('encrypt And SendFile', error: e, stackTrace: s);
      } finally {
        hideAdd.trigger(true);
      }
    });
  }

  _handleSendSats() async {
    CashuInfoModel? cashuInfo = await Get.bottomSheet(
        clipBehavior: Clip.hardEdge,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
        const CashuSendPage(true));
    if (cashuInfo == null) return;
    try {
      await RoomService.instance.sendMessage(roomObs.value, cashuInfo.token,
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
    if (GetPlatform.isMacOS) {
      EasyLoading.showToast('Camera not supported on MacOS');
      return;
    }
    bool isGranted = true;
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

  _initBotInfo() async {
    List list =
        await NostrAPI.instance.fetchMetadata([roomObs.value.toMainPubkey]);
    if (list.isEmpty) return;
    NostrEventModel res = list.last;
    Map<String, dynamic> metadata =
        Map<String, dynamic>.from(jsonDecode(res.content));
    if (roomObs.value.botInfoUpdatedAt >= res.createdAt) {
      botCommands.value =
          List<Map<String, dynamic>>.from(metadata['commands'] ?? []);
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
    botCommands.value =
        List<Map<String, dynamic>>.from(metadata['commands'] ?? []);

    var metadataString = jsonEncode(metadata);
    roomObs.value.botInfo = metadataString;
    roomObs.value.name = metadata['name'] ?? roomObs.value.name;
    roomObs.value.description = metadata['description'];

    // save config for botPricePerMessageRequest
    if (metadata['botPricePerMessageRequest'] != null) {
      try {
        var config = jsonEncode(metadata['botPricePerMessageRequest']);
        await MessageService.instance.saveSystemMessage(roomObs.value, config,
            suffix: '', isMeSend: false);
      } catch (e) {
        logger.e('botPricePerMessageRequest: ${e.toString()}',
            error: e, stackTrace: StackTrace.current);
      }
    }
    await RoomService.instance.updateRoomAndRefresh(roomObs.value);
  }

  _initRoom() async {
    // group
    if (roomObs.value.type == RoomType.group) {
      return await resetMembers();
    }
    // private chat
    if (roomObs.value.type == RoomType.common) {
      if (roomObs.value.contact == null) {
        Contact contact = await ContactService.instance.getOrCreateContact(
            roomObs.value.identityId, roomObs.value.toMainPubkey);
        roomObs.value.contact = contact;
        roomContact.value = contact;
      } else {
        roomContact.value = roomObs.value.contact!;
      }
    }
    if (roomObs.value.type == RoomType.bot) {
      _initBotInfo();
    }
  }

  Future handlePasteboard() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return; // Clipboard API is not supported on this platform.
    }
    final reader = await clipboard.read();
    if (reader.items.isEmpty) {
      return;
    }

    final imageFormats = [
      (Formats.png, MessageMediaType.image, true),
      (Formats.jpeg, MessageMediaType.image, true),
      (Formats.webp, MessageMediaType.image, true),
      (Formats.gif, MessageMediaType.image, false),
      (Formats.mp4, MessageMediaType.video, true),
      (Formats.pdf, MessageMediaType.file, false),
      (Formats.svg, MessageMediaType.image, false),
      (Formats.webp, MessageMediaType.image, false),
      (Formats.tiff, MessageMediaType.image, false),
      (Formats.bmp, MessageMediaType.image, false),
      (Formats.ico, MessageMediaType.image, false),
      (Formats.heic, MessageMediaType.image, false),
      (Formats.heif, MessageMediaType.image, false),
      (Formats.mov, MessageMediaType.video, false),
      (Formats.m4v, MessageMediaType.video, false),
      (Formats.avi, MessageMediaType.video, false),
      (Formats.mpeg, MessageMediaType.video, false),
      (Formats.webm, MessageMediaType.video, false),
      (Formats.ogg, MessageMediaType.video, false),
      (Formats.wmv, MessageMediaType.video, false),
      (Formats.flv, MessageMediaType.video, false),
      (Formats.mkv, MessageMediaType.video, false),
      (Formats.mp3, MessageMediaType.file, false),
      (Formats.oga, MessageMediaType.file, false),
      (Formats.aac, MessageMediaType.file, false),
      (Formats.wav, MessageMediaType.file, false),
      (Formats.doc, MessageMediaType.file, false),
      (Formats.docx, MessageMediaType.file, false),
      (Formats.csv, MessageMediaType.file, false),
      (Formats.xls, MessageMediaType.file, false),
      (Formats.xlsx, MessageMediaType.file, false),
      (Formats.ppt, MessageMediaType.file, false),
      (Formats.pptx, MessageMediaType.file, false),
      (Formats.json, MessageMediaType.file, false),
      (Formats.zip, MessageMediaType.file, false),
      (Formats.tar, MessageMediaType.file, false),
      (Formats.gzip, MessageMediaType.file, false),
      (Formats.bzip2, MessageMediaType.file, false),
      (Formats.rar, MessageMediaType.file, false),
      (Formats.dmg, MessageMediaType.file, false),
      (Formats.iso, MessageMediaType.file, false),
      (Formats.deb, MessageMediaType.file, false),
      (Formats.rpm, MessageMediaType.file, false),
      (Formats.apk, MessageMediaType.file, false),
      (Formats.exe, MessageMediaType.file, false),
      (Formats.msi, MessageMediaType.file, false),
      (Formats.plainTextFile, MessageMediaType.file, false),
      (Formats.htmlFile, MessageMediaType.file, false),
      (Formats.webUnknown, MessageMediaType.file, false),
    ];
    if (reader.canProvide(Formats.fileUri)) {
      for (int i = 0; i < imageFormats.length; i++) {
        final format = imageFormats[i].$1;
        final mediaType = imageFormats[i].$2;
        final compress = imageFormats[i].$3;
        bool canProcess = reader.canProvide(format);
        if (canProcess) {
          logger.d('Clipboard can provide: $format');
          await _readFromStream(reader, format, mediaType, compress);
          return;
        }
      }
    }
    if (reader.canProvide(Formats.plainText)) {
      String? text = await reader.readValue(Formats.plainText);
      if (text != null && text.isNotEmpty) {
        String currentText = textEditingController.text;
        TextSelection selection = textEditingController.selection;

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
          int cursorPosition = selection.baseOffset;

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
        textEditingController.selection = TextSelection.fromPosition(
          TextPosition(offset: newCursorPosition),
        );
        return;
      }
      return;
    }

    // fallback
    for (int i = 0; i < imageFormats.length; i++) {
      final format = imageFormats[i].$1;
      final mediaType = imageFormats[i].$2;
      final compress = imageFormats[i].$3;
      bool canProcess = reader.canProvide(format);
      if (canProcess) {
        logger.d('Clipboard can provide: $format');
        await _readFromStream(reader, format, mediaType, compress);
        return;
      }
    }
    EasyLoading.showToast('Not supported media type');
  }

  Future _readFromStream(
      ClipboardReader reader, SimpleFileFormat format, MessageMediaType type,
      [bool compress = true]) async {
    /// Binary formats need to be read as streams
    reader.getFile(format, (DataReaderFile file) async {
      String? suggestedName = await reader.getSuggestedName();
      String? mimeType = format.mimeTypes?.first;

      try {
        Uint8List imageBytes = await file.readAll();
        String sourceFileName = textEditingController.text.trim();
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        if (suggestedName == null) {
          String? suffix;
          if (mimeType != null) {
            suffix = extensionFromMime(mimeType);
          }
          if (sourceFileName.isNotEmpty && sourceFileName.contains('.')) {
            String inputName = sourceFileName.split('.').first;
            String inputSuffix = sourceFileName.split('.').last;
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

        XFile xfile = XFile(path,
            bytes: imageBytes, mimeType: mimeType, name: suggestedName);
        bool isImage = FileService.instance.isImageFile(xfile.path);
        if (isImage) {
          bool? comfirmResult = await Get.dialog(CupertinoAlertDialog(
            content: SizedBox(
              width: 300,
              child: FileService.instance.getImageView(File(xfile.path)),
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
                  await handleSendMediaFile(
                      xfile, MessageMediaType.image, true);
                  Get.back(result: true);
                },
                child: const Text('Send'),
              ),
            ],
          ));
          if (comfirmResult == null || !comfirmResult) {
            return; // user cancelled
          }
        }
        await handleSendMediaFile(xfile, type, compress);
      } catch (e, s) {
        logger.e('_readFromStream: ${e.toString()}', stackTrace: s);
      } finally {
        await Future.delayed(Duration(seconds: 2));
        EasyLoading.dismiss();
      }
    });
  }
}
