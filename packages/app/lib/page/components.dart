// ignore_for_file: use_build_context_synchronously

import 'package:app/global.dart';
import 'package:app/models/nostr_event_status.dart';
import 'package:app/models/models.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/chat/create_contact_page.dart';
import 'package:app/models/signal_id.dart';

import 'package:app/page/setting/my_qrcode.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/signalId.service.dart';
import 'package:app/utils.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:search_page/search_page.dart';
import 'package:settings_ui/settings_ui.dart';

import '../controller/home.controller.dart';
import '../service/contact.service.dart';
import '../service/room.service.dart';

Widget centerLoadingComponent([String title = 'loading']) {
  return Center(
      child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      const CircularProgressIndicator(),
      const SizedBox(height: 16.0),
      Text(
        title,
        style: const TextStyle(color: Colors.grey, fontSize: 16.0),
      ),
    ],
  ));
}

textP(String title, [Color? color]) {
  return Text(
    title,
    style: TextStyle(
      fontSize: 16, color: color,
      // overflow: TextOverflow.ellipsis
    ),
  );
}

textDescription(String title, BuildContext context) {
  return Text(
    title,
    style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
  );
}

errorText(String title) {
  return Text(
    title,
    style: TextStyle(color: Colors.red.shade400),
  );
}

Widget genQRImage(String content,
    {double size = 300,
    double embeddedImageSize = 60,
    Color backgroundColor = Colors.white,
    ImageProvider<Object>? embeddedImage}) {
  return QrImageView(
    data: content,
    gapless: false,
    backgroundColor: backgroundColor,
    // padding: const EdgeInsets.all(5.0),
    embeddedImage: embeddedImage,
    embeddedImageStyle:
        QrEmbeddedImageStyle(size: Size(embeddedImageSize, embeddedImageSize)),
    size: size,
  );
}

settingInfoCopy(String title, String content, [Icon? icon]) {
  return SettingsTile(
    leading: icon,
    title: Text(title),
    value: textP(content),
    onPressed: (context) {
      Clipboard.setData(ClipboardData(text: title));
      Get.snackbar('Success', 'Copied to clipboard',
          snackPosition: SnackPosition.BOTTOM);
    },
  );
}

Future<void> showDeleteMsgDialog(BuildContext context, Room room) async {
  String title = "Clear chat history?";
  return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          content: Text(title,
              style: const TextStyle(fontSize: 20.0),
              textAlign: TextAlign.center),
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
                'Clear',
              ),
              onPressed: () async {
                Get.back();
                await RoomService().deleteRoomMessage(room);
                Get.find<HomeController>()
                    .loadIdentityRoomList(room.identityId);
              },
            )
          ],
        );
      });
}

getAppBarFlexibleSpace() {
  var colors = Get.isDarkMode
      ? [Colors.black, Colors.black]
      : [const Color(0xffededed), const Color(0xffe6e1e5)];
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // colors: [Colors.blue, Colors.purple],
          colors: colors),
    ),
  );
}

List futuresTitle = [
  'End-to-End Encryption',
  'Customizable Relay Servers',
  'Multiple Identity',
  'Local Data Storage',
  'Privacy First'
];
List futuresSubtitle = [
  'Keychat uses the Double Ratchet Algorithm of Signal protocol to encrypt and decrypt every message. Achieving forward and backward secrecy of messages.',
  'Configurable relay server or deploy your own. Relay is a lightweight service that can store and transmit encrypted data.',
  'Encourage to use multiple identities in Keychat for different chat scenarios, such as private and public group chats.',
  'All contact, private key, configuration and other data are stored on your device without server interaction.',
  'We don\'t provide any servers, collect any account or device data, or any runtime logs. Your data is entirely stored locally, ensuring perfect protection of your privacy.'
];
showModalBottomSheetKeyChatFetures(BuildContext context) {
  List<Widget> ws = [];
  for (var i = 0; i < futuresTitle.length; i++) {
    ws.add(ListTile(
        leading: CircleAvatar(child: Text((i + 1).toString())),
        title: Text(futuresTitle[i]),
        subtitle: Text(futuresSubtitle[i])));
  }
  showModalBottomSheetWidget(
      context,
      'Why Keychat?',
      SafeArea(
          bottom: false,
          child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              children: ws)));
}

