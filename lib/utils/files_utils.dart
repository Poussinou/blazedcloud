import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:blazedcloud/constants.dart';
import 'package:blazedcloud/log.dart';
import 'package:blazedcloud/models/files_api/encrypted_stream.dart';
import 'package:blazedcloud/models/files_api/list_files.dart';
import 'package:blazedcloud/models/transfers/download_state.dart';
import 'package:blazedcloud/services/files_api.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

num computeTotalSizeGb(ListBucketResult list) {
  if (list.contents == null) {
    return 0;
  }
  logger.i('Computing total size of ${list.contents!.length} items');

  num totalSize = 0;
  for (var item in list.contents!) {
    totalSize += item.size!;
  }

  // convert to GB from bytes
  logger.i('Total size: $totalSize bytes');
  totalSize = totalSize / 1000000000;
  logger.i('Total size: $totalSize GB');

  return totalSize;
}

/// Creates a folder with a placeholder file so that it is visible in the file list.
Future<bool> createFolder(String folderKey) async {
  // upload a file with the name folderKey + "/.blazed-placeholder"
  final filename = '$folderKey/.blazed-placeholder';

  await uploadFile(pb.authStore.model.id, filename,
      http.ByteStream.fromBytes(Uint8List(0)), 0, pb.authStore.token);
  return true;
}

Future<http.ByteStream> decryptByteStream(
    http.ByteStream encryptedStream, String encryptionKey) async {
  // Hash the encryptionKey using SHA-512
  final keyHash =
      Uint8List.fromList(sha512.convert(utf8.encode(encryptionKey)).bytes);

  // Use the first 32 bytes (256 bits) of the SHA-512 hash as the decryption key
  final key = Key(Uint8List.fromList(keyHash.sublist(0, 32)));
  final iv = IV.fromLength(16); // Initialization Vector

  final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

  final decryptedStreamController = StreamController<List<int>>();
  final decryptedSink = decryptedStreamController.sink;

  try {
    await for (final chunk in encryptedStream) {
      final decryptedChunk = encrypter.decryptBytes(
        Encrypted.fromBase64(base64Encode(chunk)),
        iv: iv,
      );
      decryptedSink.add(decryptedChunk);
    }
  } catch (e) {
    decryptedStreamController.addError(e);
  } finally {
    decryptedSink.close();
  }

  // Create a StreamTransformer to convert the Stream<List<int>> to http.ByteStream
  final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
    handleData: (data, sink) {
      sink.add(data);
    },
  );

  final decryptedStream =
      decryptedStreamController.stream.transform(transformer);

  return http.ByteStream(decryptedStream);
}

Future<EncryptedStreamResult> encryptByteStream(
    http.ByteStream originalStream, String encryptionKey) async {
  // Hash the encryptionKey using SHA-512
  final keyHash =
      Uint8List.fromList(sha512.convert(utf8.encode(encryptionKey)).bytes);

  // Use the first 32 bytes (256 bits) of the SHA-512 hash as the encryption key
  final key = Key(Uint8List.fromList(keyHash.sublist(0, 32)));
  final iv = IV.fromLength(16); // Initialization Vector

  final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

  final encryptedStreamController = StreamController<List<int>>();
  final encryptedSink = encryptedStreamController.sink;
  int totalByteLength = 0; // Initialize the total byte length

  try {
    await for (final chunk in originalStream) {
      final encryptedChunk = encrypter.encryptBytes(chunk, iv: iv);
      final encryptedBytes = encryptedChunk.bytes;
      totalByteLength += encryptedBytes.length; // Update the total byte length
      encryptedSink.add(encryptedBytes);
    }
  } catch (e) {
    encryptedStreamController.addError(e);
  } finally {
    encryptedSink.close();
  }

  // Create a StreamTransformer to convert the Stream<List<int>> to http.ByteStream
  final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
    handleData: (data, sink) {
      sink.add(data);
    },
  );

  final encryptedStream =
      encryptedStreamController.stream.transform(transformer);

  return EncryptedStreamResult(
      http.ByteStream(encryptedStream), totalByteLength);
}

List<String> fuzzySearch(String query, List<String> list) {
  // Calculate a "score" for each item in the list based on how close it matches the query
  final scoredItems = list.map<Map<String, dynamic>>((item) {
    final lowerCaseItem = item.toLowerCase();
    final lowerCaseQuery = query.toLowerCase();

    // Calculate a score based on how many characters in the query match consecutively
    int score = 0;
    int queryIndex = 0;
    for (int i = 0; i < lowerCaseItem.length; i++) {
      if (queryIndex < lowerCaseQuery.length &&
          lowerCaseItem[i] == lowerCaseQuery[queryIndex]) {
        score++;
        queryIndex++;
      }
    }

    return {'item': item, 'score': score};
  }).toList();

  // Sort items by score in descending order
  scoredItems.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

  // Filter out items that don't contain the query at all
  final filteredResults = scoredItems
      .where((item) =>
          (item['item'] as String).toLowerCase().contains(query.toLowerCase()))
      .take(10)
      .map<String>((item) => item['item'] as String)
      .toList();

  return filteredResults;
}

