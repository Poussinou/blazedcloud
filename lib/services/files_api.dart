import 'dart:convert';

import 'package:blazedcloud/constants.dart';
import 'package:blazedcloud/log.dart';
import 'package:blazedcloud/models/files_api/list_files.dart';
import 'package:blazedcloud/utils/files_utils.dart';
import 'package:http/http.dart' as http;

final httpClient = http.Client();

Future<bool> deleteFile(String uid, String fileKey, String token) async {
  var headers = {'Authorization': 'Bearer $token'};
  var request = http.MultipartRequest(
      'DELETE', Uri.parse('$backendUrl/data/delete/$uid/file'));
  request.fields.addAll({'fileKey': fileKey});

  request.headers.addAll(headers);

  http.StreamedResponse response = await httpClient.send(request);

  if (response.statusCode == 200) {
    logger.d("Deleted file $fileKey");
    return true;
  } else {
    logger.e(response.reasonPhrase);
    return false;
  }
}

Future<bool> deleteFolder(String uid, String folderKey, String token) async {
  var headers = {'Authorization': 'Bearer $token'};
  var request = http.MultipartRequest(
      'DELETE', Uri.parse('$backendUrl/data/delete/$uid/folder'));
  request.fields.addAll({'folderKey': folderKey});

  request.headers.addAll(headers);

  http.StreamedResponse response = await httpClient.send(request);

  if (response.statusCode == 200) {
    logger.d("Deleted folder $folderKey");
    return true;
  } else {
    logger.e(response.reasonPhrase);
    return false;
  }
}

Future<http.StreamedResponse> getFile(
    String uid, String fileKey, String token) async {
  logger.i("Getting file ${getFileName(fileKey)} with key $fileKey");
  final link = await getFileLink(uid, fileKey, token);

  var request = http.MultipartRequest('GET', Uri.parse(link.toString()));
  request.fields.addAll({'file': getFileName(fileKey)});

  http.StreamedResponse response = await httpClient.send(request);

  if (response.statusCode == 200) {
    logger.d("Got file $fileKey");
    return response;
  } else {
    response.stream.bytesToString().then((value) => logger
        .e("${response.reasonPhrase} - ${response.statusCode} \n $value"));
    logger.e("");
    throw Exception('Failed to get file');
  }
}

/// don't call directly. This is used by getFile()
Future<String> getFileLink(String uid, String filename, String token) async {
  logger.i("Getting file link for $filename");
  var request =
      http.MultipartRequest('POST', Uri.parse('$backendUrl/data/down/$uid'));
  var headers = {'Authorization': 'Bearer $token'};
  request.fields.addAll({'filename': filename});
  request.headers.addAll(headers);

  http.StreamedResponse response = await httpClient.send(request);

  if (response.statusCode == 200) {
    final responseBody = await response.stream.bytesToString();
    logger.d("Got link $responseBody");
    return responseBody;
  } else {
    logger.e(response.reasonPhrase);
    throw Exception('Failed to get link');
  }
}

Future<ListBucketResult> getFilelist(
    String uid, String from, String token) async {
  logger.i("Getting file list for $uid");
  var headers = {'Authorization': 'Bearer $token'};
  var request = http.Request('POST', Uri.parse('$backendUrl/data/list/$uid'));

  request.body = jsonEncode({'from': from});
  request.headers.addAll(headers);

  http.StreamedResponse response = await httpClient.send(request);

  if (response.statusCode == 200) {
    final responseBody = await response.stream.transform(utf8.decoder).join();
    logger.d("Got file list - $responseBody");
    return ListBucketResult.fromJson(jsonDecode(responseBody));
  } else {
    logger.e(response.reasonPhrase);
    throw Exception('Failed to load file list');
  }
}

/// don't call directly. use uploadFile
Future<String> getUploadUrl(String uid, String filename, String token) async {
  var headers = {'Authorization': 'Bearer $token'};
  var request =
      http.MultipartRequest('POST', Uri.parse('$backendUrl/data/up/$uid'));
  request.fields.addAll({
    'filename': filename,
  });

  request.headers.addAll(headers);

  http.StreamedResponse response = await httpClient.send(request);

  if (response.statusCode == 200) {
    final responseBody = await response.stream.bytesToString();
    logger.d("Got upload url for $responseBody");
    return (responseBody);
  } else {
    logger.e(response.reasonPhrase);
    throw Exception('Failed to get upload url');
  }
}

/// use this to upload files directly. it will get the upload url and upload the file.
/// exclude the uid from the filename, it is added automatically
Future<http.StreamedResponse> uploadFile(String uid, String fileKey,
    http.ByteStream bytes, String token, int length) async {
  logger.i("Uploading file $fileKey");

  return await getUploadUrl(uid, fileKey, token)
      .then((value) => uploadToUrl(value, fileKey, bytes, length));
}

/// don't call directly. use uploadFile
Future<http.StreamedResponse> uploadToUrl(
  String url,
  String filename,
  http.ByteStream bytes,
  int length,
) async {
  logger.i("Uploading file $filename to $url");
  try {
    var request = http.MultipartRequest('PUT', Uri.parse(url));
    request.files.add(http.MultipartFile(
      'file',
      bytes,
      await bytes.length,
      filename: filename,
    ));

    http.StreamedResponse response = await httpClient.send(request);

    if (response.statusCode == 200) {
      logger.d("Uploaded file $filename");
      return response;
    } else {
      logger.e(response.reasonPhrase);
      throw Exception('Failed to upload file');
    }
  } catch (e) {
    logger.e("Error uploading file: $e");
    throw Exception('Failed to upload file');
  }
}