// almost fullscreen
showModalBottomSheetWidget(BuildContext context, String title, Widget body,
    {bool showAppBar = true, Function? callback}) {
  if (!showAppBar) {
    showCupertinoModalBottomSheet(
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
                          Get.back();
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
              ),
            ));
    return;
  }
  showCupertinoModalBottomSheet(
      context: context,
      builder: (context) => Scaffold(
          appBar: getSheetAppBar(context, title, callback), body: body));
}

getSheetAppBar(BuildContext context, String title, [Function? callback]) {
  return AppBar(
    leading: const SizedBox(),
    title: Text(title),
    centerTitle: true,
    actions: [
      IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          Get.back();
          if (callback != null) callback();
        },
      )
    ],
  );
}

// Half height, suitable for content with Obx, modal without appBar
Future show300hSheetWidget(BuildContext context, String title, Widget body) {
  return showCupertinoModalBottomSheet(
    context: context,
    barrierColor: Get.isDarkMode
        ? Colors.black.withOpacity(0.65)
        : Colors.black.withOpacity(0.35),
    builder: (context) => Container(
      constraints: BoxConstraints(maxHeight: Get.height / 2, minHeight: 200),
      child: body,
    ),
  );
}

// Adaptive height, not suitable for content with OBX
showFitSheetWidget(BuildContext context, String title, List<Widget> bodys,
    {bool showAppBar = true, Function? callback}) {
  showCupertinoModalBottomSheet(
    context: context,
    barrierColor: Get.isDarkMode
        ? Colors.black.withOpacity(0.65)
        : Colors.black.withOpacity(0.35),
    builder: (context) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (showAppBar) getSheetAppBar(context, title, callback),
          ...bodys,
          const SizedBox(
            height: 30,
          )
        ])),
  );
}

getGroupInfoBottomSheetWidget(BuildContext context) {
  showFitSheetWidget(
    context,
    'Group Type Info',
    [
      ListTile(
        title: const Text('1. Medium Group'),
        subtitle: Text(RoomUtil.getGroupModeDescription(GroupType.kdf)),
      ),
      ListTile(
        title: const Text('2. Small Group'),
        subtitle: Text(RoomUtil.getGroupModeDescription(GroupType.sendAll)),
      ),
    ],
  );
}

Widget codeSnippet(String text) {
  return Text(
    text,
    style: TextStyle(
      fontFamily: "Roboto Mono",
      fontSize: 16,
      color: Colors.black,
      backgroundColor: Colors.grey[200],
    ),
  );
}

Widget relayStatusList(BuildContext context, List<NostrEventStatus> ess) {
  if (ess.isEmpty) return const SizedBox();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Message Status', style: Theme.of(context).textTheme.titleMedium),
      ...ess.map((NostrEventStatus es) => ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(es.relay, style: Theme.of(context).textTheme.titleSmall),
          subtitle: es.error != null
              ? Text(es.error!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.red))
              : (es.sendStatus != EventSendEnum.success
                  ? Text(es.sendStatus.name,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.red))
                  : null),
          trailing: es.ecashAmount > 0
              ? Text('-${es.ecashAmount} ${es.ecashName}')
              : null,
          leading: RoomUtil.getStatusArrowIcon(1,
              es.sendStatus == EventSendEnum.success ? 1 : 0, es.isReceive))),
    ],
  );
}

Widget lineWidget(BuildContext context, double size, [Widget? widget]) {
  return Container(
    width: double.infinity,
    height: size,
    alignment: Alignment.centerLeft,
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade900
        : Colors.grey.shade300,
    child: widget,
  );
}

Text textSmallGray(BuildContext context, String content,
    {double? opacity = 0.6,
    double fontSize = 12,
    double lineHeight = 1.5,
    overflow = TextOverflow.ellipsis}) {
  return Text(content,
      overflow: overflow,
      style: TextStyle(
          fontSize: fontSize,
          height: lineHeight,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)));
}

void copyAllContacts(List<Contact> contactList) {
  final List<String> allContacts = [];
  allContacts.add('ContactName \t ContactAddress');

  for (var contact in contactList) {
    String contactInfo = '${contact.displayName} \t ${contact.npubkey}';
    allContacts.add(contactInfo);
  }

  final String allContactsString = allContacts.join('\n');

  Clipboard.setData(ClipboardData(text: allContactsString));

  EasyLoading.showToast('Copied all contacts to clipboard');
}

