import 'package:keychat/global.dart';

class NwcConnectionInfo {
  NwcConnectionInfo({
    required this.uri,
    this.name,
    this.weight = 0,
  }) {
    if (!uri.startsWith(KeychatGlobal.nwcPrefix)) {
      throw ArgumentError(
        'Invalid NWC URI: must start with ${KeychatGlobal.nwcPrefix}',
      );
    }
    // Validate URI format
    try {
      final parsed = Uri.parse(uri);
      if (parsed.host.isEmpty && parsed.path.isEmpty) {
        throw ArgumentError('Invalid NWC URI: malformed URI structure');
      }
    } catch (e) {
      if (e is ArgumentError) rethrow;
      throw ArgumentError('Invalid NWC URI: $e');
    }
  }

  factory NwcConnectionInfo.fromJson(Map<String, dynamic> json) {
    return NwcConnectionInfo(
      uri: json['uri'] as String,
      name: json['name'] as String?,
      weight: json['weight'] as int? ?? 0,
    );
  }
  final String uri;
  final String? name;
  final int weight;

  Map<String, dynamic> toJson() {
    return {
      'uri': uri,
      'name': name,
      'weight': weight,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NwcConnectionInfo &&
        other.uri == uri &&
        other.name == name &&
        other.weight == weight;
  }

  @override
  int get hashCode => uri.hashCode ^ name.hashCode ^ weight.hashCode;

  @override
  String toString() =>
      'NwcConnectionInfo(uri: $uri, name: $name, weight: $weight)';
}
