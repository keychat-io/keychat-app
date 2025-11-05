import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/global.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:keychat/page/chat/create_contact_page.dart';
import 'package:keychat/page/setting/my_qrcode.dart';
import 'package:keychat/service/chatx.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/service/signalId.service.dart';
import 'package:keychat/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:search_page/search_page.dart';
import 'package:settings_ui/settings_ui.dart';

Widget centerLoadingComponent([String title = 'loading']) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ],
    ),
  );
}

Text textP(String title, {Color? color, int? maxLength}) {
  if (maxLength != null) {
    if (title.length > maxLength) {
      title = title.substring(0, maxLength);
    }
  }
  return Text(
    title,
    style: TextStyle(
      fontSize: 16,
      color: color,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

Text textDescription(String title, BuildContext context) {
  return Text(
    title,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    ),
  );
}

Text errorText(String title) {
  return Text(
    title,
    style: TextStyle(color: Colors.red.shade400),
  );
}

SettingsTile settingInfoCopy(String title, String content, [Icon? icon]) {
  return SettingsTile(
    leading: icon,
    title: Text(title),
    value: textP(content),
    onPressed: (context) {
      Clipboard.setData(ClipboardData(text: title));
      Get.snackbar(
        'Success',
        'Copied to clipboard',
        snackPosition: SnackPosition.BOTTOM,
      );
    },
  );
}

Future<void> showDeleteMsgDialog(BuildContext context, Room room) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return CupertinoAlertDialog(
        content: const Text(
          'Clear chat history?',
          style: TextStyle(fontSize: 20),
          textAlign: TextAlign.center,
        ),
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
              'Clear',
            ),
            onPressed: () async {
              Get.back<void>();
              await RoomService.instance.deleteRoomMessage(room);
              Get.find<HomeController>().loadIdentityRoomList(room.identityId);
            },
          ),
        ],
      );
    },
  );
}

Container getAppBarFlexibleSpace() {
  final colors = Get.isDarkMode
      ? [Colors.black, Colors.black]
      : [const Color(0xffededed), const Color(0xffe6e1e5)];
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        // colors: [Colors.blue, Colors.purple],
        colors: colors,
      ),
    ),
  );
}

List futuresTitle = [
  'End-to-End Encryption',
  'Customizable Relay Servers',
  'Multiple Identity',
  'Local Data Storage',
  'Privacy First',
];
List futuresSubtitle = [
  'Keychat uses the Double Ratchet Algorithm of Signal protocol to encrypt and decrypt every message. Achieving forward and backward secrecy of messages.',
  'Configurable relay server or deploy your own. Relay is a lightweight service that can store and transmit encrypted data.',
  'Encourage to use multiple identities in Keychat for different chat scenarios, such as private and public group chats.',
  'All contact, private key, configuration and other data are stored on your device without server interaction.',
  "We don't provide any servers, collect any account or device data, or any runtime logs. Your data is entirely stored locally, ensuring perfect protection of your privacy.",
];
void showModalBottomSheetKeyChatFetures(BuildContext context) {
  final ws = <Widget>[];
  for (var i = 0; i < futuresTitle.length; i++) {
    ws.add(
      ListTile(
        leading: CircleAvatar(child: Text((i + 1).toString())),
        title: Text(futuresTitle[i]),
        subtitle: Text(futuresSubtitle[i]),
      ),
    );
  }
  showModalBottomSheetWidget(
    context,
    'Why Keychat?',
    SafeArea(
      bottom: false,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: ws,
      ),
    ),
  );
}

