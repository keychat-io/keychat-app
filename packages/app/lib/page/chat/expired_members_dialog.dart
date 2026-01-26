import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/models/room.dart';
import 'package:keychat/models/room_member.dart';
import 'package:keychat/service/mls_group.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

/// Dialog to handle expired members in a MLS group
class ExpiredMembersDialog extends StatelessWidget {
  const ExpiredMembersDialog({
    required this.expiredMembers,
    required this.room,
    super.key,
  });
  final List<RoomMember> expiredMembers;
  final Room room;

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('Expired Key Packages'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          const Text(
            'The following members have expired key packages:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          ...expiredMembers.map(_buildMemberItem),
          const SizedBox(height: 8),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Get.back<void>(),
          child: const Text('Cancel'),
        ),
        FutureBuilder(
          future: () {
            final identity = room.getIdentity();
            return room.checkAdminByIdPubkey(identity.secp256k1PKHex);
          }(),
          builder: (context, snapshot) {
            final isAdmin = snapshot.data ?? false;
            if (isAdmin) {
              return CupertinoDialogAction(
                onPressed: () async {
                  Get.back<void>();
                  await _handleBatchRemove();
                },
                child: const Text('Remove Members'),
              );
            }
            return CupertinoDialogAction(
              onPressed: () async {
                Get.back<void>();
                await _handleNotifyUpdate();
              },
              child: const Text('Notify Group Admin'),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMemberItem(RoomMember member) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Utils.getRandomAvatar(
        member.idPubkey,
        contact: member.contact,
      ),
      title: Text(
        member.displayName,
        overflow: TextOverflow.ellipsis,
      ),
      dense: true,
      subtitle: Text(
        rust_nostr.getBech32PubkeyByHex(hex: member.idPubkey),
        style: const TextStyle(fontSize: 12),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Future<void> _handleBatchRemove() async {
    try {
      await EasyLoading.show(status: 'Removing members...');

      await MlsGroupService.instance.removeMembers(room, expiredMembers);

      await EasyLoading.showSuccess('Members removed successfully');
    } catch (e) {
      final msg = Utils.getErrorMessage(e);
      logger.e(msg, error: e);
      await EasyLoading.showError('Failed: $msg');
    }
  }

  Future<void> _handleNotifyUpdate() async {
    await RoomService.instance.sendMessage(
      room,
      '''
[System] Hi admin, an error occurred while adding a new member. The following members have expired key packages and need to be removed:

${expiredMembers.map((m) => "• ${m.displayName} (${rust_nostr.getBech32PubkeyByHex(hex: m.idPubkey)})").join('\n')}

Please remove these members to continue.
      ''',
    );
  }
}
