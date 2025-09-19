import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/room.dart';
import 'package:app/page/components.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/signal_chat.service.dart';
import 'package:app/utils.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class RecommendBots extends StatelessWidget {
  const RecommendBots(this.identity, this.rooms, {super.key});
  final Identity identity;
  final List<Room> rooms;

  @override
  Widget build(BuildContext context) {
    if (identity.name.toLowerCase() != KeychatGlobal.bot.toLowerCase()) {
      return Container();
    }
    final homeController = Get.find<HomeController>();
    final List npubs = rooms.map((e) => e.npub).toList();

    return Obx(() => homeController.recommendBots.isEmpty
        ? Container()
        : ListView.separated(
            separatorBuilder: (context2, index) => Divider(
                height: 1,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.05)),
            itemCount: homeController.recommendBots.length,
            shrinkWrap: true,
            padding: const EdgeInsets.only(),
            itemBuilder: (context, index) {
              final bot = homeController.recommendBots[index] as Map;
              if (npubs.contains(bot['npub'])) {
                return Container();
              }
              return ListTile(
                leading: Utils.getAvatorByName(bot['name'], width: 50),
                key: Key('room:${bot['npub']}'),
                onLongPress: () async {},
                onTap: () async {},
                title: Text(
                  bot['name'],
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: textSmallGray(context, bot['description']),
                trailing: OutlinedButton(
                    onPressed: () async {
                      final hexPubkey =
                          rust_nostr.getHexPubkeyByBech32(bech32: bot['npub']);

                      final room = await RoomService.instance.getOrCreateRoom(
                          hexPubkey,
                          identity.secp256k1PKHex,
                          RoomStatus.enabled,
                          contactName: bot['name'],
                          type: RoomType.bot,
                          identity: identity);
                      await SignalChatService.instance
                          .sendHelloMessage(room, identity);
                      await Utils.toNamedRoom(room);
                    },
                    child: const Text('Add')),
              );
            }));
  }
}
