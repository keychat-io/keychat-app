import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

// https://github.com/hagezi/dns-blocklists?tab=readme-ov-file#light

class AdBlockService {
  static const String _blocklistUrl =
      'https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/light.txt';
  static const String _cacheFileName = 'hagezi_blocklist.txt';
  static const Duration _cacheExpiration = Duration(days: 7);

  List<ContentBlocker> _contentBlockers = [];

  /// Get the list of content blockers
  List<ContentBlocker> get contentBlockers => _contentBlockers;

  /// Initialize AdBlock rules - download if needed and parse into content blockers
  Future<void> initialize() async {
    try {
      final rulesContent = await _getRulesContent();
      if (rulesContent.isEmpty) {
        debugPrint('AdBlock: No rules loaded, using empty list');
        return;
      }

      _contentBlockers = await _parseRulesToContentBlockers(rulesContent);
      debugPrint(
        'AdBlock: Initialized with ${_contentBlockers.length} content blockers',
      );
    } catch (e) {
      debugPrint('AdBlock: Failed to initialize: $e');
      // Use empty list on error
      _contentBlockers = [];
    }
  }

  /// Get rules content from cache or download if needed
  Future<String> _getRulesContent() async {
    final cacheFile = await _getCacheFile();

    // Check if cache exists and is valid
    if (await cacheFile.exists()) {
      final lastModified = await cacheFile.lastModified();
      final cacheAge = DateTime.now().difference(lastModified);

      if (cacheAge < _cacheExpiration) {
        debugPrint('AdBlock: Using cached rules (age: ${cacheAge.inHours}h)');
        return cacheFile.readAsString();
      } else {
        debugPrint('AdBlock: Cache expired (age: ${cacheAge.inDays}d)');
      }
    }

    // Download fresh rules
    return _downloadAndCacheRules(cacheFile);
  }

  /// Get the cache file path
  Future<File> _getCacheFile() async {
    final directory = await getApplicationSupportDirectory();
    final adblockDir = Directory('${directory.path}/adblock');

    if (!await adblockDir.exists()) {
      await adblockDir.create(recursive: true);
    }

    return File('${adblockDir.path}/$_cacheFileName');
  }

  /// Download rules from HaGeZi blocklist and save to cache
  Future<String> _downloadAndCacheRules(File cacheFile) async {
    debugPrint('AdBlock: Downloading rules from $_blocklistUrl');

    try {
      final dio = Dio();
      final response = await dio.get<String>(
        _blocklistUrl,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        final content = response.data!;
        await cacheFile.writeAsString(content);
        debugPrint('AdBlock: Downloaded and cached ${content.length} bytes');
        return content;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('AdBlock: Download failed: $e');

      // Try to use old cache if available
      if (await cacheFile.exists()) {
        debugPrint('AdBlock: Using expired cache as fallback');
        return cacheFile.readAsString();
      }

      return '';
    }
  }

  /// Parse HaGeZi blocklist rules and convert to Safari Content Blocker format
  /// Only processes domain blocking rules (||domain^)
  Future<List<ContentBlocker>> _parseRulesToContentBlockers(
    String rulesContent,
  ) async {
    final blockers = <ContentBlocker>[];
    final lines = const LineSplitter().convert(rulesContent);

    final domains = <String>[];

    for (var line in lines) {
      line = line.trim();

      // Skip empty lines
      if (line.isEmpty) {
        continue;
      }

      // Skip comments (lines starting with !)
      if (line.startsWith('!')) {
        continue;
      }

      // Skip metadata lines (like [Adblock Plus])
      if (line.startsWith('[')) {
        continue;
      }

      // Only process domain blocking rules: ||domain^
      // Skip exception rules (@@)
      if (line.startsWith('@@')) {
        continue;
      }

      // Parse domain blocking rule
      final domain = _parseDomainBlockingRule(line);
      if (domain != null && domain.isNotEmpty) {
        domains.add(domain);
      }
    }

    debugPrint('AdBlock: Parsed ${domains.length} domain rules');

    // Create content blockers from domain filters
    // Limit total domains for performance
    const maxTotalDomains = 50000;
    final limitedDomains = domains.length > maxTotalDomains
        ? domains.sublist(0, maxTotalDomains)
        : domains;

    for (final domain in limitedDomains) {
      try {
        // Create URL filter pattern for the domain
        // Match domain and all subdomains
        final pattern = '.*.$domain/.*';
        blockers.add(
          ContentBlocker(
            trigger: ContentBlockerTrigger(
              urlFilter: pattern,
            ),
            action: ContentBlockerAction(
              type: ContentBlockerActionType.BLOCK,
            ),
          ),
        );
      } catch (e) {
        debugPrint(
          'AdBlock: Failed to create blocker for domain: $domain - $e',
        );
      }
    }

    if (domains.length > maxTotalDomains) {
      debugPrint(
        'AdBlock: Limited domains from ${domains.length} to $maxTotalDomains for performance',
      );
    }

    debugPrint(
      'AdBlock: Created ${blockers.length} content blockers from ${limitedDomains.length} domains',
    );

    // Print first few domains for debugging
    if (limitedDomains.isNotEmpty) {
      debugPrint(
        'AdBlock: Sample domains: ${limitedDomains.take(5).join(", ")}',
      );
    }

    return blockers;
  }

  /// Parse domain blocking rule from HaGeZi format (||domain^)
  /// Returns the domain name if valid, null otherwise
  String? _parseDomainBlockingRule(String rule) {
    // Only process rules in format: ||domain^
    if (!rule.startsWith('||') || !rule.endsWith('^')) {
      return null;
    }

    // Extract domain between || and ^
    final domain = rule.substring(2, rule.length - 1).trim();

    // Skip empty domains
    if (domain.isEmpty) return null;

    // Skip rules with wildcards or paths (we only want pure domains)
    if (domain.contains('*') || domain.contains('/')) {
      return null;
    }

    // Skip rules with special characters that aren't valid in domains
    if (domain.contains(r'$') || domain.contains('#')) {
      return null;
    }

    // Basic domain validation: should contain at least one dot and valid characters
    if (!domain.contains('.')) return null;

    // Check if domain contains only valid characters (alphanumeric, dots, hyphens)
    if (!RegExp(r'^[a-zA-Z0-9.-]+$').hasMatch(domain)) {
      return null;
    }

    // Skip too short or too long domains
    if (domain.length < 4 || domain.length > 253) return null;

    return domain;
  }

  /// Force refresh rules by downloading again
  Future<void> refreshRules() async {
    try {
      final cacheFile = await _getCacheFile();
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
      await initialize();
    } catch (e) {
      debugPrint('AdBlock: Failed to refresh rules: $e');
    }
  }

  /// Get cache info
  Future<Map<String, dynamic>> getCacheInfo() async {
    final cacheFile = await _getCacheFile();

    if (!await cacheFile.exists()) {
      return {
        'exists': false,
        'age': null,
        'size': 0,
        'blockerCount': _contentBlockers.length,
      };
    }

    final stats = await cacheFile.stat();
    final age = DateTime.now().difference(stats.modified);

    return {
      'exists': true,
      'age': age.inHours,
      'size': stats.size,
      'path': cacheFile.path,
      'blockerCount': _contentBlockers.length,
    };
  }
}
