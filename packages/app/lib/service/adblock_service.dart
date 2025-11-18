import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

/// Service for managing AdBlock rules for WebView content blocking
/// Downloads and caches EasyList rules, then converts them to Safari Content Blocker format
class AdBlockService {
  static const String _easyListUrl =
      'https://easylist-downloads.adblockplus.org/v3/full/easylist.txt';
  static const String _cacheFileName = 'easylist_rules.txt';
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

  /// Download rules from EasyList and save to cache
  Future<String> _downloadAndCacheRules(File cacheFile) async {
    debugPrint('AdBlock: Downloading rules from $_easyListUrl');

    try {
      final dio = Dio();
      final response = await dio.get<String>(
        _easyListUrl,
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

  /// Parse EasyList rules and convert to Safari Content Blocker format
  Future<List<ContentBlocker>> _parseRulesToContentBlockers(
    String rulesContent,
  ) async {
    final blockers = <ContentBlocker>[];
    final lines = const LineSplitter().convert(rulesContent);

    // Lists to accumulate different types of rules
    final urlFilters = <String>[];
    final cssSelectors = <String>[];

    for (var line in lines) {
      line = line.trim();

      // Skip comments and metadata
      if (line.isEmpty || line.startsWith('!') || line.startsWith('[Adblock')) {
        continue;
      }

      // Element hiding rules (CSS selectors)
      if (line.contains('##')) {
        final selector = _parseElementHidingRule(line);
        if (selector != null && selector.isNotEmpty) {
          cssSelectors.add(selector);
        }
        continue;
      }

      // Element hiding exception rules - skip
      if (line.contains('#@#')) {
        continue;
      }

      // URL blocking rules
      final urlFilter = _parseUrlBlockingRule(line);
      if (urlFilter != null && urlFilter.isNotEmpty) {
        urlFilters.add(urlFilter);
      }
    }

    // Create content blockers from URL filters (batch in groups to avoid too many rules)
    // Note: Too many rules can cause performance issues, so we limit the total
    const maxTotalUrlFilters = 5000; // Limit total URL filters for performance
    final limitedUrlFilters = urlFilters.length > maxTotalUrlFilters
        ? urlFilters.sublist(0, maxTotalUrlFilters)
        : urlFilters;

    for (final filter in limitedUrlFilters) {
      try {
        blockers.add(
          ContentBlocker(
            trigger: ContentBlockerTrigger(
              urlFilter: filter,
            ),
            action: ContentBlockerAction(
              type: ContentBlockerActionType.BLOCK,
            ),
          ),
        );
      } catch (e) {
        debugPrint(
          'AdBlock: Failed to create blocker for filter: $filter - $e',
        );
      }
    }

    if (urlFilters.length > maxTotalUrlFilters) {
      debugPrint(
        'AdBlock: Limited URL filters from ${urlFilters.length} to $maxTotalUrlFilters for performance',
      );
    }

    // Create content blockers from CSS selectors (batch in groups)
    const maxSelectorsPerBlocker = 1000; // Increased from 100
    const maxTotalSelectors = 3000; // Limit total CSS selectors
    final limitedSelectors = cssSelectors.length > maxTotalSelectors
        ? cssSelectors.sublist(0, maxTotalSelectors)
        : cssSelectors;

    for (var i = 0; i < limitedSelectors.length; i += maxSelectorsPerBlocker) {
      final end = (i + maxSelectorsPerBlocker < limitedSelectors.length)
          ? i + maxSelectorsPerBlocker
          : limitedSelectors.length;
      final batch = limitedSelectors.sublist(i, end);

      try {
        blockers.add(
          ContentBlocker(
            trigger: ContentBlockerTrigger(
              urlFilter: '.*',
            ),
            action: ContentBlockerAction(
              type: ContentBlockerActionType.CSS_DISPLAY_NONE,
              selector: batch.join(', '),
            ),
          ),
        );
      } catch (e) {
        debugPrint('AdBlock: Failed to create CSS blocker: $e');
      }
    }

    if (cssSelectors.length > maxTotalSelectors) {
      debugPrint(
        'AdBlock: Limited CSS selectors from ${cssSelectors.length} to $maxTotalSelectors',
      );
    }

    debugPrint(
      'AdBlock: Created ${blockers.length} content blockers '
      '(${limitedUrlFilters.length} URL filters, ${limitedSelectors.length} CSS selectors)',
    );

    // Print first few blockers for debugging
    if (blockers.isNotEmpty) {
      debugPrint(
        'AdBlock: Sample blocker: ${blockers.first.trigger.urlFilter}',
      );
    }

    return blockers;
  }

  /// Parse element hiding rule (##selector)
  String? _parseElementHidingRule(String rule) {
    if (!rule.contains('##')) return null;

    final parts = rule.split('##');
    if (parts.length < 2) return null;

    var selector = parts[1].trim();

    // Skip domain-specific rules for simplicity (we'd need to parse domains)
    if (parts[0].isNotEmpty && !parts[0].startsWith('~')) {
      // This is a domain-specific rule, skip for now
      return null;
    }

    // Clean up the selector
    selector = selector.replaceAll(RegExp(r'[\r\n\t]'), '');

    // Skip selectors with non-ASCII characters (Safari Content Blocker limitation)
    if (!_isAscii(selector)) return null;

    // Skip advanced selectors that Safari doesn't support well
    if (selector.contains(':-abp-') ||
        selector.contains(':has(') ||
        selector.contains(':xpath(')) {
      return null;
    }

    // Validate basic CSS selector format
    if (selector.isEmpty || selector.length > 200) return null;

    return selector;
  }

  /// Parse URL blocking rule and convert to regex pattern
  String? _parseUrlBlockingRule(String rule) {
    // Skip exception rules
    if (rule.startsWith('@@')) return null;

    // Skip domain-specific options for simplicity
    if (rule.contains(r'$') && !rule.endsWith(r'$')) {
      // Has options, parse them
      final parts = rule.split(r'$');
      rule = parts[0];

      // Skip if it has complex options we don't handle
      final options = parts.length > 1 ? parts[1].toLowerCase() : '';
      if (options.contains('domain=') ||
          options.contains('script') ||
          options.contains('stylesheet') ||
          options.contains('subdocument')) {
        // We could parse these, but for simplicity skip for now
        return null;
      }
    }

    // Clean the rule
    rule = rule.trim();
    if (rule.isEmpty) return null;

    // Skip rules with non-ASCII characters
    if (!_isAscii(rule)) return null;

    // Convert AdBlock syntax to regex
    var pattern = rule;

    // Escape special regex characters except * and ^
    pattern = pattern.replaceAllMapped(
      RegExp(r'[.+?{}()\[\]\\|]'),
      (match) => '\\${match[0]}',
    );

    // Convert AdBlock wildcards to regex
    pattern = pattern.replaceAll('*', '.*');

    // Convert separator placeholder (^)
    pattern = pattern.replaceAll('^', '[^a-zA-Z0-9._%-]');

    // Handle start/end anchors
    if (pattern.startsWith('||')) {
      // ||example.com means domain start
      pattern = pattern.substring(2);
      pattern = '.*://(.*\\.)?$pattern';
    } else if (pattern.startsWith('|')) {
      // | means exact start
      pattern = '^${pattern.substring(1)}';
    }

    if (pattern.endsWith('|')) {
      // | means exact end
      pattern = '${pattern.substring(0, pattern.length - 1)}\$';
    }

    // Skip rules that are too generic or too complex
    if (pattern.length < 5 || pattern.length > 300) return null;
    if (pattern == '.*' || pattern == '.*:.*') return null;

    return pattern;
  }

  /// Check if string contains only ASCII characters
  bool _isAscii(String text) {
    return text.codeUnits.every((unit) => unit < 128);
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
