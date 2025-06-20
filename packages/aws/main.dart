import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

void main() async {
  File file = File('./lib/a.text');
  var fileBytes = (await file.readAsBytes()).toList();
  String hash = calculateFileHash(fileBytes);
  Map<dynamic, dynamic> uploadParams = await getUploadParams(
    cashu: "",
    length: fileBytes.length,
    sha256: hash,
  );

  String result = await uploadToAws(
      uploadParams: uploadParams, fileBytes: fileBytes, filename: hash);

  developer.log(result);
}

Future<Map> getUploadParams(
    {required String cashu,
    required int length,
    required String sha256}) async {
  final dio = Dio();
  const url = 'http://138.128.221.248:3001/v1/object';
  final headers = {'Content-type': 'application/json'};

  final response = await dio.post(
    url,
    data: {
      'cashu': cashu,
      'length': length,
      'sha256': sha256,
    },
    options: Options(headers: headers),
  );

  if (response.statusCode == 200) {
    return response.data;
  }
  throw Exception('Fetch upload params failed');
}

String calculateFileHash(List<int> fileBytes) {
  final digest = sha256.convert(fileBytes);
  return base64Encode(digest.bytes);
}

Future<String> uploadToAws(
    {required List<int> fileBytes,
    void Function(int p1, int p2)? onSendProgress,
    required String filename,
    required Map<dynamic, dynamic> uploadParams}) async {
  final dio = Dio();

  String endpoint = uploadParams['url']!;
  Map<String, dynamic> config = uploadParams['headers']!;

  try {
    final response = await dio.put(endpoint,
        data: Stream.fromIterable(fileBytes.map((e) => [e])),
        options: Options(
          headers: config,
        ),
        onSendProgress: onSendProgress);

    if (response.statusCode == 200) {
      return uploadParams['access_url']!;
    }
  } on DioException catch (e) {
    // The request was made and the server responded with a status code
    // that falls out of the range of 2xx and is also not 304.
    if (e.response != null) {
      developer.log(e.response?.data);
    } else {
      // Something happened in setting up or sending the request that triggered an Error
      developer.log(e.requestOptions.toString());
      developer.log(e.message.toString());
    }
  }

  throw Exception('File_upload_faild');
}
