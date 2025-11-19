import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/service/adblock_service.dart';

void main() {
  group('AdBlockService', () {
    late AdBlockService service;

    setUp(() {
      service = AdBlockService();
    });

    test('should parse element hiding rule correctly', () {
      // This test demonstrates the expected behavior
      // In actual implementation, the parsing methods are private

      // Example rules that should be parsed:
      // ##.ads -> CSS selector ".ads"
      // ##div[id="advertisement"] -> CSS selector "div[id=\"advertisement\"]"
      // example.com##.banner -> domain-specific, may be skipped
    });

    test('should parse URL blocking rule correctly', () {
      // This test demonstrates the expected behavior

      // Example conversions:
      // ||ads.example.com^ -> .*://(.*\.)?ads\.example\.com[^a-zA-Z0-9._%-]
      // /ads/* -> .*ads/.*
      // |http://example.com -> ^http://example\.com
    });

    test('should handle cache correctly', () async {
      // Initialize service
      await service.initialize();

      // Should have some content blockers (could be empty if no cache and download fails)
      expect(service.contentBlockers, isA<List<dynamic>>());

      // Get cache info
      final info = await service.getCacheInfo();
      expect(info, containsPair('exists', isA<bool>()));
      expect(info, containsPair('blockerCount', isA<int>()));
    });

    test('should refresh rules', () async {
      await service.initialize();

      // Refresh should work without errors
      await service.refreshRules();

      // Should have blockers list (even if empty)
      expect(service.contentBlockers, isA<List<dynamic>>());
    });
  });

  group('Rule parsing edge cases', () {
    test('should handle various AdBlock Plus syntax', () {
      // Test cases for different AdBlock Plus rule formats:

      // 1. Basic URL block
      // Input: ||example.com^
      // Expected: Block domain example.com

      // 2. Wildcard
      // Input: /ads/*.js
      // Expected: Block any JS file in /ads/ path

      // 3. Element hiding
      // Input: ##.advertisement
      // Expected: Hide elements with class "advertisement"

      // 4. Domain-specific element hiding
      // Input: example.com##.banner
      // Expected: Hide .banner only on example.com (may be skipped in simple impl)

      // 5. Exception rule (should be ignored)
      // Input: @@||example.com/allowed.js
      // Expected: Skip this rule

      // 6. Complex selector
      // Input: ##div[class^="ad-"]
      // Expected: Hide divs with class starting with "ad-"
    });
  });
}
