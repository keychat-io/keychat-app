import 'dart:async' show Timer;
import 'dart:convert' show jsonDecode;
import 'dart:math' show Random, min;

import 'package:app/app.dart';
import 'package:app/controller/chat.controller.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/chat/message_widget.dart';
import 'package:app/page/components.dart';
import 'package:app/page/routes.dart';
import 'package:app/page/widgets/error_text.dart';
import 'package:app/page/widgets/notice_text_widget.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/signal_chat.service.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:get/get.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:settings_ui/settings_ui.dart';

class ChatPage extends StatefulWidget {
  final Room? room;
  const ChatPage({this.room, super.key});

  @override
  _ChatPage2State createState() => _ChatPage2State();
}

class _ChatPage2State extends State<ChatPage> {
  late ChatController controller;
  HomeController hc = Get.find<HomeController>();

  late Widget myAavtar;
  bool isGroup = false;
  late MarkdownConfig markdownDarkConfig;
  late MarkdownConfig markdownLightConfig;
  bool isSendGreeting = false;

  @override
  void initState() {
    Room room = _getRoomAndInit(context);
    myAavtar = Utils.getRandomAvatar(room.getIdentity().secp256k1PKHex,
        httpAvatar: room.getIdentity().avatarFromRelay, height: 40, width: 40);
    isGroup = room.type == RoomType.group;
    markdownDarkConfig = MarkdownConfig.darkConfig.copy(configs: [
      LinkConfig(
          onTap: (url) {
            Utils.hideKeyboard(Get.context!);
            Get.find<MultiWebviewController>().launchWebview(initUrl: url);
          },
          style: const TextStyle(
              color: Colors.white,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white)),
      const PConfig(textStyle: TextStyle(color: Colors.white, fontSize: 16)),
      PreConfig.darkConfig
          .copy(textStyle: const TextStyle(color: Colors.white, fontSize: 16)),
      BlockquoteConfig(textColor: const Color(0xFFFFFFFF))
    ]);
    markdownLightConfig = MarkdownConfig.defaultConfig.copy(configs: [
      LinkConfig(
          onTap: (url) {
            Utils.hideKeyboard(Get.context!);
            Get.find<MultiWebviewController>().launchWebview(initUrl: url);
          },
          style: const TextStyle(
              color: Colors.blue, decoration: TextDecoration.none)),
    ]);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0.0,
          elevation: 0.0,
          backgroundColor: Get.isDarkMode
              ? const Color(0xFF000000)
              : const Color(0xffededed),
          centerTitle: true,
          title: Obx(() => Wrap(
                direction: Axis.horizontal,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  controller.roomObs.value.type != RoomType.group
                      ? getRoomTitle(controller.roomObs.value.getRoomName(),
                          controller.roomObs.value.isMute, null)
                      : getRoomTitle(
                          controller.roomObs.value.getRoomName(),
                          controller.roomObs.value.isMute,
                          controller.enableMembers.length.toString()),
                  if (controller.roomObs.value.type == RoomType.bot)
                    const Padding(
                        padding: EdgeInsets.only(left: 5),
                        child:
                            Icon(Icons.android_outlined, color: Colors.purple))
                ],
              )),
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
        body: GestureDetector(
          onTap: () {
            controller.processClickBlank();
          },
          onPanUpdate: (details) {
            if (GetPlatform.isIOS) {
              if (details.delta.dx < -10) {
                goToSetting();
              }
            }
          },
          child: Column(
            children: <Widget>[
              Obx(() => debugWidget(hc)),
              if (controller.roomObs.value.isSendAllGroup)
                Obx(() => _kpaIsNull(controller)),
              Obx(() => controller.roomObs.value.signalDecodeError
                  ? MyErrorText(
                      errorText: 'Messages decrypted failed',
                      action: TextButton(
                          child: const Text('Fix it',
                              style: TextStyle(color: Colors.white)),
                          onPressed: () async {
                            await SignalChatService.instance.sendHelloMessage(
                                controller.roomObs.value,
                                controller.roomObs.value.getIdentity());
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
                      child: Listener(
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
                          child: Obx(
                            () => CustomMaterialIndicator(
                                onRefresh: controller.loadMoreChatHistory,
                                displacement: 20,
                                backgroundColor: Colors.white,
                                trigger: IndicatorTrigger.bothEdges,
                                triggerMode: IndicatorTriggerMode.anywhere,
                                controller: controller.indicatorController,
                                indicatorBuilder: (context, c) {
                                  return Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: CircularProgressIndicator(
                                        color: KeychatGlobal.primaryColor,
                                        value: c.state.isLoading
                                            ? null
                                            : min(c.value, 1.0)),
                                  );
                                },
                                child: ListView.builder(
                                  reverse: true,
                                  shrinkWrap: true,
                                  itemCount: controller.messages.length,
                                  controller: controller.scrollController,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    Message message =
                                        controller.messages[index];

                                    RoomMember? rm;
                                    if (!message.isMeSend &&
                                        controller.roomObs.value.type ==
                                            RoomType.group) {
                                      rm = controller.getMemberByIdPubkey(
                                          message.idPubkey);
                                      if (rm != null) {
                                        message.senderName = rm.name;
                                      }
                                    }

                                    return MessageWidget(
                                      key: ObjectKey('msg:${message.id}'),
                                      myAavtar: myAavtar,
                                      index: index,
                                      isGroup: isGroup,
                                      roomMember: rm,
                                      cc: controller,
                                      screenWidth: Get.width,
                                      toDisplayNameColor: Get.isDarkMode
                                          ? Colors.white54
                                          : Colors.black54,
                                      backgroundColor: message.isMeSend
                                          ? KeychatGlobal.secondaryColor
                                          : Get.isDarkMode
                                              ? const Color(0xFF2c2c2c)
                                              : const Color(0xFFFFFFFF),
                                      fontColor: Get.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                      markdownConfig:
                                          Get.isDarkMode || message.isMeSend
                                              ? markdownDarkConfig
                                              : markdownLightConfig,
                                    );
                                  },
                                )),
                          )))),
              Obx(() => getSendMessageInput(context, controller))
            ],
          ),
        ));
  }

  Widget getSendMessageInput(BuildContext context, ChatController controller) {
    if (controller.roomObs.value.isMLSGroup &&
        !controller.roomObs.value.sentHelloToMLS) {
      return _inputSectionContainer(FilledButton(
          onPressed: () async {
            if (isSendGreeting) {
              EasyLoading.showToast('Processing, please wait...');
              return;
            }
            try {
              isSendGreeting = true;
              EasyLoading.show(
                  status:
                      '1. Receving all messages... \n2. Sending greeting...');
              Room room = await RoomService.instance
                  .getRoomByIdOrFail(controller.roomObs.value.id);

              while (true) {
                String receivingKey = room.onetimekey!;
                EasyLoading.show(status: 'Receiving from: $receivingKey');
                await MlsGroupService.instance.waitingForEose(
                    receivingKey: receivingKey,
                    relays: controller.roomObs.value.sendingRelays);
                await Future.delayed(Duration(milliseconds: 500));
                room = await RoomService.instance
                    .getRoomByIdOrFail(controller.roomObs.value.id);

                if (receivingKey == room.onetimekey &&
                    DateTime.now()
                            .difference(controller.lastMessageAddedAt)
                            .inSeconds >
                        2) {
                  loggerNoLine.i('Receiving key matched: $receivingKey');
                  break;
                }
                loggerNoLine
                    .i('Waiting for receiving key to match: $receivingKey');
              }

              await MlsGroupService.instance
                  .sendGreetingMessage(controller.roomObs.value);
              EasyLoading.dismiss();
            } catch (e) {
              String msg = Utils.getErrorMessage(e);
              EasyLoading.showError(msg);
            } finally {
              isSendGreeting = false;
            }
          },
          child: Text('Send Greeting')));
    }
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
        return _inputEditSection();
    }
  }

  Widget _inputEditSection() {
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
                        onKeyEvent: (KeyEvent event) async {
                          if (event is KeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.enter &&
                                !HardwareKeyboard.instance.isControlPressed &&
                                !HardwareKeyboard.instance.isMetaPressed &&
                                !HardwareKeyboard.instance.isShiftPressed &&
                                !HardwareKeyboard.instance.isAltPressed) {
                              controller.handleSubmitted();
                              return;
                            }

                            final isCmdPressed = HardwareKeyboard
                                    .instance.logicalKeysPressed
                                    .contains(LogicalKeyboardKey.metaLeft) ||
                                HardwareKeyboard.instance.logicalKeysPressed
                                    .contains(LogicalKeyboardKey.metaRight);
                            if (event.logicalKey == LogicalKeyboardKey.keyV &&
                                isCmdPressed) {
                              controller.handlePasteboardFile();
                              return;
                            }
                            final isShiftPressed = HardwareKeyboard
                                    .instance.logicalKeysPressed
                                    .contains(LogicalKeyboardKey.shiftLeft) ||
                                HardwareKeyboard.instance.logicalKeysPressed
                                    .contains(LogicalKeyboardKey.altLeft) ||
                                HardwareKeyboard.instance.logicalKeysPressed
                                    .contains(LogicalKeyboardKey.controlLeft);

                            if (event.logicalKey == LogicalKeyboardKey.enter &&
                                isShiftPressed) {
                              final text =
                                  controller.textEditingController.text;
                              final selection =
                                  controller.textEditingController.selection;

                              controller.textEditingController.value =
                                  controller.textEditingController.value
                                      .copyWith(
                                text: text.replaceRange(
                                    selection.start, selection.end, '\n'),
                                selection: TextSelection.collapsed(
                                  offset: selection.start + 1,
                                ),
                              );
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
                                hintText: 'Write a message...',
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.all(0)),
                            textInputAction: TextInputAction.send,
                            onEditingComplete: controller.handleSubmitted,
                            contextMenuBuilder: (context, editableTextState) {
                              final TextSelection selection = editableTextState
                                  .currentTextEditingValue.selection;
                              final String text = editableTextState
                                  .currentTextEditingValue.text;
                              final bool hasSelection = !selection.isCollapsed;
                              final bool hasText = text.isNotEmpty;
                              final bool canSelectAll = hasText &&
                                  (selection.start != 0 ||
                                      selection.end != text.length);

                              List<ContextMenuButtonItem> buttonItems = [];

                              if (hasSelection) {
                                buttonItems.add(
                                  ContextMenuButtonItem(
                                      onPressed: () {
                                        editableTextState.cutSelection(
                                            SelectionChangedCause.toolbar);
                                      },
                                      type: ContextMenuButtonType.cut),
                                );
                                buttonItems.add(
                                  ContextMenuButtonItem(
                                      onPressed: () {
                                        editableTextState.copySelection(
                                            SelectionChangedCause.toolbar);
                                      },
                                      type: ContextMenuButtonType.copy),
                                );
                              }

                              buttonItems.add(ContextMenuButtonItem(
                                  onPressed: () {
                                    controller
                                        .handlePasteboard()
                                        .catchError((error, stackTrace) {
                                      loggerNoLine.e(
                                          'Error pasting clipboard content: $error',
                                          stackTrace: stackTrace);
                                    });
                                    editableTextState.hideToolbar();
                                  },
                                  type: ContextMenuButtonType.paste));

                              if (canSelectAll) {
                                buttonItems.add(
                                  ContextMenuButtonItem(
                                      onPressed: () {
                                        editableTextState.selectAll(
                                            SelectionChangedCause.toolbar);
                                      },
                                      type: ContextMenuButtonType.selectAll),
                                );
                              }

                              return AdaptiveTextSelectionToolbar.buttonItems(
                                  anchors: editableTextState.contextMenuAnchors,
                                  buttonItems: buttonItems);
                            },
                            enableInteractiveSelection: true,
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
                                  color: KeychatGlobal.primaryColor)
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
                      ? GetPlatform.isMobile
                          ? 220.0
                          : 120
                      : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: getFeaturesWidget(context),
                ),
              ),
            )
          ],
        ));
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
                  clipBehavior: Clip.antiAlias,
                  shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(4))),
                  SafeArea(
                      child:
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
                                    RoomService.instance.sendMessage(
                                        controller.roomObs.value,
                                        element['name']);
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
                  ])));
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
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: GetPlatform.isDesktop ? 6 : 4,
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
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Image.asset(
                          controller.featuresIcons[index],
                          fit: BoxFit.contain,
                        ),
                      ),
                    )),
                Text(controller.featuresTitles[index])
              ],
            ));
      },
    );
  }

  Future<void> handleMessageSend() async {
    if (controller.textEditingController.text.isNotEmpty) {
      await controller.handleSubmitted();
      return;
    }
    if (controller.roomObs.value.type == RoomType.bot) {
      EasyLoading.showToast('Not supported in bot chat now');
      return;
    }
    controller.hideAdd.trigger(!controller.hideAdd.value);
    if (controller.hideAdd.value) {
      controller.chatContentFocus.requestFocus();
    } else {
      controller.chatContentFocus.unfocus();
    }
  }

  Future goToSetting() async {
    String route = Routes.roomSettingContact;
    if (controller.roomObs.value.type == RoomType.group) {
      route = Routes.roomSettingGroup;
    }
    await Get.toNamed(
        route.replaceFirst(':id', controller.roomObs.value.id.toString()),
        id: GetPlatform.isDesktop ? GetXNestKey.room : null);
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
                              RoomService.instance.sendMessage(
                                  controller.roomObs.value, count.toString());
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
                      MessageService.instance
                          .deleteMessageByRoomId(controller.roomObs.value.id);
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
    if (controller.roomObs.value.type == RoomType.group) {
      String lastChar = value.substring(value.length - 1, value.length);
      if (lastChar == '@' && controller.inputTextIsAdd.value) {
        var members = controller.enableMembers.values.toList();
        RoomMember? roomMember = await Get.bottomSheet(
            ignoreSafeArea: false,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
            SafeArea(
                child: Scaffold(
                    appBar: AppBar(
                      leading: Container(),
                      title: const Text('Select member to alert'),
                    ),
                    body: ListView.separated(
                        controller: ScrollController(),
                        separatorBuilder: (BuildContext context2, int index) =>
                            Divider(
                                color: Theme.of(context)
                                    .dividerTheme
                                    .color
                                    ?.withValues(alpha: 0.05)),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          RoomMember rm = members[index];
                          return ListTile(
                              onTap: () {
                                Get.back(result: members[index]);
                              },
                              leading: Utils.getRandomAvatar(rm.idPubkey,
                                  height: 36,
                                  width: 36,
                                  httpAvatar: rm.avatarFromRelay),
                              title: Text(
                                rm.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                ),
                              ));
                        }))));
        if (roomMember != null) {
          controller.addMetionName(roomMember.name);
          controller.chatContentFocus.requestFocus();
          // FocusScope.of(Get.context!).requestFocus(controller.chatContentFocus);
        }
      }
    }
  }

  Widget getRoomTitle(String title, bool isMute, String? memberCount) {
    return Wrap(
      direction: Axis.horizontal,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(memberCount != null ? '$title ($memberCount)' : title),
        if (isMute)
          Icon(
            Icons.notifications_off_outlined,
            color: Theme.of(Get.context!)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6),
            size: 18,
          )
      ],
    );
  }

  Widget _inputSectionContainer(Widget child) {
    return SafeArea(
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16), child: child));
  }

  Widget _exitInputSection() {
    return _inputSectionContainer(FilledButton(
      style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.red)),
      onPressed: () async {
        await RoomService.instance.deleteRoom(controller.roomObs.value);
        Get.find<HomeController>()
            .loadIdentityRoomList(controller.roomObs.value.identityId);
        await Utils.offAllNamedRoom(Routes.root);
      },
      child: const Text('Exit and Delete Room',
          style: TextStyle(color: Colors.white)),
    ));
  }

  Widget _approvingInputSection() {
    return _inputSectionContainer(Wrap(
      direction: Axis.vertical,
      runAlignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      children: [
        const Text('You have a friend request'),
        Wrap(
          runSpacing: 10,
          spacing: 30,
          children: [
            FilledButton(
              onPressed: () async {
                try {
                  Room room = controller.roomObs.value;
                  room = await RoomService.instance.getRoomByIdOrFail(room.id);
                  if (room.status == RoomStatus.approving) {
                    String displayName = room.getIdentity().displayName;
                    await SignalChatService.instance.sendMessage(
                        room, RoomUtil.getHelloMessage(displayName));
                    room.status = RoomStatus.enabled;
                    await RoomService.instance.updateRoomAndRefresh(room);
                  }
                } catch (e, s) {
                  EasyLoading.showError(e.toString());
                  logger.e(e.toString(), error: e, stackTrace: s);
                }
                Get.find<HomeController>()
                    .loadIdentityRoomList(controller.roomObs.value.identityId);
              },
              style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.green)),
              child:
                  const Text('Approve', style: TextStyle(color: Colors.white)),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  int identityId = controller.roomObs.value.identityId;
                  await RoomService.instance
                      .deleteRoom(controller.roomObs.value);
                  Get.find<HomeController>().loadIdentityRoomList(identityId);
                  await Utils.offAllNamedRoom(Routes.root);
                } catch (e) {
                  String msg = Utils.getErrorMessage(e);
                  EasyLoading.showError(msg);
                  logger.e(msg, error: e);
                }
              },
              style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.red)),
              child:
                  const Text('Ignore', style: TextStyle(color: Colors.white)),
            ),
          ],
        )
      ],
    ));
  }

  Widget _requestingInputSection() {
    return _inputSectionContainer(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Text('Friend request sent. Waiting for their response.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                fontSize: 16))));
  }

  Room _getRoomAndInit(BuildContext context) {
    Room? room = widget.room;
    int? roomId = widget.room?.id;
    int searchMessageId = -1;
    if (room == null) {
      if (Get.parameters['id'] != null) {
        roomId = int.parse(Get.parameters['id']!);
      }
      if (Get.arguments == null && roomId != null) {
        room = RoomService.instance.getRoomByIdSync(roomId);
      } else {
        try {
          Map<String, dynamic> arguments = Get.arguments;
          room = arguments['room'];
          searchMessageId = arguments['messageId'] ?? -1;
        } catch (e) {
          // only one arguments, not in Json format
          room = Get.arguments as Room;
        }
      }
    }
    controller =
        Utils.getGetxController<ChatController>(tag: roomId.toString()) ??
            Get.put(ChatController(room!, mId: searchMessageId),
                tag: roomId.toString());
    return room!;
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
                Column(children: [
                  NoticeTextWidget.warning(
                      'You are not friends, cannot send and receive messages'),
                  const SizedBox(height: 16),
                  Expanded(
                      child: Obx(() => ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          separatorBuilder: (context2, index) =>
                              const SizedBox(height: 4),
                          shrinkWrap: true,
                          itemCount: controller.kpaIsNullRooms.length,
                          itemBuilder: (context, index) {
                            Room room = controller.kpaIsNullRooms[index];
                            room.contact ??= ContactService.instance
                                .getOrCreateContactSync(
                                    room.identityId, room.toMainPubkey);
                            return ListTile(
                              leading: Utils.getAvatarDot(room, width: 40),
                              key: Key('room:${room.id}'),
                              title: Text(room.getRoomName()),
                              trailing: OutlinedButton(
                                  onPressed: () async {
                                    Room? room0 = await RoomService.instance
                                        .createRoomAndsendInvite(
                                            room.toMainPubkey,
                                            autoJump: false,
                                            greeting:
                                                'From group: ${controller.roomObs.value.getRoomName()}');
                                    if (room0 != null) {
                                      controller.kpaIsNullRooms[index] = room0;
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
