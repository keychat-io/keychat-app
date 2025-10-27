import 'dart:convert' show jsonDecode;

import 'package:app/controller/chat.controller.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/models/keychat/keychat_message.dart';
import 'package:app/models/keychat/profile_request_model.dart';
import 'package:app/models/message.dart';
import 'package:app/models/room.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
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
  ) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Save contact from QR code
      await ContactService.instance.saveContactFromQrCode(
        identityId: widget.message.identityId,
        pubkey: profile.pubkey,
        name: profile.name,
        avatarRemoteUrl: profile.avatar,
        lightning: profile.lightningAddress,
      );
      Get.find<HomeController>().loadIdentityRoomList(widget.room.identityId);
      await RoomService.instance.refreshRoom(widget.room);

      // Update message status
      await _updateMessageStatus(RequestConfrimEnum.approved);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact saved successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save contact: $e')),
        );
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
      final keychatMessage =
          KeychatMessage.fromJson(jsonDecode(widget.message.content));
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
                    color: Colors.grey,
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
                      if (map.lightningAddress != null)
                        Text(
                          map.lightningAddress!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      if (map.note != null)
                        Text(
                          map.note!,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
              child: const Text('Reject'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed:
                  _isLoading ? null : () => _handleApprove(context, profile),
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
                'Request Rejected',
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
