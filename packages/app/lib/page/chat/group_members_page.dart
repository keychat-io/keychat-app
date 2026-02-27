import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/controller/chat.controller.dart';
import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:keychat/service/contact.service.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

/// Page for viewing all group members in a scrollable list.
///
/// Displays all members of a group in a vertical list with ListTile layout
/// showing avatar, name, admin badge, pubkey (tap to copy), and status badges.
/// Supports member interactions: viewing profiles, initiating private chats,
/// and (for admins) removing members.
class GroupMembersPage extends StatefulWidget {
  const GroupMembersPage({
    required this.roomId,
    super.key,
  });

  final int roomId;

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  late ChatController cc;
  late Identity identity;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    final controller = RoomService.getController(widget.roomId);
    if (controller == null) {
      Get.back<void>();
      return;
    }
    cc = controller;
    identity = cc.roomObs.value.getIdentity();
    final myRoomMember = cc.getMemberByIdPubkey(identity.secp256k1PKHex);
    isAdmin = myRoomMember?.isAdmin ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text('Group Members (${cc.members.length})'),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await RoomUtil.showAddMemberToGroupDialog(
                cc.roomObs.value,
                identity,
              );
            },
            icon: const Icon(CupertinoIcons.plus_circle_fill),
          ),
        ],
      ),
      body: Obx(
        () {
          final members = cc.members.values.toList();
          if (members.isEmpty) {
            return Center(
              child: Text(
                'No members',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          // Normalize MLS member status: members without a profile name
          // are considered still in "inviting" state
          if (cc.roomObs.value.isMLSGroup) {
            for (final rm in members) {
              if ((rm.name == null || rm.name == rm.idPubkey) &&
                  rm.status == UserStatusType.invited) {
                rm.status = UserStatusType.inviting;
              }
            }
          }

          // Sort admins to the top of the list
          members.sort((a, b) {
            if (a.isAdmin && !b.isAdmin) return -1;
            if (!a.isAdmin && b.isAdmin) return 1;
            return 0;
          });

          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: members.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
            ),
            itemBuilder: (context, index) {
              final rm = members[index];
              // Update self member avatar and name if needed
              if (rm.idPubkey == identity.secp256k1PKHex) {
                rm.contact?.avatarLocalPath = identity.avatarLocalPath;
                rm.contact?.name = identity.displayName;
              }

              return _buildMemberListItem(rm);
            },
          );
        },
      ),
    );
  }

  /// Builds a member list item using ListTile.
  ///
  /// Displays member avatar, name, pubkey, and status badges.
  /// Supports multiple interactions:
  /// - Tap to open member dialog with actions
  /// - Long press to show quick actions menu
  /// - Tap on pubkey to copy it
  Widget _buildMemberListItem(RoomMember rm) {
    final npub = rust_nostr.getBech32PubkeyByHex(
      hex: rm.idPubkey,
    );

    return ListTile(
      dense: true,
      key: Key(rm.idPubkey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: () async {
        if (identity.secp256k1PKHex == rm.idPubkey) {
          await EasyLoading.showToast("It's me");
          return;
        }

        // Get or create contact for member
        final contact = await ContactService.instance.getOrCreateContact(
          identityId: cc.roomObs.value.identityId,
          pubkey: rm.idPubkey,
          name: rm.name,
          autoCreateFromGroup: true,
        );

        // Show member details dialog
        _showMemberDialog(rm, contact);
      },
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Utils.getRandomAvatar(
          rm.idPubkey,
          contact: rm.contact,
          size: 56,
        ),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              rm.displayName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Single badge slot aligned to the right
          _MemberBadgeSlot(
            badge: _resolveMemberBadge(rm),
          ),
        ],
      ),
      subtitle: GestureDetector(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: npub));
          await EasyLoading.showToast('Pubkey copied');
        },
        child: Text(
          npub,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
          ),
        ),
      ),
      trailing: identity.secp256k1PKHex == rm.idPubkey
          ? null
          : IconButton(
              icon: Icon(
                Icons.more_vert,
                color: Colors.grey.shade400,
                size: 20,
              ),
              onPressed: () async {
                if (identity.secp256k1PKHex == rm.idPubkey) {
                  return;
                }
                final contact = await ContactService.instance
                    .getOrCreateContact(
                      identityId: cc.roomObs.value.identityId,
                      pubkey: rm.idPubkey,
                      name: rm.name,
                      autoCreateFromGroup: true,
                    );
                _showMemberDialog(rm, contact);
              },
            ),
    );
  }

  /// Resolves the highest-priority badge for a member.
  ///
  /// Priority: admin > me > inviting > key expired.
  Widget? _resolveMemberBadge(RoomMember rm) {
    if (rm.isAdmin) {
      return RoomUtil.adminBadge(context);
    }
    if (rm.idPubkey == identity.secp256k1PKHex) {
      return RoomUtil.meBadge(context);
    }
    if (rm.status == UserStatusType.inviting) {
      return RoomUtil.invitingBadge(context);
    }
    if (rm.mlsPKExpired) {
      return RoomUtil.keyExpiredBadge(context);
    }
    return null;
  }

  /// Shows a dialog with member actions and information.
  void _showMemberDialog(RoomMember rm, Contact contact) {
    RoomUtil.showGroupMemberDialog(
      room: cc.roomObs.value,
      rm: rm,
      contact: contact,
      isAdmin: isAdmin,
    );
  }
}

/// Renders a fixed-size slot for a member badge to keep alignment stable.
class _MemberBadgeSlot extends StatelessWidget {
  const _MemberBadgeSlot({required this.badge});

  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    if (badge == null) {
      return const SizedBox(width: 56, height: 16);
    }

    return SizedBox(
      width: 56,
      height: 16,
      child: Center(child: badge),
    );
  }
}
