/// NWC URI Parser for parsing nostr+walletconnect:// URIs.
///
/// Supports parsing NWC connection URIs as defined in NIP-47.
library;

/// Parsed NWC connection parameters from a NWC URI.
class NwcConnectionParams {
  /// Creates a new NwcConnectionParams instance.
  const NwcConnectionParams({
    required this.walletPubkey,
    required this.relays,
    required this.secret,
    this.lud16,
  });

  /// The wallet service's public key (hex format).
  final String walletPubkey;

  /// List of relay URLs to connect to.
  final List<String> relays;

  /// The client's private key (secret) for signing requests.
  final String secret;

  /// Optional Lightning address (lud16).
  final String? lud16;

  @override
  String toString() {
    return 'NwcConnectionParams(walletPubkey: $walletPubkey, relays: $relays, lud16: $lud16)';
  }
}

/// Parser for NWC (Nostr Wallet Connect) URIs.
///
/// Parses URIs in the format:
/// nostr+walletconnect://<pubkey>?relay=<relay>&secret=<secret>&lud16=<lud16>
class NwcUriParser {
  /// The NWC URI scheme prefix.
  static const String nwcPrefix = 'nostr+walletconnect://';

  /// Parses a NWC URI string into NwcConnectionParams.
  ///
  /// Throws [ArgumentError] if the URI is invalid or missing required fields.
  static NwcConnectionParams parse(String uri) {
    if (!uri.startsWith(nwcPrefix)) {
      throw ArgumentError('Invalid NWC URI: must start with $nwcPrefix');
    }

    // Remove the scheme prefix and parse
    final withoutScheme = uri.substring(nwcPrefix.length);

    // Split pubkey from query parameters
    final parts = withoutScheme.split('?');
    if (parts.isEmpty || parts[0].isEmpty) {
      throw ArgumentError('Invalid NWC URI: missing wallet pubkey');
    }

    final walletPubkey = parts[0];

    // Validate pubkey format (64 hex characters)
    if (!_isValidHexPubkey(walletPubkey)) {
      throw ArgumentError('Invalid NWC URI: invalid wallet pubkey format');
    }

    if (parts.length < 2) {
      throw ArgumentError('Invalid NWC URI: missing query parameters');
    }

    // Parse query parameters
    final queryString = parts.sublist(1).join('?');
    final params = _parseQueryString(queryString);

    // Extract relays (can have multiple)
    final relays = params['relay'];
    if (relays == null || relays.isEmpty) {
      throw ArgumentError('Invalid NWC URI: missing relay parameter');
    }

    // Extract secret
    final secrets = params['secret'];
    if (secrets == null || secrets.isEmpty) {
      throw ArgumentError('Invalid NWC URI: missing secret parameter');
    }
    final secret = secrets.first;

    // Validate secret format (64 hex characters)
    if (!_isValidHexPubkey(secret)) {
      throw ArgumentError('Invalid NWC URI: invalid secret format');
    }

    // Extract optional lud16
    final lud16List = params['lud16'];
    final lud16 = lud16List?.isNotEmpty == true ? lud16List!.first : null;

    return NwcConnectionParams(
      walletPubkey: walletPubkey,
      relays: relays,
      secret: secret,
      lud16: lud16,
    );
  }

  /// Parses a query string into a map of parameter names to lists of values.
  ///
  /// Supports multiple values for the same parameter (e.g., multiple relays).
  static Map<String, List<String>> _parseQueryString(String queryString) {
    final result = <String, List<String>>{};

    final pairs = queryString.split('&');
    for (final pair in pairs) {
      final keyValue = pair.split('=');
      if (keyValue.length != 2) continue;

      final key = keyValue[0];
      final value = Uri.decodeComponent(keyValue[1]);

      result.putIfAbsent(key, () => []).add(value);
    }

    return result;
  }

  /// Validates that a string is a valid 64-character hex pubkey/secret.
  static bool _isValidHexPubkey(String value) {
    if (value.length != 64) return false;
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(value);
  }
}
