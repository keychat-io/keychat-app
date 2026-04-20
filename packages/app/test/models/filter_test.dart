import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/nostr-core/filter.dart';

void main() {
  group('Filter', () {
    Map<String, dynamic> buildFullJson() => {
      'ids': ['id1', 'id2'],
      'authors': ['author1'],
      'kinds': [1, 4],
      '#e': ['event1'],
      '#p': ['pubkey1', 'pubkey2'],
      '#r': ['wss://relay.example.com'],
      '#t': ['hashtag1'],
      '#h': ['group1'],
      'since': 1672175320,
      'until': 1672261720,
      'limit': 100,
    };

    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = buildFullJson();
        final filter = Filter.fromJson(json);

        expect(filter.ids, equals(['id1', 'id2']));
        expect(filter.authors, equals(['author1']));
        expect(filter.kinds, equals([1, 4]));
        expect(filter.e, equals(['event1']));
        expect(filter.p, equals(['pubkey1', 'pubkey2']));
        expect(filter.r, equals(['wss://relay.example.com']));
        expect(filter.t, equals(['hashtag1']));
        expect(filter.h, equals(['group1']));
        expect(filter.since, equals(1672175320));
        expect(filter.until, equals(1672261720));
        expect(filter.limit, equals(100));
      });

      test('handles null fields gracefully', () {
        final filter = Filter.fromJson(<String, dynamic>{});

        expect(filter.ids, isNull);
        expect(filter.authors, isNull);
        expect(filter.kinds, isNull);
        expect(filter.e, isNull);
        expect(filter.p, isNull);
        expect(filter.r, isNull);
        expect(filter.t, isNull);
        expect(filter.h, isNull);
        expect(filter.since, isNull);
        expect(filter.until, isNull);
        expect(filter.limit, isNull);
      });
    });

    group('toJson', () {
      test('outputs correct keys including hash-prefixed tag keys', () {
        final filter = Filter(
          ids: ['id1'],
          authors: ['author1'],
          kinds: [1],
          e: ['event1'],
          p: ['pubkey1'],
          r: ['relay1'],
          t: ['tag1'],
          h: ['group1'],
          since: 1000,
          until: 2000,
          limit: 50,
        );

        final json = filter.toJson();

        expect(json['ids'], equals(['id1']));
        expect(json['authors'], equals(['author1']));
        expect(json['kinds'], equals([1]));
        expect(json['#e'], equals(['event1']));
        expect(json['#p'], equals(['pubkey1']));
        expect(json['#r'], equals(['relay1']));
        expect(json['#t'], equals(['tag1']));
        expect(json['#h'], equals(['group1']));
        expect(json['since'], equals(1000));
        expect(json['until'], equals(2000));
        expect(json['limit'], equals(50));

        // Ensure raw keys are not present
        expect(json.containsKey('e'), isFalse);
        expect(json.containsKey('p'), isFalse);
        expect(json.containsKey('r'), isFalse);
        expect(json.containsKey('t'), isFalse);
        expect(json.containsKey('h'), isFalse);
      });

      test('null fields are omitted from output', () {
        final filter = Filter(kinds: [1], limit: 10);
        final json = filter.toJson();

        expect(json.containsKey('kinds'), isTrue);
        expect(json.containsKey('limit'), isTrue);
        expect(json.containsKey('ids'), isFalse);
        expect(json.containsKey('authors'), isFalse);
        expect(json.containsKey('#e'), isFalse);
        expect(json.containsKey('#p'), isFalse);
        expect(json.containsKey('#r'), isFalse);
        expect(json.containsKey('#t'), isFalse);
        expect(json.containsKey('#h'), isFalse);
        expect(json.containsKey('since'), isFalse);
        expect(json.containsKey('until'), isFalse);
      });

      test('empty filter produces empty map', () {
        final filter = Filter();
        final json = filter.toJson();

        expect(json, isEmpty);
      });
    });

    group('roundtrip', () {
      test('fromJson -> toJson preserves all data', () {
        final original = buildFullJson();
        final filter = Filter.fromJson(original);
        final result = filter.toJson();

        expect(result['ids'], equals(original['ids']));
        expect(result['authors'], equals(original['authors']));
        expect(result['kinds'], equals(original['kinds']));
        expect(result['#e'], equals(original['#e']));
        expect(result['#p'], equals(original['#p']));
        expect(result['#r'], equals(original['#r']));
        expect(result['#t'], equals(original['#t']));
        expect(result['#h'], equals(original['#h']));
        expect(result['since'], equals(original['since']));
        expect(result['until'], equals(original['until']));
        expect(result['limit'], equals(original['limit']));
      });
    });
  });
}
