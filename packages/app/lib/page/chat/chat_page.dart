import 'dart:async' show Timer;
import 'dart:convert' show jsonDecode;
import 'dart:math' show Random;

import 'package:app/controller/home.controller.dart';
import 'package:app/page/app_theme.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/chat/message_widget.dart';
import 'package:app/page/common.dart';
import 'package:app/page/components.dart';
import 'package:app/page/theme.dart';
import 'package:app/page/widgets/notice_text_widget.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:app/models/models.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:settings_ui/settings_ui.dart';

import '../../controller/chat.controller.dart';
import '../../service/signal_chat.service.dart';
import '../routes.dart';
import '../widgets/error_text.dart';
import 'chat_setting_contact_page.dart';
import 'chat_setting_group_page.dart';
import '../../service/room.service.dart';

// ignore: must_be_immutable
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPage2State createState() => _ChatPage2State();
}

class _ChatPage2State extends State<ChatPage> {
  late ChatController controller;
  DateTime searchDt = DateTime.now();
  bool isFromSearch = false;

  @override
  void dispose() {
    try {
      Get.delete<ChatController>(tag: controller.room.id.toString());
      // ignore: empty_catches
    } catch (e) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Room room = _getRoomAndInit(context);
    HomeController hc = Get.find<HomeController>();
    Widget myAavtar = getRandomAvatar(room.getIdentity().secp256k1PKHex,
        height: 40, width: 40);
    bool isGroup = room.type == RoomType.group;
    double screenWidth = Get.width;

    Color fontColor = Get.isDarkMode ? Colors.white : Colors.black87;
    Color toBackgroundColor =
        Get.isDarkMode ? const Color(0xFF2c2c2c) : const Color(0xFFFFFFFF);

    //const Color(0xFFF5E2FF).withOpacity(0.8); // for light mode
    Color meBackgroundColor = const Color(0xff7748FF);

    // style for text
    MarkdownStyleSheet myMarkdownStyleSheet =
        MarkdownStyleSheet.fromTheme(AppThemeCustom.dark()).copyWith(
            strong: Theme.of(Get.context!).textTheme.titleSmall?.copyWith(
                fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
            p: Theme.of(Get.context!)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.white, fontSize: 16));

    MarkdownStyleSheet hisMarkdownStyleSheet =
        MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            strong: Theme.of(Get.context!)
                .textTheme
                .titleSmall
                ?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
            p: Theme.of(Get.context!)
                .textTheme
                .bodyLarge
                ?.copyWith(fontSize: 16));

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        elevation: 0.0,
        backgroundColor:
            Get.isDarkMode ? const Color(0xFF000000) : const Color(0xffededed),
        centerTitle: true,
        title: Obx(() => Wrap(
              direction: Axis.horizontal,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _getRoomTite(),
                if (controller.roomObs.value.type == RoomType.bot)
                  const Padding(
                      padding: EdgeInsets.only(left: 5),
                      child: Icon(
                        Icons.android_outlined,
                        color: Colors.purple,
                      ))
              ],
            )),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: Obx(() =>
              controller.roomObs.value.status == RoomStatus.enabled &&
                      controller.roomObs.value.type == RoomType.common &&
                      controller.roomObs.value.encryptMode == EncryptMode.nip04
                  ? const Text('Weak Encrypt Mode')
                  : const SizedBox()),
        ),
        actions: [
          Obx(() => controller.roomObs.value.status != RoomStatus.approving
              ? IconButton(
                  onPressed: goToSetting,
                  icon: const Icon(
                    Icons.more_horiz,
                  ),
                )
              : Container())
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
      floatingActionButton: Obx(() => controller.unreadIndex.value > 1
          ? FilledButton.icon(
              icon: const Icon(Icons.arrow_upward),
              style: ElevatedButton.styleFrom(
                  backgroundColor: MaterialTheme.lightScheme().primary),
              onPressed: () async {
                await controller.autoScrollController.scrollToIndex(
                    controller.unreadIndex.value - 3,
                    preferPosition: AutoScrollPosition.begin);
                controller.autoScrollController
                    .highlight(controller.unreadIndex.value);
                controller.unreadIndex.value = -1;
              },
              label:
                  Text('${controller.unreadIndex.value + 1} Messages Unread'),
            )
          : const SizedBox()),
      body: SafeArea(
          child: GestureDetector(
        onPanUpdate: (details) {
          if (details.delta.dx < -10) {
            goToSetting();
          }
        },
        onTap: () {
          controller.processClickBlank();
        },
        child: Column(
          children: <Widget>[
            Obx(() => debugWidget(hc)),
            if (controller.room.isSendAllGroup)
              Obx(() => _kpaIsNull(controller)),
            Obx(() => controller.roomObs.value.signalDecodeError
                ? MyErrorText(
                    errorText: 'Messages decrypted failed',
                    action: TextButton(
                        child: const Text('Fix it',
                            style: TextStyle(color: Colors.white)),
                        onPressed: () async {
                          await SignalChatService().sendHelloMessage(
                              controller.room, controller.room.getIdentity());
                          EasyLoading.showInfo('Request sent successfully.');
                        }),
                  )
                : const SizedBox()),
            Expanded(
                child: Container(
                    color: Get.isDarkMode
                        ? const Color(0xFF000000)
                        : const Color(0xffededed),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: RefreshIndicator(
                      displacement: 2,
                      onRefresh: controller.loadMoreChatHistory,
                      child: Obx(() => Listener(
                          onPointerMove: (event) {
                            if (event.delta.dy < -10 && isFromSearch) {
                              List<Message> msgs =
                                  controller.loadMoreChatFromSearchSroll();
                              if (msgs.isNotEmpty) {
                                controller.messages
                                    .addAll(controller.sortMessageById(msgs));
                                controller.messages.value =
                                    controller.messages.toSet().toList();
                                controller.messages.sort(((a, b) =>
                                    b.createdAt.compareTo(a.createdAt)));
                              }
                            }
                          },
                          child: ListView.builder(
                            reverse: true,
                            shrinkWrap: true,
                            controller: controller.autoScrollController,
                            itemCount: controller.messages.length,
                            itemBuilder: (BuildContext context, int index) {
                              Message message = controller.messages[index];
                              Contact contact =
                                  controller.getContactByMessage(message);
                              RoomMember? rm;
                              if (controller.room.type == RoomType.group) {
                                rm = controller.getRoomMemberByMessage(message);
                              }

                              return AutoScrollTag(
                                  key: ValueKey(index),
                                  controller: controller.autoScrollController,
                                  index: index,
                                  highlightColor: Theme.of(context)
                                      .colorScheme
                                      .inversePrimary,
                                  child: MessageWidget(
                                    key: ObjectKey('msg:${message.id}'),
                                    myAavtar: myAavtar,
                                    contact: contact,
                                    index: index,
                                    isGroup: isGroup,
                                    roomMember: rm,
                                    chatController: controller,
                                    screenWidth: screenWidth,
                                    toDisplayNameColor: Get.isDarkMode
                                        ? Colors.white54
                                        : Colors.black54,
                                    backgroundColor: message.isMeSend
                                        ? meBackgroundColor
                                        : toBackgroundColor,
                                    fontColor: fontColor,
                                    markdownStyleSheet: message.isMeSend
                                        ? myMarkdownStyleSheet
                                        : hisMarkdownStyleSheet,
                                  ));
                            },
                          ))),
                    ))),
            Obx(() => getSendMessageInput(context, controller))
          ],
        ),
      )),
    );
  }

  getSendMessageInput(BuildContext context, ChatController controller) {
    switch (controller.roomObs.value.status) {
      case RoomStatus.requesting:
        return _requestingInputSection();
      case RoomStatus.approving:
      case RoomStatus.approvingNoResponse:
        return _approvingInputSection();
      case RoomStatus.rejected:
      case RoomStatus.dissolved:
      case RoomStatus.removedFromGroup:
        return _exitInputSection();
      default:
        return SafeArea(
            top: false,
            maintainBottomViewPadding: true,
            child: Column(
              children: [
                _getReplyWidget(),
                Container(
                    padding: EdgeInsets.only(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        top: controller.inputReplys.isNotEmpty ? 0 : 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        if (controller.botCommands.isNotEmpty)
                          botMenuWidget(controller, context),
                        Expanded(
                          child: KeyboardListener(
                            focusNode: controller.keyboardFocus,
                            onKeyEvent: (KeyEvent event) {
                              if (event.runtimeType == KeyDownEvent &&
                                  event.physicalKey ==
                                      PhysicalKeyboardKey.enter) {
                                if (!(HardwareKeyboard
                                        .instance.isControlPressed ||
                                    HardwareKeyboard.instance.isShiftPressed ||
                                    HardwareKeyboard.instance.isAltPressed)) {
                                  controller.handleSubmitted();
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(4.0),
                                ),
                                color: Get.isDarkMode
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade100,
                              ),
                              child: TextFormField(
                                controller: controller.textEditingController,
                                keyboardType: TextInputType.multiline,
                                focusNode: controller.chatContentFocus,
                                autofocus: GetPlatform.isDesktop,
                                decoration: const InputDecoration(
                                    isCollapsed: true,
                                    hintText: 'Message',
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.all(0)),
                                textInputAction: TextInputAction.send,
                                onEditingComplete: controller.handleSubmitted,
                                maxLines: 8,
                                minLines: 1,
                                scrollController:
                                    controller.textFieldScrollController,
                                textAlign: TextAlign.left,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(fontSize: 16),
                                cursorColor: Colors.green,
                                onTap: () {
                                  controller.hideEmoji.value = true;
                                  controller.hideAdd.value = true;
                                },
                                onChanged: handleOnChanged,
                                onFieldSubmitted: (c) {
                                  controller.handleSubmitted();
                                },
                                enabled: true,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 10, bottom: 5),
                          child: GestureDetector(
                              onTap: handleMessageSend,
                              child: controller.inputText.value.isNotEmpty
                                  ? const Icon(
                                      weight: 300,
                                      size: 28,
                                      CupertinoIcons.arrow_up_circle_fill,
                                      color: Color.fromARGB(255, 100, 80, 243))
                                  : Icon(
                                      size: 28,
                                      CupertinoIcons.add_circled,
                                      weight: 300,
                                      color: Theme.of(context)
                                          .iconTheme
                                          .color
                                          ?.withAlpha(155),
                                    )),
                        ),
                      ],
                    )),
                Visibility(
                  visible: !controller.hideAdd.value,
                  child: AnimatedOpacity(
                    opacity: !controller.hideAdd.value ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: AnimatedContainer(
                      height: !controller.hideAdd.value
                          ? controller.featuresIcons.length > 4
                              ? 220.0
                              : 100
                          : 0.0,
                      duration: const Duration(milliseconds: 500),
                      child: getFeaturesWidget(context),
                    ),
                  ),
                )
              ],
            ));
    }
  }

  Padding botMenuWidget(ChatController controller, BuildContext context) {
    return Padding(
        padding: const EdgeInsets.only(left: 0, right: 5, bottom: 5),
        child: GestureDetector(
            onTap: () {
              Map localConfig =
                  jsonDecode(controller.roomObs.value.botLocalConfig ?? '{}');
              Map? botPricePerMessageRequest =
                  localConfig['botPricePerMessageRequest'];
              Get.bottomSheet(
                  SettingsList(platform: DevicePlatform.iOS, sections: [
                SettingsSection(
                    title: const Text('Commands'),
                    tiles: controller.botCommands
                        .map(
                          (element) => SettingsTile(
                              title: Text(element['name']),
                              value: Flexible(
                                  child: textSmallGray(
                                      context, element['description'],
                                      overflow: TextOverflow.clip)),
                              onPressed: (context) async {
                                RoomService().sendTextMessage(
                                    controller.roomObs.value, element['name']);
                                Get.back();
                              }),
                        )
                        .toList()),
                if (botPricePerMessageRequest != null)
                  SettingsSection(
                    title: const Text('Selected Local Config'),
                    tiles: [
                      SettingsTile(
                          title: Text(botPricePerMessageRequest['name']),
                          trailing: Text(
                              '${botPricePerMessageRequest['price']} ${botPricePerMessageRequest['unit']} /message'),
                          onPressed: (context) async {
                            Get.back();
                          })
                    ],
                  )
              ]));
            },
            child: Icon(
              size: 26,
              Icons.menu,
              weight: 300,
              color: Theme.of(context).iconTheme.color?.withAlpha(155),
            )));
  }

  Widget getFeaturesWidget(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
      ),
      itemCount: controller.featuresIcons.length,
      itemBuilder: (context, index) {
        return GestureDetector(
            onTap: () {
              controller.featuresOnTaps[index]();
            },
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  child: Icon(
                    controller.featuresIcons[index],
                    size: 32.0,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(controller.featuresTitles[index])
              ],
            ));
      },
    );
  }

  handleMessageSend() async {
    if (controller.textEditingController.text.isEmpty) {
      if (controller.roomObs.value.type == RoomType.bot) {
        EasyLoading.showToast('Not supported int bot chat now');
        return;
      }
      controller.hideAdd.trigger(false);
      controller.chatContentFocus.unfocus();
      return;
    }
    await controller.handleSubmitted();
  }

  Future goToSetting() async {
    if (controller.roomObs.value.type == RoomType.group) {
      await Get.to(() => GroupChatSettingPage(
          room: controller.roomObs.value, chatController: controller));
    } else {
      await Get.to(() => ShowContactDetail(
          contact: controller.roomContact.value,
          room: controller.roomObs.value,
          chatController: controller));
    }
    await controller.openPageAction();
    return;
  }

  Widget debugWidget(HomeController hc) {
    return Visibility(
        visible: hc.debugModel.value,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.center,
              runSpacing: 10,
              spacing: 10,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('send: ${controller.statsSend}'),
                    Text('receive: ${controller.statsReceive}'),
                  ],
                ),
                Visibility(
                    visible: !hc.debugSendMessageRunning.value,
                    child: FilledButton(
                        onPressed: () {
                          EasyLoading.showSuccess(
                              'Random to send message task starting',
                              duration: const Duration(seconds: 5));
                          hc.debugSendMessageRunning.value = true;
                          int count = 0;
                          void randomTimer() {
                            if (!hc.debugSendMessageRunning.value) {
                              return;
                            }

                            final random = Random();
                            final seconds = random.nextInt(10) + 1;

                            Timer(Duration(seconds: seconds), () {
                              count++;
                              controller.getRoomStats();
                              RoomService().sendTextMessage(
                                  controller.room, count.toString());
                              randomTimer();
                            });
                          }

                          randomTimer();
                        },
                        child: const Text('Start'))),
                Visibility(
                    visible: hc.debugSendMessageRunning.value,
                    child: FilledButton(
                        onPressed: () {
                          hc.debugSendMessageRunning.value = false;
                        },
                        child: const Text('Stop '))),
                OutlinedButton(
                    onPressed: () {
                      MessageService()
                          .deleteMessageByRoomId(controller.room.id);
                      Get.back();
                    },
                    child: const Text('clean')),
                OutlinedButton(
                    onPressed: () {
                      controller.getRoomStats();
                    },
                    child: const Text('stats'))
              ],
            )));
  }

  Widget _getReplyWidget() {
    if (controller.inputReplys.isEmpty) return const SizedBox();
    return Visibility(
        visible: controller.inputReplys.isNotEmpty,
        child: ListTile(
          dense: true,
          leading: Icon(
            CupertinoIcons.reply,
            color: Colors.blue.shade700,
          ),
          title: Text(
            'Reply to: ${controller.inputReplys.first.fromContact!.name}',
            style: Theme.of(Get.context!)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.blue.shade700, height: 1),
          ),
          subtitle: RoomUtil.getRelaySubtitle(controller.inputReplys.first),
          trailing: IconButton(
              onPressed: () {
                controller.inputReplys.clear();
                controller.inputReplys.refresh();
              },
              icon: Icon(
                Icons.close,
                color: Colors.blue.shade700,
              )),
        ));
  }

  void handleOnChanged(String value) async {
    if (value.isEmpty) {
      if (!controller.hideSend.value) {
        controller.hideSend.value = true;
        controller.hideAddIcon.value = false;
      }
      return;
    }

    if (controller.hideSend.value) {
      controller.hideSend.value = false;
      controller.hideAddIcon.value = true;
    }
    if (controller.room.type == RoomType.group) {
      String lastChar = value.substring(value.length - 1, value.length);
      if (lastChar == '@' && controller.inputTextIsAdd.value) {
        RoomMember? roomMember = await Get.bottomSheet(Scaffold(
            appBar: AppBar(
              leading: Container(),
              title: const Text('Select member to alert'),
            ),
            body: ListView.separated(
                controller: ScrollController(),
                separatorBuilder: (BuildContext context, int index) => Divider(
                    color: Theme.of(context)
                        .dividerTheme
                        .color
                        ?.withOpacity(0.05)),
                itemCount: controller.enableMembers.length,
                itemBuilder: (context, index) {
                  RoomMember rm = controller.enableMembers[index];
                  return ListTile(
                      onTap: () {
                        Get.back(result: controller.enableMembers[index]);
                      },
                      leading:
                          getRandomAvatar(rm.idPubkey, height: 36, width: 36),
                      title: Text(
                        rm.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                        ),
                      ));
                })));
        if (roomMember != null) {
          controller.addMetionName(roomMember.name);
          controller.chatContentFocus.requestFocus();
          // FocusScope.of(Get.context!).requestFocus(controller.chatContentFocus);
        }
      }
    }
  }

  Widget _getRoomTite() {
    String? title = controller.roomObs.value.name;
    if (controller.roomObs.value.type == RoomType.common) {
      title = controller.roomContact.value.displayName;
    }
    if (controller.roomObs.value.type == RoomType.group) {
      title =
          '${controller.roomObs.value.name} (${controller.enableMembers.length})';
    }

    return Wrap(
      direction: Axis.horizontal,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(title ?? controller.roomObs.value.getRoomName()),
        if (controller.roomObs.value.isMute)
          Icon(
            Icons.notifications_off_outlined,
            color:
                Theme.of(Get.context!).colorScheme.onSurface.withOpacity(0.6),
            size: 18,
          )
      ],
    );
  }

  Widget _inputSectionContainer(Widget child) {
    return SafeArea(
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20), child: child));
  }

  Widget _exitInputSection() {
    return _inputSectionContainer(FilledButton(
      style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.red)),
      onPressed: () async {
        await RoomService().deleteRoom(controller.roomObs.value);
        await Get.find<HomeController>()
            .loadIdentityRoomList(controller.room.identityId);
        await Get.offAllNamed(Routes.root);
      },
      child: const Text(
        'Exit and Delete Room',
        style: TextStyle(color: Colors.white),
      ),
    ));
  }

  Widget _approvingInputSection() {
    return _inputSectionContainer(Wrap(
      direction: Axis.vertical,
      runAlignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      children: [
        const Text('Request to start secure chatting.'),
        Wrap(
          runSpacing: 10,
          spacing: 30,
          children: [
            FilledButton(
              onPressed: () async {
                try {
                  Room room = controller.roomObs.value;
                  if (room.status == RoomStatus.approving) {
                    String displayName = room.getIdentity().displayName;
                    await SignalChatService().sendMessage(
                        room, RoomUtil.getHelloMessage(displayName));
                    room.status = RoomStatus.enabled;
                    await RoomService().updateRoom(room);
                    controller.setRoom(room);
                  }
                } catch (e, s) {
                  EasyLoading.showError(e.toString());
                  logger.e(e.toString(), error: e, stackTrace: s);
                }
                Get.find<HomeController>()
                    .loadIdentityRoomList(controller.room.identityId);
              },
              style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.green)),
              child: const Text('Approve'),
            ),
            FilledButton(
              onPressed: () async {
                int identityId = controller.room.identityId;
                await SignalChatService()
                    .sendRejectMessage(controller.roomObs.value);
                await RoomService().deleteRoom(controller.roomObs.value);
                Get.find<HomeController>().loadIdentityRoomList(identityId);
                Get.back();
              },
              style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.red)),
              child: const Text('Reject'),
            ),
          ],
        )
      ],
    ));
  }

  Widget _requestingInputSection() {
    return _inputSectionContainer(Wrap(
      runSpacing: 10,
      spacing: 30,
      children: [
        FilledButton(
          onPressed: () async {
            Get.dialog(CupertinoAlertDialog(
              title: const Text('Waiting Approve'),
              content: const Text(
                  'Invitation has been sent, waiting for the his/her approval'),
              actions: <Widget>[
                CupertinoDialogAction(
                  onPressed: () {
                    Get.back();
                  },
                  child: const Text('OK'),
                ),
                CupertinoDialogAction(
                  onPressed: () async {
                    await RoomService().createRoomAndsendInvite(
                        controller.room.toMainPubkey,
                        autoJump: false);
                    Get.back();
                  },
                  child: const Text('Resend'),
                ),
              ],
            ));
          },
          style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.green)),
          child: const Text('Requesting'),
        ),
        OutlinedButton(
          onPressed: () async {
            Get.dialog(CupertinoAlertDialog(
              title: const Text('Cancel Invitation'),
              content: const Text('Are you sure to cancel this requesting?'),
              actions: <Widget>[
                CupertinoDialogAction(
                  onPressed: () {
                    Get.back();
                  },
                  child: const Text('Close'),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () async {
                    Get.back();
                    int id = controller.roomObs.value.identityId;
                    await RoomService().deleteRoom(controller.roomObs.value);
                    await Get.find<HomeController>().loadIdentityRoomList(id);
                    Get.back();
                  },
                  child: const Text('Cancel Invitation'),
                ),
              ],
            ));
          },
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: () async {
            controller.roomObs.value.status = RoomStatus.enabled;
            await RoomService().updateRoom(controller.roomObs.value);
            await RoomService().updateChatRoomPage(controller.roomObs.value);
            await Get.find<HomeController>()
                .loadIdentityRoomList(controller.room.identityId);
          },
          child: const Text('Start Chat with Nostr Client'),
        ),
      ],
    ));
  }

  Room _getRoomAndInit(BuildContext context) {
    int roomId = int.parse(Get.parameters['id']!);
    Room? room;
    if (Get.arguments == null) {
      room = RoomService().getRoomByIdSync(roomId);
    } else {
      // room = Get.arguments as Room;
      try {
        Map<String, dynamic> arguments = Get.arguments;
        room = arguments['room'];
        isFromSearch = arguments['isFromSearch'];
        searchDt = arguments['searchDt'];
      } catch (e) {
        // only one arguments, not in Json format
        room = Get.arguments as Room;
      }
    }
    controller = Get.put(ChatController(room!), tag: roomId.toString());
    controller.context = context;
    if (isFromSearch) {
      controller.searchMsgIndex.value = 1;
      controller.searchDt.value = searchDt;
    }
    return room;
  }

  Widget _kpaIsNull(ChatController controller) {
    if (controller.kpaIsNullRooms.isEmpty) {
      return const SizedBox();
    }
    return ListTile(
      leading: const Icon(Icons.warning, color: Colors.yellow),
      title: Text('NotContacts: ${controller.kpaIsNullRooms.length}'),
      subtitle:
          const Text('You are not friends, cannot send and receive messages'),
      trailing: FilledButton(
          onPressed: () {
            showModalBottomSheetWidget(
                Get.context!,
                'Add Contacts',
                Column(
                    // padding: const EdgeInsets.symmetric(horizontal: 10),
                    // color: Theme.of(Get.context!).colorScheme.background,
                    children: [
                      NoticeTextWidget.warning(
                          'You are not friends, cannot send and receive messages'),
                      const SizedBox(height: 16),
                      Expanded(
                          child: Obx(() => ListView.separated(
                              physics: const NeverScrollableScrollPhysics(),
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 4),
                              shrinkWrap: true,
                              itemCount: controller.kpaIsNullRooms.length,
                              itemBuilder: (context, index) {
                                Room room = controller.kpaIsNullRooms[index];
                                room.contact ??= ContactService()
                                    .getOrCreateContactSync(
                                        room.identityId, room.toMainPubkey);
                                return ListTile(
                                  leading: getAvatarDot(room, width: 40),
                                  key: Key('room:${room.id}'),
                                  title: Text(room.getRoomName()),
                                  trailing: OutlinedButton(
                                      onPressed: () async {
                                        Room? room0 = await RoomService()
                                            .createRoomAndsendInvite(
                                                room.toMainPubkey,
                                                autoJump: false,
                                                greeting:
                                                    'From group: ${controller.roomObs.value.getRoomName()}');
                                        if (room0 != null) {
                                          controller.kpaIsNullRooms[index] =
                                              room0;
                                          controller.kpaIsNullRooms.refresh();
                                        }
                                      },
                                      child: Text(
                                          room.status == RoomStatus.requesting
                                              ? 'Requesting'
                                              : 'Send')),
                                );
                              })))
                    ]));
          },
          child: const Text('View')),
    );
  }
}
