import 'package:app/models/room.dart';

class GroupExtension {
  final String name;
  final String description;
  final String status;
  final List<String> admins;
  final List<String> relays;

  GroupExtension({
    required this.name,
    required this.description,
    required this.admins,
    required this.relays,
    required this.status,
  });

  factory GroupExtension.fromMap(Map<String, dynamic> map) {
    return GroupExtension(
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      admins: List<String>.from(map['admins'] ?? []),
      relays: List<String>.from(map['relays'] ?? []),
      status: map['status'] ?? RoomStatus.enabled,
    );
  }

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
