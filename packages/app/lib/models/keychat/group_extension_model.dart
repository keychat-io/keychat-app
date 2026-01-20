import 'package:keychat/models/room.dart';

class GroupExtension {
  GroupExtension({
    required this.name,
    required this.description,
    required this.admins,
    required this.relays,
    required this.status,
  });

  factory GroupExtension.fromMap(Map<String, dynamic> map) {
    return GroupExtension(
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      admins: List<String>.from(map['admins'] as List<dynamic>? ?? []),
      relays: List<String>.from(map['relays'] as List<dynamic>? ?? []),
      status: map['status'] as String? ?? RoomStatus.enabled.name,
    );
  }
  final String name;
  final String description;
  final String status;
  final List<String> admins;
  final List<String> relays;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'admins': admins,
      'relays': relays,
      'status': status,
    };
  }
}
