import 'package:keychat/models/room_member.dart';

/// Exception thrown when there are expired members in a MLS group
class ExpiredMembersException implements Exception {
  ExpiredMembersException(this.expiredMembers);
  final List<RoomMember> expiredMembers;

  @override
  String toString() {
    final names = expiredMembers.map((m) => m.displayName).join(', ');
    return 'The following members have expired key packages: $names';
  }
}
