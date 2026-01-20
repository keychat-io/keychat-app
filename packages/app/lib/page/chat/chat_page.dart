import 'dart:async' show Timer;
import 'dart:convert' show jsonDecode;
import 'dart:math' show Random, min;
import 'dart:ui' show ImageFilter;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/controller/chat.controller.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:keychat/page/chat/message_widget.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/page/routes.dart';
import 'package:keychat/page/widgets/error_text.dart';
import 'package:keychat/page/widgets/notice_text_widget.dart';
import 'package:keychat/service/contact.service.dart';
import 'package:keychat/service/message.service.dart';
import 'package:keychat/service/mls_group.service.dart';
import 'package:keychat/service/signal_chat.service.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';
import 'package:settings_ui/settings_ui.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({this.room, super.key});
  final Room? room;

  @override
  _ChatPage2State createState() => _ChatPage2State();
}

class _ChatPage2State extends State<ChatPage> {
  late ChatController controller;
  HomeController hc = Get.find<HomeController>();

  late Widget myAvatar;
  bool isGroup = false;
  late MarkdownConfig markdownDarkConfig;
  late MarkdownConfig markdownLightConfig;
  bool isSendGreeting = false;
  late Room room;

  @override
  void initState() {
    room = _getRoomAndInit();
    myAvatar = Utils.getAvatarByIdentity(room.getIdentity());
    isGroup = room.type == RoomType.group;
    markdownDarkConfig = MarkdownConfig.darkConfig.copy(
      configs: [
        const LinkConfig(
          onTap: RoomUtil.tapLink,
          style: TextStyle(
            color: Colors.white,
            decoration: TextDecoration.underline,
            decorationColor: Colors.white,
          ),
        ),
        const PConfig(textStyle: TextStyle(color: Colors.white, fontSize: 16)),
        PreConfig.darkConfig.copy(
          textStyle: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        const BlockquoteConfig(textColor: Color(0xFFFFFFFF)),
      ],
    );
    markdownLightConfig = MarkdownConfig.defaultConfig.copy(
      configs: [
        const LinkConfig(
          onTap: RoomUtil.tapLink,
          style: TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            scrolledUnderElevation: 0,
            elevation: 0,
            centerTitle: true,
            title: Obx(
              () => Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  getRoomTitle(
                    controller.roomObs.value.getRoomName(),
                    isMute: controller.roomObs.value.isMute,
                    memberCount: controller.enableMembers.length,
                  ),
                  if (controller.roomObs.value.type == RoomType.bot)
                    const Padding(
                      padding: EdgeInsets.only(left: 5),
                      child: Icon(
                        Icons.android_outlined,
                        color: Colors.purple,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              Obx(
                () => controller.nipChatType.value.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () async {
                            await RoomUtil.deprecatedEncryptedDialog(
                              controller.roomObs.value,
                            );
                          },
                          child: Text(
                            '⚠️',
                            style: TextStyle(
                              color: Colors.red.withAlpha(200),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    : Container(),
              ),
              Obx(
                () => controller.roomObs.value.status != RoomStatus.approving
                    ? IconButton(
                        onPressed: goToSetting,
                        icon: const Icon(Icons.more_horiz),
                      )
                    : Container(),
              ),
            ],
          ),
          body: GestureDetector(
            onTap: controller.processClickBlankArea,
            onPanUpdate: (details) async {
              if (GetPlatform.isIOS && details.delta.dx < -10) {
                await goToSetting();
              }
            },
            child: Column(
              children: <Widget>[
                Obx(() => debugWidget(hc)),
                if (controller.roomObs.value.isSendAllGroup)
                  Obx(() => _kpaIsNull(controller)),
                Obx(
                  () => controller.roomObs.value.signalDecodeError
                      ? MyErrorText(
                          errorText: 'Messages decrypted failed',
                          action: TextButton(
                            child: const Text(
                              'Fix it',
                              style: TextStyle(color: Colors.white),
                            ),
                            onPressed: () async {
                              await SignalChatService.instance.sendHelloMessage(
                                controller.roomObs.value,
                                controller.roomObs.value.getIdentity(),
                              );
                              EasyLoading.showInfo(
                                'Request sent successfully.',
                              );
                            },
                          ),
                        )
                      : const SizedBox(),
                ),
                Expanded(
                  child: Container(
                    color: Get.isDarkMode
                        ? const Color(0xFF000000)
                        : const Color(0xffededed),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: CustomMaterialIndicator(
                      onRefresh: controller.pullToLoadMessages,
                      displacement: 4,
                      trigger: IndicatorTrigger.bothEdges,
                      triggerMode: IndicatorTriggerMode.anywhere,
                      controller: controller.indicatorController,
                      indicatorBuilder: (context, c) {
                        return Padding(
                          padding: const EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            color: KeychatGlobal.primaryColor,
                            value: c.state.isLoading ? null : min(c.value, 1),
                          ),
                        );
                      },
                      child: Obx(
                        () => ListView.builder(
                          key: PageStorageKey<String>(
                            'chatlistview:${controller.roomObs.value.id}',
                          ),
                          reverse: true,
                          shrinkWrap: true,
                          itemCount: controller.messages.length,
                          controller: controller.scrollController,
                          itemBuilder: (BuildContext context, int index) {
                            final message = controller.messages[index];
                            RoomMember? rm;
                            if (!message.isMeSend &&
                                controller.roomObs.value.type ==
                                    RoomType.group) {
                              rm = controller.getMemberByIdPubkey(
                                message.idPubkey,
                              );
                              if (rm != null) {
                                message.senderName = rm.name;
                              }
                            }

                            return MessageWidget(
                              key: ObjectKey('msg:${message.id}'),
                              myAavtar: myAvatar,
                              index: index,
                              isGroup: isGroup,
                              roomMember: rm,
                              cc: controller,
                              screenWidth: Get.width,
                              backgroundColor: message.isMeSend
                                  ? KeychatGlobal.secondaryColor
                                  : Get.isDarkMode
                                  ? const Color(0xFF2c2c2c)
                                  : const Color(0xFFFFFFFF),
                              markdownLightConfig: markdownLightConfig,
                              markdownDarkConfig: markdownDarkConfig,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Obx(
                  () => getSendMessageInput(
                    status: controller.roomObs.value.status,
                    needSendGreeting:
                        controller.roomObs.value.isMLSGroup &&
                        !controller.roomObs.value.sentHelloToMLS,
                  ),
                ),
              ],
            ),
          ),
        ), // Privacy protection blur layer
        if (GetPlatform.isMobile)
          Obx(
            () => hc.isBlurred.value
                ? Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: ColoredBox(
                        color: Colors.black.withAlpha(30),
                        child: const Center(
                          child: Icon(
                            CupertinoIcons.lock_shield_fill,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }

  Widget getSendMessageInput({
    required RoomStatus status,
    required bool needSendGreeting,
  }) {
    if (needSendGreeting) {
      return _sendGreetingSection();
    }
    switch (status) {
      case RoomStatus.requesting:
        return _requestingInputSection();
      case RoomStatus.approving:
      case RoomStatus.approvingNoResponse:
        return _approvingInputSection();
      case RoomStatus.rejected:
      case RoomStatus.dissolved:
      case RoomStatus.removedFromGroup:
        return _exitInputSection();
      case RoomStatus.enabled:
        return _inputEditSection();
      case RoomStatus.init:
        return _inputEditSection();
      case RoomStatus.disabled:
        return Container();
      case RoomStatus.groupUser:
        return Container();
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
              bottom: 8,
              top: controller.inputReplys.isNotEmpty ? 0 : 4,
            ),
            child: Row(
              children: <Widget>[
                // if (controller.botCommands.isNotEmpty)
                //   botMenuWidget(controller, context),
                IconButton(
                  iconSize: 28,
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    Utils.hideKeyboard(context);
                    final giphy = dotenv.get('GIPHY');
                    if (giphy.isEmpty) {
                      await EasyLoading.showInfo(
                        'GIPHY API key is not configured.',
                      );
                      return;
                    }
                    try {
                      final gif = await GiphyGet.getGif(
                        context: context,
                        apiKey: giphy,
                        randomID: Utils.randomString(8),
                        loadingWidget: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        failedWidget: ColoredBox(
                          color: Theme.of(context).cardColor,
                          child: const Center(
                            child: Text('Load Failed'),
                          ),
                        ),
                        tabBottomBuilder: (context) => Container(),
                      );
                      logger.d('Selected GIF: $gif');
                      if (gif == null) return;

                      final imageUrl =
                          gif.images?.fixedWidthDownsampled?.url ??
                          gif.images?.fixedWidth.url;
                      if (imageUrl == null) return;
                      await controller.sendGiphyMessage(imageUrl);
                    } catch (e) {
                      logger.e(e);
                    }
                  },
                  icon: const Icon(Icons.emoji_emotions_outlined),
                ),
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
                          await controller.handleSubmitted();
                          return;
                        }

                        final isCmdPressed =
                            HardwareKeyboard.instance.logicalKeysPressed
                                .contains(LogicalKeyboardKey.metaLeft) ||
                            HardwareKeyboard.instance.logicalKeysPressed
                                .contains(LogicalKeyboardKey.metaRight);
                        if (event.logicalKey == LogicalKeyboardKey.keyV &&
                            isCmdPressed) {
                          await controller.handlePasteboardFile();
                          return;
                        }
                        final isShiftPressed =
                            HardwareKeyboard.instance.logicalKeysPressed
                                .contains(LogicalKeyboardKey.shiftLeft) ||
                            HardwareKeyboard.instance.logicalKeysPressed
                                .contains(LogicalKeyboardKey.altLeft) ||
                            HardwareKeyboard.instance.logicalKeysPressed
                                .contains(LogicalKeyboardKey.controlLeft);

                        if (event.logicalKey == LogicalKeyboardKey.enter &&
                            isShiftPressed) {
                          final text = controller.textEditingController.text;
                          final selection =
                              controller.textEditingController.selection;

                          controller.textEditingController.value = controller
                              .textEditingController
                              .value
                              .copyWith(
                                text: text.replaceRange(
                                  selection.start,
                                  selection.end,
                                  '\n',
                                ),
                                selection: TextSelection.collapsed(
                                  offset: selection.start + 1,
                                ),
                              );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(4),
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
                          contentPadding: EdgeInsets.zero,
                        ),
                        textInputAction: TextInputAction.send,
                        onEditingComplete: controller.handleSubmitted,
                        contextMenuBuilder: (context, editableTextState) {
                          final selection = editableTextState
                              .currentTextEditingValue
                              .selection;
                          final text =
                              editableTextState.currentTextEditingValue.text;
                          final hasSelection = !selection.isCollapsed;
                          final hasText = text.isNotEmpty;
                          final canSelectAll =
                              hasText &&
                              (selection.start != 0 ||
                                  selection.end != text.length);

                          final buttonItems = <ContextMenuButtonItem>[];

                          if (hasSelection) {
                            buttonItems
                              ..add(
                                ContextMenuButtonItem(
                                  onPressed: () {
                                    editableTextState.cutSelection(
                                      SelectionChangedCause.toolbar,
                                    );
                                  },
                                  type: ContextMenuButtonType.cut,
                                ),
                              )
                              ..add(
                                ContextMenuButtonItem(
                                  onPressed: () {
                                    editableTextState.copySelection(
                                      SelectionChangedCause.toolbar,
                                    );
                                  },
                                  type: ContextMenuButtonType.copy,
                                ),
                              );
                          }

                          buttonItems.add(
                            ContextMenuButtonItem(
                              onPressed: () async {
                                await controller.handlePasteboard();
                                editableTextState.hideToolbar();
                              },
                              type: ContextMenuButtonType.paste,
                            ),
                          );

                          if (canSelectAll) {
                            buttonItems.add(
                              ContextMenuButtonItem(
                                onPressed: () {
                                  editableTextState.selectAll(
                                    SelectionChangedCause.toolbar,
                                  );
                                },
                                type: ContextMenuButtonType.selectAll,
                              ),
                            );
                          }

                          return AdaptiveTextSelectionToolbar.buttonItems(
                            anchors: editableTextState.contextMenuAnchors,
                            buttonItems: buttonItems,
                          );
                        },
                        enableInteractiveSelection: true,
                        maxLines: 8,
                        minLines: 1,
                        scrollController: controller.textFieldScrollController,
                        textAlign: TextAlign.left,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(fontSize: 16),
                        cursorColor: Colors.green,
                        onTap: () {
                          controller.hideEmoji.value = true;
                          controller.hideAdd.value = true;
                        },
                        onChanged: handleOnChanged,
                        onFieldSubmitted: (c) async {
                          await controller.handleSubmitted();
                        },
                        enabled: true,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  iconSize: 28,
                  padding: EdgeInsets.zero,
                  onPressed: handleMessageSend,
                  icon: controller.inputText.value.isNotEmpty
                      ? const Icon(
                          CupertinoIcons.arrow_up_circle_fill,
                          color: KeychatGlobal.primaryColor,
                        )
                      : const Icon(CupertinoIcons.add_circled),
                ),
              ],
            ),
          ),
          Visibility(
            visible: !controller.hideAdd.value,
            child: AnimatedOpacity(
              opacity: !controller.hideAdd.value ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: AnimatedContainer(
                // height: !controller.hideAdd.value ? 220.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ResponsiveGridList(
                    listViewBuilderOptions: ListViewBuilderOptions(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                    ),
                    minItemWidth: 68,
                    children: controller.featuresIcons.indexed.map((record) {
                      final (index, item) = record;
                      return GestureDetector(
                        onTap: () {
                          (controller.featuresOnTaps[index] as Function)();
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Image.asset(
                                    item,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                            Text(controller.featuresTitles[index]),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Padding botMenuWidget(ChatController controller, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 5, bottom: 5),
      child: GestureDetector(
        onTap: () {
          final Map localConfig =
              jsonDecode(controller.roomObs.value.botLocalConfig ?? '{}')
                  as Map<String, dynamic>;
          final Map? botPricePerMessageRequest =
              localConfig['botPricePerMessageRequest'] as Map<String, dynamic>?;
          Get.bottomSheet(
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
            SafeArea(
              child: SettingsList(
                platform: DevicePlatform.iOS,
                sections: [
                  SettingsSection(
                    title: const Text('Commands'),
                    tiles: controller.botCommands
                        .map(
                          (element) => SettingsTile(
                            title: Text(element['name'] as String),
                            value: Flexible(
                              child: textSmallGray(
                                context,
                                element['description'] as String,
                                overflow: TextOverflow.clip,
                              ),
                            ),
                            onPressed: (context) async {
                              RoomService.instance.sendMessage(
                                controller.roomObs.value,
                                element['name'] as String,
                              );
                              Get.back<void>();
                            },
                          ),
                        )
                        .toList(),
                  ),
                  if (botPricePerMessageRequest != null)
                    SettingsSection(
                      title: const Text('Selected Local Config'),
                      tiles: [
                        SettingsTile(
                          title: Text(
                            botPricePerMessageRequest['name'] as String,
                          ),
                          trailing: Text(
                            '${botPricePerMessageRequest['price']} ${botPricePerMessageRequest['unit']} /message',
                          ),
                          onPressed: (context) async {
                            Get.back<void>();
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
        child: Icon(
          size: 26,
          Icons.menu,
          weight: 300,
          color: Theme.of(context).iconTheme.color?.withAlpha(155),
        ),
      ),
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

  Future<void> goToSetting() async {
    var route = Routes.roomSettingContact;
    if (controller.roomObs.value.type == RoomType.group) {
      route = Routes.roomSettingGroup;
    }
    await Get.toNamed(
      route.replaceFirst(':id', controller.roomObs.value.id.toString()),
      id: GetPlatform.isDesktop ? GetXNestKey.room : null,
    );
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
                    duration: const Duration(seconds: 5),
                  );
                  hc.debugSendMessageRunning.value = true;
                  var count = 0;
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
                        controller.roomObs.value,
                        count.toString(),
                      );
                      randomTimer();
                    });
                  }

                  randomTimer();
                },
                child: const Text('Start'),
              ),
            ),
            Visibility(
              visible: hc.debugSendMessageRunning.value,
              child: FilledButton(
                onPressed: () {
                  hc.debugSendMessageRunning.value = false;
                },
                child: const Text('Stop '),
              ),
            ),
            OutlinedButton(
              onPressed: () {
                MessageService.instance.deleteMessageByRoomId(
                  controller.roomObs.value.id,
                );
                Get.back<void>();
              },
              child: const Text('clean'),
            ),
            OutlinedButton(
              onPressed: () {
                controller.getRoomStats();
              },
              child: const Text('stats'),
            ),
          ],
        ),
      ),
    );
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
          style: Theme.of(Get.context!).textTheme.bodyMedium?.copyWith(
            color: Colors.blue.shade700,
            height: 1,
          ),
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
          ),
        ),
      ),
    );
  }

  Future<void> handleOnChanged(String value) async {
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
      final lastChar = value.substring(value.length - 1, value.length);
      if (lastChar == '@' && controller.inputTextIsAdd.value) {
        final members = controller.enableMembers.values.toList();
        final roomMember = await Get.bottomSheet<RoomMember>(
          ignoreSafeArea: false,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          ),
          SafeArea(
            child: Scaffold(
              appBar: AppBar(
                leading: Container(),
                title: const Text('Select member to alert'),
              ),
              body: ListView.separated(
                controller: ScrollController(),
                separatorBuilder: (BuildContext context2, int index) => Divider(
                  color: Theme.of(
                    context,
                  ).dividerTheme.color?.withValues(alpha: 0.05),
                ),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final rm = members[index];
                  return ListTile(
                    onTap: () {
                      Get.back(result: members[index]);
                    },
                    leading: Utils.getRandomAvatar(
                      rm.idPubkey,
                      size: 36,
                      contact: rm.contact,
                    ),
                    title: Text(
                      rm.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        if (roomMember != null) {
          controller.addMetionName(roomMember.displayName);
          controller.chatContentFocus.requestFocus();
          // FocusScope.of(Get.context!).requestFocus(controller.chatContentFocus);
        }
      }
    }
  }

  Widget getRoomTitle(
    String title, {
    bool isMute = false,
    int memberCount = 0,
  }) {
    return Wrap(
      key: ValueKey('title:${room.toMainPubkey}'),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (memberCount > 0) Text('$title ($memberCount)') else Text(title),
        if (isMute)
          Icon(
            Icons.notifications_off_outlined,
            color: Theme.of(
              Get.context!,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
            size: 18,
          ),
      ],
    );
  }

  Widget _inputSectionContainer(Widget child) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: child,
      ),
    );
  }

  Widget _exitInputSection() {
    return _inputSectionContainer(
      FilledButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.red),
        ),
        onPressed: () async {
          await RoomService.instance.deleteRoom(controller.roomObs.value);
          Get.find<HomeController>().loadIdentityRoomList(
            controller.roomObs.value.identityId,
          );
          await Utils.offAllNamedRoom(Routes.root);
        },
        child: const Text(
          'Exit and Delete Room',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _approvingInputSection() {
    return _inputSectionContainer(
      Wrap(
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
                    final room = await RoomService.instance.getRoomByIdOrFail(
                      controller.roomObs.value.id,
                    );
                    if (room.status != RoomStatus.approving) return;
                    final displayName = room.getIdentity().displayName;
                    await SignalChatService.instance.sendMessage(
                      room,
                      RoomUtil.getHelloMessage(displayName),
                    );
                    final contact = await ContactService.instance
                        .addContactToFriend(
                          pubkey: room.toMainPubkey,
                          identityId: room.identityId,
                          fetchAvatar: true,
                        );

                    room
                      ..status = RoomStatus.enabled
                      ..contact = contact;
                    Utils.removeAvatarCacheByPubkey(room.toMainPubkey);
                    await RoomService.instance.updateRoomAndRefresh(
                      room,
                      refreshContact: true,
                    );
                  } catch (e, s) {
                    final msg = Utils.getErrorMessage(e);
                    await EasyLoading.showError(msg);
                    logger.e(msg, error: e, stackTrace: s);
                  }
                  Get.find<HomeController>().loadIdentityRoomList(
                    controller.roomObs.value.identityId,
                  );
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.green),
                ),
                child: const Text(
                  'Approve',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    final identityId = controller.roomObs.value.identityId;
                    await RoomService.instance.deleteRoom(
                      controller.roomObs.value,
                    );
                    Get.find<HomeController>().loadIdentityRoomList(identityId);
                    await Utils.offAllNamedRoom(Routes.root);
                  } catch (e) {
                    final msg = Utils.getErrorMessage(e);
                    EasyLoading.showError(msg);
                    logger.e(msg, error: e);
                  }
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.red),
                ),
                child: const Text(
                  'Ignore',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _requestingInputSection() {
    return _inputSectionContainer(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Text(
          'Friend request sent. Waiting for their response.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  int? tryGetMessageId() {
    try {
      final arguments = Get.arguments as Map<String, dynamic>;
      return arguments['messageId'] as int?;
      // ignore: empty_catches
    } catch (e) {}
    return null;
  }

  Room _getRoomAndInit() {
    var room = widget.room;
    var roomId = widget.room?.id;
    final searchMessageId = tryGetMessageId();
    if (room == null) {
      if (Get.parameters['id'] != null) {
        roomId = int.parse(Get.parameters['id']!);
      }
      if (Get.arguments == null && roomId != null) {
        room = RoomService.instance.getRoomByIdSync(roomId);
      } else {
        try {
          final arguments = Get.arguments as Map<String, dynamic>;
          room = arguments['room'] as Room?;
        } catch (e) {
          room = Get.arguments as Room;
        }
      }
    }
    final exist = Utils.getGetxController<ChatController>(
      tag: roomId.toString(),
    );
    if (exist != null) {
      controller = exist;
      if (searchMessageId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await controller.loadFromMessageId(searchMessageId);
        });
      }
    } else {
      controller = Get.put(
        ChatController(room!, searchMessageId: searchMessageId ?? -1),
        tag: roomId.toString(),
      );
    }
    return room!;
  }

  Widget _kpaIsNull(ChatController controller) {
    if (controller.kpaIsNullRooms.isEmpty) {
      return const SizedBox();
    }
    return ListTile(
      leading: const Icon(Icons.warning, color: Colors.yellow),
      title: Text('NotContacts: ${controller.kpaIsNullRooms.length}'),
      subtitle: const Text(
        'You are not friends, cannot send and receive messages',
      ),
      trailing: FilledButton(
        onPressed: () {
          showModalBottomSheetWidget(
            Get.context!,
            'Add Contacts',
            Column(
              children: [
                NoticeTextWidget.warning(
                  'You are not friends, cannot send and receive messages',
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Obx(
                    () => ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (context2, index) =>
                          const SizedBox(height: 4),
                      shrinkWrap: true,
                      itemCount: controller.kpaIsNullRooms.length,
                      itemBuilder: (context, index) {
                        final room = controller.kpaIsNullRooms[index];
                        room.contact ??= ContactService.instance
                            .getOrCreateContactSync(
                              room.identityId,
                              room.toMainPubkey,
                            );
                        return ListTile(
                          leading: Utils.getAvatarByRoom(room),
                          key: Key('room:${room.id}'),
                          title: Text(room.getRoomName()),
                          trailing: OutlinedButton(
                            onPressed: () async {
                              final room0 = await RoomService.instance
                                  .createRoomAndsendInvite(
                                    room.toMainPubkey,
                                    autoJump: false,
                                    greeting:
                                        'From group: ${controller.roomObs.value.getRoomName()}',
                                  );
                              if (room0 != null) {
                                controller.kpaIsNullRooms[index] = room0;
                                controller.kpaIsNullRooms.refresh();
                              }
                            },
                            child: Text(
                              room.status == RoomStatus.requesting
                                  ? 'Requesting'
                                  : 'Send',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: const Text('View'),
      ),
    );
  }

  Widget _sendGreetingSection() {
    return _inputSectionContainer(
      FilledButton(
        onPressed: () async {
          if (isSendGreeting) {
            EasyLoading.showToast('Processing, please wait...');
            return;
          }
          try {
            isSendGreeting = true;
            EasyLoading.show(
              status: '1. Receving all messages... \n2. Sending greeting...',
            );
            var room = await RoomService.instance.getRoomByIdOrFail(
              controller.roomObs.value.id,
            );

            while (true) {
              final receivingKey = room.onetimekey!;
              EasyLoading.show(status: 'Receiving from: $receivingKey');
              await MlsGroupService.instance.waitingForEose(
                receivingKey: receivingKey,
                relays: controller.roomObs.value.sendingRelays,
              );
              await Future.delayed(const Duration(milliseconds: 500));
              room = await RoomService.instance.getRoomByIdOrFail(
                controller.roomObs.value.id,
              );

              if (receivingKey == room.onetimekey &&
                  DateTime.now()
                          .difference(controller.lastMessageAddedAt)
                          .inSeconds >
                      2) {
                loggerNoLine.i('Receiving key matched: $receivingKey');
                break;
              }
              loggerNoLine.i(
                'Waiting for receiving key to match: $receivingKey',
              );
            }

            await MlsGroupService.instance.sendGreetingMessage(
              controller.roomObs.value,
            );
            EasyLoading.dismiss();
          } catch (e) {
            final msg = Utils.getErrorMessage(e);
            EasyLoading.showError(msg);
          } finally {
            isSendGreeting = false;
          }
        },
        child: const Text('Send Greeting'),
      ),
    );
  }
}
