import 'dart:convert';
import 'dart:typed_data';

/// Stores LND connection details parsed from lndconnect:// URI.
///
/// LNDConnect URI format:
/// lndconnect://<host>:<port>?cert=<base64url_cert>&macaroon=<base64url_macaroon>
class LndConnectionInfo {
  LndConnectionInfo({
    required this.uri,
    required this.host,
    required this.port,
    required this.macaroon,
    this.tlsCert,
    this.name,
    this.weight = 0,
  });

  /// Parse an LNDConnect URI into connection info.
  ///
  /// Throws [ArgumentError] if the URI is malformed.
  factory LndConnectionInfo.fromUri(String uri, {String? name}) {
    if (!uri.startsWith(lndConnectPrefix)) {
      throw ArgumentError(
        'Invalid LND URI: must start with $lndConnectPrefix',
      );
    }

    try {
      // Parse the URI (replace scheme for standard parsing)
      final parsed = Uri.parse(uri.replaceFirst('lndconnect://', 'https://'));

      final host = parsed.host;
      final port = parsed.port != 0 ? parsed.port : 8080;

      // Get macaroon from query params (base64url encoded)
      final macaroonBase64 = parsed.queryParameters['macaroon'];
      if (macaroonBase64 == null || macaroonBase64.isEmpty) {
        throw ArgumentError('Missing macaroon in LND URI');
      }

      // Convert base64url to hex for API header
      final macaroonHex = _base64UrlToHex(macaroonBase64);

      // Get optional TLS cert
      final certBase64 = parsed.queryParameters['cert'];
      String? tlsCert;
      if (certBase64 != null && certBase64.isNotEmpty) {
        tlsCert = _base64UrlToStandardBase64(certBase64);
      }

      return LndConnectionInfo(
        uri: uri,
        host: host,
        port: port,
        macaroon: macaroonHex,
        tlsCert: tlsCert,
        name: name,
      );
    } catch (e) {
      if (e is ArgumentError) rethrow;
      throw ArgumentError('Invalid LND URI: $e');
    }
  }

  factory LndConnectionInfo.fromJson(Map<String, dynamic> json) {
    return LndConnectionInfo(
      uri: json['uri'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      macaroon: json['macaroon'] as String,
      tlsCert: json['tlsCert'] as String?,
      name: json['name'] as String?,
      weight: json['weight'] as int? ?? 0,
    );
  }

  static const String lndConnectPrefix = 'lndconnect://';

  /// Full lndconnect URI
  final String uri;

  /// LND server hostname or IP
  final String host;

  /// LND REST API port (default 8080)
  final int port;

  /// Hex-encoded macaroon for authentication
  final String macaroon;

  /// Optional TLS certificate (base64 PEM)
  final String? tlsCert;

  /// User-defined wallet name
  final String? name;

  /// Weight for sorting (higher = more important)
  final int weight;

  /// Get the base URL for REST API calls
  String get baseUrl => 'https://$host:$port';

  Map<String, dynamic> toJson() {
    return {
      'uri': uri,
      'host': host,
      'port': port,
      'macaroon': macaroon,
      'tlsCert': tlsCert,
      'name': name,
      'weight': weight,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LndConnectionInfo &&
        other.uri == uri &&
        other.name == name &&
        other.weight == weight;
  }

  @override
  int get hashCode => uri.hashCode ^ name.hashCode ^ weight.hashCode;

  @override
  String toString() =>
      'LndConnectionInfo(host: $host, port: $port, name: $name)';

  /// Convert base64url to hex string.
  static String _base64UrlToHex(String base64url) {
    // Add padding if needed
    var padded = base64url;
    while (padded.length % 4 != 0) {
      padded += '=';
    }
    // Convert base64url to standard base64
    final standard = padded.replaceAll('-', '+').replaceAll('_', '/');
    final bytes = base64Decode(standard);
    return _bytesToHex(bytes);
  }

  /// Convert base64url to standard base64.
  static String _base64UrlToStandardBase64(String base64url) {
    var padded = base64url;
    while (padded.length % 4 != 0) {
      padded += '=';
    }
    return padded.replaceAll('-', '+').replaceAll('_', '/');
  }

  /// Convert bytes to hex string.
  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