// almost fullscreen
void showModalBottomSheetWidget(
  BuildContext context,
  String title,
  Widget body, {
  bool showAppBar = true,
  Function? callback,
}) {
  if (!showAppBar) {
    showCupertinoSheet(
      context: context,
      builder: (context) => Scaffold(
        body: Center(
          child: Stack(
            children: [
              body,
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  onPressed: () {
                    Get.back<void>();
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return;
  }
  showCupertinoSheet(
    context: context,
    builder: (context) => Scaffold(
      appBar: getSheetAppBar(context, title, callback),
      body: body,
    ),
  );
}

AppBar getSheetAppBar(
  BuildContext context,
  String title, [
  Function? callback,
]) {
  return AppBar(
    leading: const SizedBox(),
    title: Text(title),
    centerTitle: true,
    actions: [
      IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          Get.back<void>();
          if (callback != null) callback();
        },
      ),
    ],
  );
}

// Adaptive height, not suitable for content with OBX
void showFitSheetWidget(
  BuildContext context,
  String title,
  List<Widget> bodys, {
  bool showAppBar = true,
  Function? callback,
}) {
  showCupertinoSheet(
    context: context,
    builder: (context) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAppBar) getSheetAppBar(context, title, callback),
          ...bodys,
          const SizedBox(
            height: 30,
          ),
        ],
      ),
    ),
  );
}