showSearchContactsPage(BuildContext context, List<Contact> contactList) {
  String input = "";
  showSearch(
      context: context,
      delegate: SearchPage(
          onQueryUpdate: (value) {
            input = value;
          },
          searchLabel: "Search Friend",
          items: contactList,
          suggestion: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                OutlinedButton(
                    onPressed: () async {
                      final clipboardData =
                          await Clipboard.getData('text/plain');
                      if (clipboardData != null) {
                        final pastedText = clipboardData.text;
                        if (pastedText != null && pastedText != '') {
                          Get.off(() => AddtoContactsPage(
                                pastedText,
                              ));
                        } else {
                          EasyLoading.showToast('Clipboard is empty');
                        }
                      }
                    },
                    child: const Text('Add to contacts from clipboard'))
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
                    'Not found in local, but you can add him/her to contacts.'),
                const SizedBox(
                  height: 20,
                ),
                FilledButton(
                  onPressed: () async {
                    Get.off(() => AddtoContactsPage(input));
                  },
                  child: const Text(
                    'Add to contacts',
                  ),
                ),
              ],
            )),
          ),
          builder: (contact) => ListTile(
                onTap: () async {},
                leading: getRandomAvatar(contact.pubkey, height: 40, width: 40),
                title: Text(
                  contact.displayName.toString(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: Text(
                  // contact.npubkey.toString(),
                  "${contact.npubkey.substring(0, 18)}...${contact.npubkey.substring(contact.npubkey.length - 18)}",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                dense: true,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.black12, width: 0.1),
                  borderRadius: BorderRadius.circular(0),
                ),
              ),
          filter: (contact) => [contact.displayName.toString()]));
}

showSearchContactsPage2(BuildContext context) async {
  Identity identity = Get.find<HomeController>().getSelectedIdentity();
  List<Contact> contactList =
      await ContactService().getContactList(identity.id);
  String input = "";
  showSearch(
      context: context,
      delegate: SearchPage(
          onQueryUpdate: (value) {
            input = value;
          },
          searchLabel: "Search Friend",
          items: contactList,
          suggestion: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                OutlinedButton(
                    onPressed: () async {
                      final clipboardData =
                          await Clipboard.getData('text/plain');
                      if (clipboardData != null) {
                        final pastedText = clipboardData.text;
                        if (pastedText != null && pastedText != '') {
                          Get.off(() => AddtoContactsPage(input));
                        } else {
                          EasyLoading.showToast('Clipboard is empty');
                        }
                      }
                    },
                    child: const Text('Add to contacts from clipboard'))
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
                    'Not found in local, but you can add him/her to contacts.'),
                const SizedBox(
                  height: 20,
                ),
                FilledButton(
                  onPressed: () async {
                    Get.off(() => AddtoContactsPage(input));
                  },
                  child: const Text(
                    'Add to contacts',
                  ),
                ),
              ],
            )),
          ),
          builder: (contact) => ListTile(
                onTap: () async {},
                leading: getRandomAvatar(contact.pubkey, height: 40, width: 40),
                title: Text(
                  contact.displayName.toString(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: Text(
                  // contact.npubkey.toString(),
                  "${contact.npubkey.substring(0, 18)}...${contact.npubkey.substring(contact.npubkey.length - 18)}",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                dense: true,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.black12, width: 0.1),
                  borderRadius: BorderRadius.circular(0),
                ),
              ),
          filter: (contact) => [contact.displayName.toString()]));
}

Future showMyQrCode(
    BuildContext context, Identity identity, bool showMore) async {
  // get one time keys from db
  List<Mykey> oneTimeKeys =
      await Get.find<ChatxService>().getOneTimePubkey(identity.id);
  // every time create one, due to need update signalKeyId
  late SignalId signalId;
  try {
    signalId = await SignalIdService.instance.createSignalId(identity.id);
  } catch (e, s) {
    String msg = Utils.getErrorMessage(e);
    logger.e(e.toString(), error: e, stackTrace: s);
    EasyLoading.showError(msg);
    return;
  }

  int expiredTime = DateTime.now().millisecondsSinceEpoch +
      KeychatGlobal.oneTimePubkeysLifetime * 3600 * 1000;

  showModalBottomSheetWidget(
      context,
      identity.displayName,
      MyQRCode(
        identity: identity,
        oneTimeKey: oneTimeKeys.first.pubkey,
        signalId: signalId,
        showMore: showMore,
        time: expiredTime,
        isOneTime: true,
        onTap: Get.back,
      ));
}

Widget pageLoadingSpinKit() {
  return const Center(
      child: SizedBox(
          width: 100,
          height: 100,
          child: SpinKitWave(
            color: Color.fromARGB(255, 141, 123, 243),
            size: 40.0,
          )));
}
