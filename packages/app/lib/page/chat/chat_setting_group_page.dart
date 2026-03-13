import 'package:keychat/app.dart';
import 'package:keychat/controller/chat.controller.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:keychat/page/chat/group_members_page.dart';
import 'package:keychat/page/chat/search_messages_page.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/page/routes.dart';
import 'package:keychat/service/contact.service.dart';
import 'package:keychat/service/group.service.dart';
import 'package:keychat/service/mls_group.service.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';
import 'package:settings_ui/settings_ui.dart';

class ChatSettingGroupPage extends StatefulWidget {
  const ChatSettingGroupPage({super.key, this.roomId});
  final int? roomId;

  @override
  _ChatSettingGroupPageState createState() => _ChatSettingGroupPageState();
}

class _ChatSettingGroupPageState extends State<ChatSettingGroupPage> {
  HomeController homeController = Get.find<HomeController>();
  late ChatController cc;
  late TextEditingController textEditingController;
  late String myAlias = '';
  late Identity identity;
  bool isAdmin = false;
  bool _isUpdatingNickname = false;
  @override
  void initState() {
    final roomId = widget.roomId ?? int.parse(Get.parameters['id']!);
    final controller = RoomService.getController(roomId);
    if (controller == null) {
      Get.back<void>();
      return;
    }
    cc = controller;
    super.initState();
    identity = cc.roomObs.value.getIdentity();
    final myRoomMember = cc.getMemberByIdPubkey(identity.secp256k1PKHex);
    myAlias = myRoomMember?.name ?? cc.roomObs.value.getIdentity().displayName;
    isAdmin = myRoomMember?.isAdmin ?? false;
    textEditingController = TextEditingController(text: cc.roomObs.value.name);
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            "${cc.roomObs.value.name ?? ""}(${cc.enableMembers.length})",
          ),
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
        () => SettingsList(
          platform: DevicePlatform.iOS,
          contentPadding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          sections: [
            SettingsSection(
              tiles: [
                CustomSettingsTile(
                  child: getImageGridView(cc.members.values.toList()),
                ),
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile(
                  title: const Text('ID'),
                  leading: const Icon(CupertinoIcons.person_3),
                  value: textSmallGray(
                    context,
                    getPublicKeyDisplay(
                      cc.roomObs.value.toMainPubkey,
                      4,
                    ),
                    fontSize: 16,
                  ),
                  onPressed: (context) {
                    Clipboard.setData(
                      ClipboardData(
                        text: cc.roomObs.value.toMainPubkey,
                      ),
                    );
                    EasyLoading.showToast('Copied');
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(CupertinoIcons.chart_bar),
                  title: const Text('Mode'),
                  value: textP(
                    RoomUtil.getGroupModeName(
                      cc.roomObs.value.groupType,
                    ),
                  ),
                  onPressed: (_) async {
                    if (cc.roomObs.value.isSendAllGroup) {
                      await RoomUtil.signalChatDialog(
                        context,
                        RoomUtil.getDescByGroupType(
                          cc.roomObs.value.groupType,
                        ),
                      );
                      return;
                    }

                    if (cc.roomObs.value.isMLSGroup) {
                      await RoomUtil.mlsChatDialog(
                        context,
                        RoomUtil.getDescByGroupType(
                          cc.roomObs.value.groupType,
                        ),
                      );
                      return;
                    }
                  },
                ),
                if (isAdmin)
                  SettingsTile.navigation(
                    title: const Text('Group Name'),
                    leading: const Icon(CupertinoIcons.flag),
                    value: textP(
                      cc.roomObs.value.name ?? cc.roomObs.value.toMainPubkey,
                      maxLength: 15,
                    ),
                    onPressed: (context) async {
                      _showGroupNameDialog();
                    },
                  )
                else
                  SettingsTile(
                    title: const Text('Group Name'),
                    leading: const Icon(CupertinoIcons.flag),
                    value: textP(
                      cc.roomObs.value.name ?? cc.roomObs.value.toMainPubkey,
                    ),
                  ),

                if (cc.roomObs.value.isMLSGroup)
                  SettingsTile(
                    title: const Text('Relay'),
                    leading: const Icon(CupertinoIcons.globe),
                    value: textSmallGray(
                      context,
                      maxLines: 10,
                      cc.roomObs.value.sendingRelays.join('\n'),
                    ),
                    onPressed: (context) {},
                  ),
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile.navigation(
                  title: const Text('My Alias'),
                  leading: const Icon(CupertinoIcons.person),
                  value: textP(myAlias, maxLength: 15),
                  onPressed: _handleUpdateMyNickname,
                ),
                if (cc.roomObs.value.isMLSGroup)
                  SettingsTile.navigation(
                    title: const Text('Update My Group Key'),
                    leading: const Icon(Icons.refresh),
                    onPressed: _handleUpdateMyGroupKey,
                  ),
              ],
            ),
            SettingsSection(
              tiles: [
                RoomUtil.pinRoomSection(cc),
                if (!cc.roomObs.value.isSendAllGroup)
                  SettingsTile.switchTile(
                    title: const Text('Show Addresses'),
                    initialValue: cc.showFromAndTo.value,
                    onToggle: (value) async {
                      cc.showFromAndTo.toggle();
                      Get.back<void>();
                    },
                    leading: const Icon(CupertinoIcons.mail),
                  ),
                if (cc.roomObs.value.isShareKeyGroup ||
                    cc.roomObs.value.isKDFGroup ||
                    cc.roomObs.value.isMLSGroup)
                  RoomUtil.muteSection(cc),
                SettingsTile.navigation(
                  leading: const Icon(CupertinoIcons.search),
                  title: const Text('Search History'),
                  onPressed: (context) async {
                    await Get.to<void>(
                      () => SearchMessagesPage(
                        roomId: cc.roomObs.value.id,
                      ),
                      id: GetPlatform.isDesktop ? GetXNestKey.room : null,
                    );
                  },
                ),
              ],
            ),
            payToRelaySection(),
            dangerZoom(context),
          ],
        ),
      ),
    );
  }

  SettingsSection receiveInPostOffice() {
    return SettingsSection(
      title: const Text('Message Relays'),
      tiles: [
        SettingsTile(
          leading: const Icon(CupertinoIcons.up_arrow),
          title: const Text('SendTo'),
          value: Flexible(
            child: Text(
              cc.roomObs.value.sendingRelays.isNotEmpty
                  ? cc.roomObs.value.sendingRelays.join(',')
                  : 'All',
            ),
          ),
        ),
        SettingsTile(
          leading: const Icon(CupertinoIcons.down_arrow),
          title: const Text('ReceiveFrom'),
          value: Flexible(
            child: Text(
              cc.roomObs.value.receivingRelays.isNotEmpty
                  ? cc.roomObs.value.receivingRelays.join(',')
                  : 'All',
            ),
          ),
        ),
      ],
    );
  }

  SettingsSection payToRelaySection() {
    return SettingsSection(
      tiles: [
        RoomUtil.mediaSection(cc),
        SettingsTile.navigation(
          leading: const Icon(
            CupertinoIcons.bitcoin,
          ),
          title: const Text('Pay to Relay'),
          onPressed: (context) async {
            Get.toNamed<void>(
              Routes.roomSettingPayToRelay.replaceFirst(
                ':id',
                cc.roomObs.value.id.toString(),
              ),
              id: GetPlatform.isDesktop ? GetXNestKey.room : null,
            );
          },
        ),
      ],
    );
  }

  Widget getImageGridView(List<RoomMember> members) {
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
    final allMembers = members
        .where(
          (e) =>
              e.status == UserStatusType.invited ||
              e.status == UserStatusType.inviting,
        )
        .toList();

    if (allMembers.length > 8) {
      return _buildMembersSummaryCard(allMembers);
    }

    // Show responsive grid preview for up to 8 members
    return Padding(
      padding: const EdgeInsets.all(6),
      child: ResponsiveGridList(
        minItemsPerRow: 3,
        maxItemsPerRow: 8,
        minItemWidth: 68,
        horizontalGridSpacing: 6,
        verticalGridSpacing: 6,
        listViewBuilderOptions: ListViewBuilderOptions(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        ),
        children: allMembers.map((rm) {
          // Update self member info if needed
          if (rm.idPubkey == identity.secp256k1PKHex) {
            rm.contact?.avatarLocalPath = identity.avatarLocalPath;
            rm.contact?.name = identity.displayName;
          }

          return _buildMemberGridItem(rm);
        }).toList(),
      ),
    );
  }

  /// Builds a summary card when member count exceeds threshold.
  ///
  /// Shows member count, abnormal status statistics, and a link to the
  /// dedicated group members page for viewing all members in a list.
  /// Counts members with issues like pending invitations and expired keys.
  Widget _buildMembersSummaryCard(List<RoomMember> members) {
    final memberCount = members.length;

    // Count members with abnormal status
    var invitingCount = 0;
    var expiredKeyCount = 0;

    for (final rm in members) {
      if (rm.status == UserStatusType.inviting) {
        invitingCount++;
      }
      if (rm.mlsPKExpired) {
        expiredKeyCount++;
      }
    }

    final hasAbnormalStatus = invitingCount > 0 || expiredKeyCount > 0;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Card(
        child: InkWell(
          onTap: () {
            Get.to<void>(
              () => GroupMembersPage(roomId: cc.roomObs.value.id),
              id: GetPlatform.isDesktop ? GetXNestKey.room : null,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group Members',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$memberCount members',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      // Show abnormal status summary if any
                      if (hasAbnormalStatus) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (invitingCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.amber.shade700,
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  '$invitingCount inviting',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.amber.shade700,
                                        fontSize: 10,
                                      ),
                                ),
                              ),
                            if (expiredKeyCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.red.shade700,
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  '$expiredKeyCount key expired',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.red.shade700,
                                        fontSize: 10,
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds an individual member grid item with a single badge slot.
  ///
  /// Displays member avatar, name, and the highest-priority badge.
  /// Tapping opens a dialog with member actions (chat, copy pubkey, remove).
  Widget _buildMemberGridItem(RoomMember rm) {
    return _MemberGridItem(
      rm: rm,
      badge: _resolveMemberBadge(rm),
      onTap: () async {
        if (identity.secp256k1PKHex == rm.idPubkey) {
          await EasyLoading.showToast("It's me");
          return;
        }
        final contact = await ContactService.instance.getOrCreateContact(
          identityId: cc.roomObs.value.identityId,
          pubkey: rm.idPubkey,
          name: rm.name,
          autoCreateFromGroup: true,
        );

        _showMemberDialog(rm, contact);
      },
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

  /// Shows a dialog with member details and available actions.
  void _showMemberDialog(RoomMember rm, Contact contact) {
    RoomUtil.showGroupMemberDialog(
      room: cc.roomObs.value,
      rm: rm,
      contact: contact,
      isAdmin: isAdmin,
    );
  }

  SettingsSection dangerZoom(BuildContext context) {
    return SettingsSection(
      tiles: [
        RoomUtil.autoCleanMessage(cc),
        RoomUtil.clearHistory(cc),
        SettingsTile(
          leading: const Icon(
            CupertinoIcons.trash,
            color: Colors.pink,
          ),
          title: Text(
            isAdmin ? 'Disband Group' : 'Leave Group',
            style: const TextStyle(color: Colors.pink),
          ),
          onPressed: _selfExitGroup,
        ),
      ],
    );
  }

  Future<void> _showGroupNameDialog() async {
    await Get.dialog<void>(
      CupertinoAlertDialog(
        title: const Text('Group Name'),
        content: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(top: 15),
          child: TextField(
            controller: textEditingController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'New Group Name',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              Get.back<void>();
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final newName = textEditingController.text;
              if (newName.isEmpty || newName == cc.roomObs.value.name) {
                EasyLoading.showToast('Please enter a new name');
                return;
              }

              try {
                EasyLoading.show(status: 'Processing...');

                await GroupService.instance.changeRoomName(
                  cc.roomObs.value.id,
                  newName,
                );

                cc.roomObs.value.name = newName;
                cc.roomObs.refresh();
                EasyLoading.showSuccess('Success');
                Get.find<HomeController>().loadIdentityRoomList(
                  cc.roomObs.value.identityId,
                );
                Get.back<void>();
              } catch (e, s) {
                final msg = Utils.getErrorMessage(e);
                EasyLoading.showError(msg);
                logger.e(msg, error: e, stackTrace: s);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _selfExitGroup(BuildContext context) {
    Get.dialog<void>(
      CupertinoAlertDialog(
        title: Text(isAdmin ? 'Disband?' : 'Leave?'),
        content: Text(
          'Are you sure to ${isAdmin ? 'disband' : 'leave'} this group?',
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              Get.back<void>();
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(isAdmin ? 'Disband' : 'Leave'),
            onPressed: () async {
              EasyLoading.show(status: 'Loading...');
              try {
                isAdmin
                    ? await GroupService.instance.dissolveGroup(
                        cc.roomObs.value,
                      )
                    : await GroupService.instance.selfExitGroup(
                        cc.roomObs.value,
                      );
                EasyLoading.showSuccess('Success');
              } catch (e, s) {
                final msg = Utils.getErrorMessage(e);
                logger.e(msg, error: e, stackTrace: s);
                EasyLoading.showError(msg);
                return;
              }
              Get.find<HomeController>().loadIdentityRoomList(
                cc.roomObs.value.identityId,
              );
              Utils.offAllNamedRoom(Routes.root);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdateMyNickname(BuildContext context) async {
    if (cc.roomObs.value.isKDFGroup || cc.roomObs.value.isShareKeyGroup) {
      return;
    }
    final userNameController = TextEditingController(
      text: myAlias,
    );

    await Get.dialog<void>(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return CupertinoAlertDialog(
            title: const Text('My Name'),
            content: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.only(top: 15),
              child: TextField(
                controller: userNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: <Widget>[
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () {
                  Get.back<void>();
                },
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: _isUpdatingNickname
                    ? null
                    : () async {
                        try {
                          final name = userNameController.text.trim();
                          if (name.isEmpty) return;
                          EasyLoading.show(
                            status: 'Processing...',
                          );
                          setDialogState(() {
                            _isUpdatingNickname = true;
                          });
                          final room = await RoomService.instance
                              .getRoomByIdOrFail(cc.roomObs.value.id);
                          if (room.isSendAllGroup) {
                            await GroupService.instance.changeMyNickname(
                              room,
                              name,
                            );
                          } else if (room.isMLSGroup) {
                            final msg = '[System] Update my name to $name';
                            await MlsGroupService.instance.selfUpdateKey(
                              room,
                              extension: {
                                'name': name,
                                'msg': msg,
                              },
                              msg: msg,
                            );
                          }
                          setState(() {
                            myAlias = name;
                          });
                          userNameController.clear();
                          cc.resetMembers();
                          EasyLoading.showSuccess(
                            'Success',
                          );
                          Get.back<void>();
                        } catch (e, s) {
                          logger.e(
                            'Failed to update name',
                            error: e,
                            stackTrace: s,
                          );
                          EasyLoading.showError(
                            'Failed to update name: $e',
                          );
                        } finally {
                          setDialogState(() {
                            _isUpdatingNickname = false;
                          });
                        }
                      },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleUpdateMyGroupKey(BuildContext context) async {
    // Get the room ID to use as part of the storage key
    final storageKey = 'UpdateMyGroupKey:${cc.roomObs.value.id}';
    final lastUpdateTime = Storage.getInt(storageKey);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check if it's been less than a day since the last update
    if (kReleaseMode &&
        lastUpdateTime != null &&
        now - lastUpdateTime < 24 * 60 * 60 * 1000) {
      EasyLoading.showInfo(
        'You can only update once per day.',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    await Get.dialog<void>(
      CupertinoAlertDialog(
        title: const Text('Update My Group Key'),
        content: const Text(
          'Regularly updating my group key makes chats more secure.',
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              Get.back<void>();
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Confirm'),
            onPressed: () async {
              Get.back<void>();
              EasyThrottle.throttle(
                'UpdateMyGroupKey',
                const Duration(seconds: 3),
                () async {
                  try {
                    await EasyLoading.show(
                      status: 'Processing...',
                    );
                    final room = await RoomService.instance.getRoomByIdOrFail(
                      cc.roomObs.value.id,
                    );
                    await MlsGroupService.instance.selfUpdateKey(
                      room,
                      msg: '[System] Update my group key',
                    );

                    // Save the current timestamp when update is successful
                    await Storage.setInt(
                      storageKey,
                      now,
                    );

                    await EasyLoading.showSuccess(
                      'Success',
                    );
                  } catch (e, s) {
                    final msg = Utils.getErrorMessage(
                      e,
                    );
                    await EasyLoading.showError(msg);
                    logger.e(
                      msg,
                      error: e,
                      stackTrace: s,
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Renders a compact group member card used in the member grid.
class _MemberGridItem extends StatelessWidget {
  const _MemberGridItem({
    required this.rm,
    required this.onTap,
    required this.badge,
  });

  final RoomMember rm;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(2),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        key: Key(rm.idPubkey),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Utils.getRandomAvatar(
                rm.idPubkey,
                contact: rm.contact,
                size: 52,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                rm.displayName,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            _buildBadgeSlot(badge),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  /// Builds a fixed-height slot to keep member cards aligned.
  ///
  /// When no badge is provided, an empty box is returned to preserve spacing.
  Widget _buildBadgeSlot(Widget? badge) {
    if (badge == null) {
      return const SizedBox(height: 16);
    }

    return SizedBox(
      height: 16,
      child: Center(child: badge),
    );
  }
}