void getGroupInfoBottomSheetWidget(BuildContext context) {
  Get.bottomSheet(
    ignoreSafeArea: false,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
    ),
    SafeArea(
      child: Scaffold(
        body: ListView(
          children: [
            ListTile(
              title: Text(
                'Large Group - MLS Protocol',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(RoomUtil.getGroupModeDescription(GroupType.mls)),
            ),
            ListTile(
              title: Text(
                'Small Group - Signal Protocol',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                RoomUtil.getGroupModeDescription(GroupType.sendAll),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget codeSnippet(String text) {
  return Text(
    text,
    style: TextStyle(
      fontFamily: 'Roboto Mono',
      fontSize: 16,
      color: Colors.black,
      backgroundColor: Colors.grey[200],
    ),
  );
}

Widget relayStatusList(BuildContext context, List<NostrEventStatus> ess) {
  if (ess.isEmpty) return const SizedBox();
  final sentCount = ess.where((element) => !element.isReceive).length;
  final sentSuccessCount = ess
      .where(
        (element) =>
            !element.isReceive && element.sendStatus == EventSendEnum.success,
      )
      .length;
  return Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.network_check,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Message Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (sentCount > 0) Text('Success: $sentSuccessCount/$sentCount'),
            ],
          ),
        ),
        const Divider(height: 1),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: ess.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            indent: 56,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
          itemBuilder: (context, index) {
            final es = ess[index];
            final isSuccess = es.sendStatus == EventSendEnum.success;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: es.isReceive
                          ? Colors.blue.withValues(alpha: 0.1)
                          : (isSuccess
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: es.isReceive
                        ? const Icon(
                            Icons.arrow_downward,
                            color: Colors.lightBlue,
                          )
                        : Icon(
                            Icons.arrow_upward_outlined,
                            color: es.sendStatus == EventSendEnum.success
                                ? Colors.lightGreen
                                : Colors.red,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          es.relay,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isSuccess) ...[
                          const SizedBox(height: 4),
                          _buildStatusChip(context, es.sendStatus, es.error),
                        ],
                        if (es.ecashAmount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '-${es.ecashAmount} ${es.ecashName}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (es.ecashToken != null &&
                              es.ecashToken!.isNotEmpty)
                            textSmallGray(context, es.ecashToken!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}

Widget _buildStatusChip(
  BuildContext context,
  EventSendEnum sendStatus, [
  String? errorMessage,
]) {
  String text;
  Color backgroundColor;
  Color textColor;
  IconData icon;

  switch (sendStatus) {
    case EventSendEnum.init:
      text = 'No Receipt';
      backgroundColor = Colors.grey.withValues(alpha: 0.2);
      textColor = Colors.grey.shade700;
      icon = Icons.schedule;
    case EventSendEnum.relayConnecting:
      text = 'Disconnected';
      backgroundColor = Colors.orange.withValues(alpha: 0.2);
      textColor = Colors.orange.shade700;
      icon = Icons.signal_wifi_off;
    case EventSendEnum.cashuError:
      text = 'Pay Error';
      backgroundColor = Colors.red.withValues(alpha: 0.2);
      textColor = Colors.red.shade700;
      icon = Icons.error_outline;
    default:
      text = sendStatus.name;
      backgroundColor = Colors.red.withValues(alpha: 0.2);
      textColor = Colors.red.shade700;
      icon = Icons.warning_amber;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: textColor),
        const SizedBox(width: 4),
        Text(
          errorMessage ?? text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    ),
  );
}

Text textSmallGray(
  BuildContext context,
  String content, {
  double? opacity = 0.6,
  double fontSize = 12,
  double lineHeight = 1.5,
  TextAlign textAlign = TextAlign.left,
  int maxLines = 1,
  TextOverflow overflow = TextOverflow.ellipsis,
}) {
  return Text(
    content,
    overflow: overflow,
    maxLines: maxLines,
    textAlign: textAlign,
    style: TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    ),
  );
}

void showSearchContactsPage(BuildContext context, List<Contact> contactList) {
  var input = '';
  showSearch(
    context: context,
    delegate: SearchPage(
      onQueryUpdate: (value) {
        input = value;
      },
      searchLabel: 'Search Friend',
      items: contactList,
      suggestion: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () async {
                final clipboardData = await Clipboard.getData('text/plain');
                if (clipboardData != null) {
                  final pastedText = clipboardData.text;
                  if (pastedText != null && pastedText != '') {
                    await Get.bottomSheet(
                      AddtoContactsPage(pastedText),
                      isScrollControlled: true,
                      ignoreSafeArea: false,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                    );
                  } else {
                    EasyLoading.showToast('Clipboard is empty');
                  }
                }
              },
              child: const Text('Add to contacts from clipboard'),
            ),
          ],
        ),
      ),
      failure: InkWell(
        child: Center(
          child: Column(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.2,
              ),
              const Text(
                'Not found in local, but you can add him/her to contacts.',
              ),
              const SizedBox(
                height: 20,
              ),
              FilledButton(
                onPressed: () async {
                  await Get.bottomSheet(
                    AddtoContactsPage(input),
                    isScrollControlled: true,
                    ignoreSafeArea: false,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Add to contacts',
                ),
              ),
            ],
          ),
        ),
      ),
      builder: (contact) => ListTile(
        onTap: () async {},
        leading: Utils.getRandomAvatar(contact.pubkey, contact: contact),
        title: Text(
          contact.displayName,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Text(
          // contact.npubkey.toString(),
          '${contact.npubkey.substring(0, 18)}...${contact.npubkey.substring(contact.npubkey.length - 18)}',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        dense: true,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.black12, width: 0.1),
          borderRadius: BorderRadius.circular(0),
        ),
      ),
      filter: (contact) => [contact.displayName],
    ),
  );
}

Future<void> showMyQrCode(
  BuildContext context,
  Identity identity,
  bool showMore,
) async {
  // get one time keys from db
  final oneTimeKeys = await Get.find<ChatxService>().getOneTimePubkey(
    identity.id,
  );
  // every time create one, due to need update signalKeyId
  late SignalId signalId;
  try {
    signalId = await SignalIdService.instance.createSignalId(identity.id);
  } catch (e, s) {
    final msg = Utils.getErrorMessage(e);
    logger.e('signalId: $e', error: e, stackTrace: s);
    EasyLoading.showError(msg);
    return;
  }

  Get.bottomSheet(
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
    ),
    MyQRCode(
      title: identity.displayName,
      identity: identity,
      oneTimeKey: oneTimeKeys.first.pubkey,
      signalId: signalId,
      showMore: showMore,
      time: RoomUtil.getValidateTime(),
      isOneTime: true,
      onTap: Get.back,
    ),
    ignoreSafeArea: false,
    isScrollControlled: true,
  );
}

Widget pageLoadingSpinKit({String title = 'Loading...'}) {
  return Center(
    child: Wrap(
      direction: Axis.vertical,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const SizedBox(
          width: 100,
          height: 100,
          child: SpinKitWave(
            color: Color.fromARGB(255, 141, 123, 243),
            size: 40,
          ),
        ),
        Text(title),
      ],
    ),
  );
}
