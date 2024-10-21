import 'package:app/controller/home.controller.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/room.dart';
import 'package:app/page/common.dart';
import 'package:app/page/components.dart';
import 'package:app/service/room.service.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class RecommendBots extends StatefulWidget {
  final Identity identity;
  final List<Room> rooms;
  const RecommendBots(this.identity, this.rooms, {super.key});

  @override
  _RecommendBotsState createState() => _RecommendBotsState();
}

class _RecommendBotsState extends State<RecommendBots> {
  List npubs = [];
  HomeController homeController = Get.find<HomeController>();
  @override
  void initState() {
    super.initState();
    setState(() {
      npubs = widget.rooms.map((e) => e.npub).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => homeController.recommendBots.isEmpty
        ? Container()
        : ListView.separated(
            separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withOpacity(0.05),
                ),
            itemCount: homeController.recommendBots.length,
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 0),
            itemBuilder: (context, index) {
              Map bot = homeController.recommendBots[index];
              if (npubs.contains(bot['npub'])) {
                return Container();
              }
              return ListTile(
                leading: getAvatorByName(bot['name'], width: 50),
                key: Key('room:${bot['npub']}'),
                onLongPress: () async {},
                onTap: () async {},
                title: Text(
                  bot['name'],
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: textSmallGray(context, bot['description']),
                trailing: FilledButton(
                    onPressed: () async {
                      String hexPubkey =
                          rust_nostr.getHexPubkeyByBech32(bech32: bot['npub']);

                      await RoomService().getOrCreateRoom(hexPubkey,
                          widget.identity.secp256k1PKHex, RoomStatus.enabled,
                          contactName: bot['name'],
                          type: RoomType.bot,
                          identity: widget.identity);
                    },
                    child: const Text('Add')),
              );
            }));
  }
}
