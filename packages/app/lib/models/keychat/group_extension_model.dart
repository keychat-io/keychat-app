class GroupExtension {
  final String name;
  final String description;
  final List<String> admins;
  final List<String> relays;

  GroupExtension({
    required this.name,
    required this.description,
    required this.admins,
    required this.relays,
  });

  factory GroupExtension.fromMap(Map<String, dynamic> map) {
    return GroupExtension(
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      admins: List<String>.from(map['admins'] ?? []),
      relays: List<String>.from(map['relays'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'admins': admins,
      'relays': relays,
    };
  }
}
