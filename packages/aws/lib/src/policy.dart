import 'dart:convert' show utf8, base64, jsonEncode;

import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';
import './enum/acl.dart';
import './utils.dart';

class Policy {
  String expiration;
  String region;
  ACL acl;
  String bucket;
  String key;
  String credential;
  String datetime;
  int maxFileSize;
  Map<String, dynamic>? metadata;

  Policy(
    this.key,
    this.bucket,
    this.datetime,
    this.expiration,
    this.credential,
    this.maxFileSize,
    this.acl, {
    this.region = 'us-east-2',
    this.metadata,
  });

  factory Policy.fromS3PresignedPost(
    String key,
    String bucket,
    String accessKeyId,
    int expiryMinutes,
    int maxFileSize,
    ACL acl, {
    String region = 'us-east-2',
    Map<String, dynamic>? metadata,
  }) {
    final datetime = SigV4.generateDatetime();
    final expiration = (DateTime.now())
        .add(Duration(minutes: expiryMinutes))
        .toUtc()
        .toString()
        .split(' ')
        .join('T');
    final cred =
        '$accessKeyId/${SigV4.buildCredentialScope(datetime, region, 's3')}';

    return Policy(
      key,
      bucket,
      datetime,
      expiration,
      cred,
      maxFileSize,
      acl,
      region: region,
      metadata: metadata,
    );
  }

  String encode() {
    final bytes = utf8.encode(toString());
    return base64.encode(bytes);
  }

  List<Map<String, String>> _convertMetadataToPolicyParams(
      Map<String, dynamic>? metadata) {
    final List<Map<String, String>> params = [];

    if (metadata != null) {
      for (var k in metadata.keys) {
        params.add({k: metadata[k]});
      }
    }

    return params;
  }

  @override
  String toString() {
    final metadataParams = _convertMetadataToPolicyParams(metadata);

    final payload = {
      "expiration": expiration,
      "conditions": [
        {"bucket": bucket},
        ["starts-with", "\$key", (key)],
        ["starts-with", "\$Content-Type", ""],
        {"acl": aclToString(acl)},
        ["content-length-range", 1, maxFileSize],
        {"x-amz-credential": credential},
        {"x-amz-algorithm": "AWS4-HMAC-SHA256"},
        {"x-amz-date": datetime},
      ],
    };

    // If there's metadata, add it to the list of conditions for the policy.
    if (metadataParams.isNotEmpty) {
      for (final p in metadataParams) {
        (payload['conditions'] as List).add(p);
      }
    }

    return jsonEncode(payload);
  }
}