// function to prompt user to select folder to store files at, and save the path to Hive
Future<void> getDownloadDirectory() async {
  final result = await fp.FilePicker.platform.getDirectoryPath();

  if (result != null) {
    // User selected a directory
    logger.i('Directory selected: $result');

    // save to Hive
    Hive.openBox<String>('files').then((box) {
      box.put('downloadDirectory', result);
    });
  } else {
    // User canceled the picker
    logger.i('User canceled directory picker');
  }
}

getFileDirectory(String key) {
  // remove the file name from the key
  return key.substring(0, key.lastIndexOf('/') + 1);
}

String getFileName(String filename) {
  // only return string after last '/'
  return filename.substring(filename.lastIndexOf('/') + 1);
}

FileType getFileType(String fileName) {
  if (fileName.endsWith('.jpg') ||
      fileName.endsWith('.jpeg') ||
      fileName.endsWith('.png')) {
    return FileType.image;
  } else if (fileName.endsWith('.mp4') ||
      fileName.endsWith('.avi') ||
      fileName.endsWith('.mkv')) {
    return FileType.video;
  } else if (fileName.endsWith('.mp3') ||
      fileName.endsWith('.wav') ||
      fileName.endsWith('.aac')) {
    return FileType.audio;
  } else if (fileName.endsWith('.doc') ||
      fileName.endsWith('.docx') ||
      fileName.endsWith('.pdf')) {
    return FileType.doc;
  } else if (fileName.endsWith('/')) {
    return FileType.other;
  } else {
    return FileType.other;
  }
}

List<String> getFolderList(ListBucketResult list) {
  if (list.contents == null) {
    return [];
  }

  Set<String> folderKeys = {};
  List<String> keys = getKeysFromList(list, true);

  logger.i('Keys: $keys');

  for (var key in keys) {
    // remove everything after the last / including the /
    final folderKey = key.substring(0, key.lastIndexOf('/') + 1);

    // add the folder key to the set
    folderKeys.add(folderKey);
  }

  logger.i('Folder keys: $folderKeys');

  return folderKeys.toList();
}

String getFolderName(String folderKey) {
  // remove the last segment of the folder key
  if (folderKey.endsWith('/')) {
    folderKey = folderKey.substring(0, folderKey.length - 1);
  }
  return folderKey.substring(folderKey.lastIndexOf('/') + 1);
}

List<String> getKeysFromList(ListBucketResult list, bool keepStartingDir) {
  if (list.contents == null) {
    return [];
  }

  List<String> keys = [];
  for (var item in list.contents!) {
    final key = item.key;

    // remove the starting directory from the key
    if (key!.startsWith(getStartingDirectory()) && !keepStartingDir) {
      keys.add(key.substring(getStartingDirectory().length));
    } else {
      keys.add(key);
    }
  }
  return keys;
}

Future<File> getOfflineFile(String filename) async {
  // Get the directory for the app's internal storage
  final directory = await getApplicationDocumentsDirectory();

  // Construct the file path using the filename
  final filePath = File('${directory.path}/$filename');

  return filePath;
}

String getParentDirectory(String workingDir) {
  // remove the last segment of the working directory
  if (workingDir.endsWith('/')) {
    workingDir = workingDir.substring(0, workingDir.length - 1);
  }
  return workingDir.substring(0, workingDir.lastIndexOf('/') + 1);
}

String getStartingDirectory() {
  return pb.authStore.model.id + '/';
}

Future<List<File?>> getUploadSelection() async {
  final result = await fp.FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: fp.FileType.any,
  );

  if (result != null) {
    List<File?> files = result.paths.map((path) => File(path!)).toList();
    return files;
  } else {
    // User canceled the picker
    return [];
  }
}

bool isFileBeingDownloaded(String file, List<DownloadState> downloads) {
  return downloads.any((download) => download.downloadKey == file);
}

Future<bool> isFileSavedOffline(String filename) async {
  // Get the directory for the app's internal storage
  final directory = await getApplicationDocumentsDirectory();

  // Construct the file path using the filename
  final filePath = File('${directory.path}/$filename');

  // Check if the file exists
  return filePath.existsSync();
}

bool isFolderInDirectory(String key, String workingDir) {
  // return true if file name is immediately after workingDir
  return key.startsWith(workingDir) &&
      key.substring(workingDir.length).contains('/');
}

bool isKeyInDirectory(String key, bool folder, String workingDir) {
  if (folder) {
    // remove the last segment of the key
    if (key.endsWith('/')) {
      key = key.substring(0, key.length - 1);
    }
  }
  // return true if file name is immediately after workingDir
  return key.startsWith(workingDir) &&
      !key.substring(workingDir.length).contains('/');
}

void openFile(File file) {
  if (!file.existsSync()) {
    logger.e('File does not exist: ${file.path}');
    return;
  }

  OpenFilex.open(file.path);

  //PackageInfo.fromPlatform().then((package) {
  //  final authority = "${package.packageName}.fileprovider";
  //  final intent = AndroidIntent(
  //    action: 'android.intent.action.VIEW',
  //    data: Uri.parse('content://$authority/app_files${file.path}').toString(),
  //    type: '*/*',
  //  );
//
  //  try {
  //    intent.launch();
  //  } catch (e) {
  //    logger.e('Error launching intent: $e');
  //    // Handle any errors that occur while launching the intent
  //  }
  //});
}

enum FileType { image, video, audio, doc, other, folder }
