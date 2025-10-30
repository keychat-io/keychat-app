import 'dart:convert' show jsonDecode;

import 'package:app/controller/chat.controller.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/models/keychat/keychat_message.dart';
import 'package:app/models/keychat/profile_request_model.dart';
import 'package:app/models/message.dart';
import 'package:app/models/room.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/components.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class ProfileRequestWidget extends StatefulWidget {
  const ProfileRequestWidget(
    this.cc,
    this.message,
    this.room,
    this.errorCallabck, {
    super.key,
  });
  final ChatController cc;
  final Message message;
  final Room room;
  final Widget Function({Widget? child, String? text}) errorCallabck;

  @override
  State<ProfileRequestWidget> createState() => _ProfileRequestWidgetState();
}

class _ProfileRequestWidgetState extends State<ProfileRequestWidget> {
  bool _isLoading = false;

  Future<void> _handleApprove(
    BuildContext context,
    ProfileRequestModel profile,
    String idPubkey,
  ) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (idPubkey != profile.pubkey) {
        await EasyLoading.showError('Public key mismatch');
        return;
      }
      // Save contact from QR code
      await ContactService.instance.saveContactFromQrCode(
        identityId: widget.message.identityId,
        pubkey: idPubkey,
        name: profile.name,
        avatarRemoteUrl: profile.avatar,
        lightning: profile.lightning,
        bio: profile.bio,
        version: profile.version,
      );
      if (widget.room.type == RoomType.group) {
        await RoomService.getController(widget.room.id)?.resetMembers();
      } else {
        await RoomService.instance.refreshRoom(
          widget.room,
          refreshContact: true,
        );
      }
      Get.find<HomeController>().loadIdentityRoomList(widget.room.identityId);

      // Update message status
      await _updateMessageStatus(RequestConfrimEnum.approved);

      // Show success message
      if (context.mounted) {
        EasyLoading.showSuccess('Contact saved successfully');
      }
    } catch (e) {
      if (context.mounted) {
        final msg = Utils.getErrorMessage(e);
        EasyLoading.showError(msg);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleReject() async {
    if (_isLoading) return;
    await _updateMessageStatus(RequestConfrimEnum.rejected);
  }

  Future<void> _updateMessageStatus(RequestConfrimEnum status) async {
    widget.message.requestConfrim = status;
    await MessageService.instance.updateMessageAndRefresh(widget.message);
  }

  @override
  Widget build(BuildContext context) {
    ProfileRequestModel map;
    try {
      final keychatMessage = KeychatMessage.fromJson(
        jsonDecode(widget.message.content),
      );
      map = ProfileRequestModel.fromJson(
        jsonDecode(keychatMessage.name!),
      );
    } catch (e) {
      return widget.errorCallabck(text: widget.message.content);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Avatar placeholder (question mark icon)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 30,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        map.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (map.bio != null)
                        textSmallGray(
                          context,
                          map.bio!,
                          maxLines: 3,
                        ),
                      if (map.lightning != null)
                        Text(
                          'lightning: ${map.lightning!}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            if (!widget.message.isMeSend) const SizedBox(height: 12),
            if (!widget.message.isMeSend) _buildActionSection(context, map),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection(
    BuildContext context,
    ProfileRequestModel profile,
  ) {
    final status = widget.message.requestConfrim ?? RequestConfrimEnum.request;
    switch (status) {
      case RequestConfrimEnum.request:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: _handleReject,
              child: const Text('Ignore'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () => _handleApprove(
                      context,
                      profile,
                      widget.message.idPubkey,
                    ),
              child: _isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        );
      case RequestConfrimEnum.approved:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(width: 4),
              Text(
                'Contact Saved',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ),
        );
      case RequestConfrimEnum.rejected:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel, color: Colors.red, size: 16),
              SizedBox(width: 4),
              Text(
                'Ignored',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
