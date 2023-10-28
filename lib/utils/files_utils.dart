import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:blazedcloud/constants.dart';
import 'package:blazedcloud/log.dart';
import 'package:blazedcloud/models/files_api/list_files.dart';
import 'package:blazedcloud/models/transfers/download_state.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

bool CheckIfAccessToDownloadDirectoryIsGranted() {
  // Check if the user has granted access to the download directory
  final box = Hive.box<String>('files');
  final downloadDirectory = box.get('downloadDirectory');

  if (downloadDirectory == null) {
    return false;
  } else {
    return true;
  }
}

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

Future<File> decryptFile(File encryptedFile) async {
  // Get the password from Hive (if needed)
  // final box = await Hive.openBox<String>('files');
  // final password = box.get('password');
  //const password = 'Apples123!';

  //if (password == null) {
  //  logger.e('Password not found');
  //  throw Exception('Password not found');
  //}

  // Hash the password to create a 32-byte key (not needed for Fernet)
  //final keyHash = sha256.convert(utf8.encode(password)).bytes;
  //final key = Key(Uint8List.fromList(keyHash));
  final key = Key.fromUtf8('my32lengthsupersecretnooneknows1');
  final b64key = Key.fromBase64(base64Url.encode(key.bytes));

  try {
    // Read the encrypted file content
    final Uint8List encryptedContent = await encryptedFile.readAsBytes();

    // Create a Fernet decrypter with the key
    final decrypter = Encrypter(Fernet(b64key));

    // Decrypt the encrypted content
    final decryptedBytes = decrypter.decryptBytes(Encrypted(encryptedContent));

    // Get the application's temporary directory
    final tempDir = await getApplicationCacheDirectory();
    final tempFilePath =
        '${tempDir.path}/${encryptedFile.uri.pathSegments.last}.dec';

    // Write the decrypted content to a temporary file
    final decryptedFile = File(tempFilePath);
    //await decryptedFile.writeAsBytes(decryptedBytes);

    return decryptedFile;
  } catch (e) {
    logger.e('Error decrypting file: $e');
    throw Exception('Error decrypting file: $e');
  }
}

Future<http.StreamedResponse> decryptStreamedResponse(
    http.StreamedResponse encryptedResponse, String password) async {
  // hash the password to 32 bits
  final keyHash =
      Uint8List.fromList(sha512.convert(utf8.encode(password)).bytes);
  final key = Key(Uint8List.fromList(keyHash.sublist(0, 32)));

  // Create an IV buffer to store the IV received from the encrypted stream
  final ivBuffer = <int>[];

  // Initialize the Salsa20 decryption algorithm with the password
  final encrypter = Encrypter(Salsa20(key));

  // Function to handle incoming data and decrypt
  final decryptedStream = encryptedResponse.stream.transform<Uint8List>(
      StreamTransformer<List<int>, Uint8List>.fromHandlers(
    handleData: (data, sink) {
      try {
        if (ivBuffer.length < 8) {
          // Collect the IV bytes
          ivBuffer.addAll(data.take(8 - ivBuffer.length));
          if (ivBuffer.length == 8) {
            // We have enough IV bytes, initialize a new encrypter with IV
            final iv = IV(Uint8List.fromList(ivBuffer));
            final encrypted = Encrypted(Uint8List.fromList(data.sublist(8)));
            final decryptedData = encrypter.decryptBytes(encrypted, iv: iv);
            sink.add(Uint8List.fromList(decryptedData));
          }
        } else {
          // Decrypt the data using the existing IV
          final encrypted = Encrypted(Uint8List.fromList(data));
          final decryptedData = encrypter.decryptBytes(encrypted);
          sink.add(Uint8List.fromList(decryptedData));
        }
      } catch (error) {
        logger.i('Error during decryption: $error');
      } finally {
        // Clear the IV buffer
        ivBuffer.clear();

        // Close the sink
        sink.close();

        // Close the stream
        encryptedResponse.stream.drain();
      }
    },
  ));

  final headers = Map<String, String>.from(encryptedResponse.headers);

  await encryptedResponse.stream.drain(); // Ensure all data is consumed

  return http.StreamedResponse(
    decryptedStream,
    encryptedResponse.statusCode,
    headers: headers,
    contentLength: encryptedResponse.contentLength,
    request: encryptedResponse.request,
    reasonPhrase: encryptedResponse.reasonPhrase,
  );
}

Future<http.ByteStream> encryptByteStream(
    http.ByteStream inputByteStream, String password) async {
  // hash the password to 32 bits
  final keyHash =
      Uint8List.fromList(sha512.convert(utf8.encode(password)).bytes);
  final key = Key(Uint8List.fromList(keyHash.sublist(0, 32)));

  // Generate a random IV (Initialization Vector)
  final iv = IV.fromSecureRandom(8);

  // Create a StreamController to transform the input stream and make it broadcast
  final controller = StreamController<List<int>>.broadcast();

  // Encrypt the input data with the IV
  final encrypter = Encrypter(Salsa20(key));

  inputByteStream.listen(
    (data) {
      final encryptedData = encrypter.encryptBytes(data, iv: iv);
      controller.add([...iv.bytes, ...encryptedData.bytes]);
    },
    onError: (error) {
      controller.addError(error);
      controller.close();
    },
    onDone: () {
      controller.close();
    },
  );

  final encryptedStream = http.ByteStream(controller.stream);

  return encryptedStream;
}

Future<File> encryptFile(File inputFile) async {
  // Get the password from Hive
  // final box = await Hive.openBox<String>('files');
  // final password = box.get('password');
  //const password = 'Apples123!';

  //if (password == null) {
  //  logger.e('Password not found');
  //  throw Exception('Password not found');
  //}

  // Hash the password to create a 32-byte key (not needed for Fernet)
  //final keyHash = sha256.convert(utf8.encode(password)).bytes;
  //final key = Key(Uint8List.fromList(keyHash));
  final key = Key.fromUtf8('my32lengthsupersecretnooneknows1');
  final b64key = Key.fromBase64(base64Url.encode(key.bytes));

  if (!await inputFile.exists()) {
    throw FileSystemException('File not found: ${inputFile.path}');
  }

  // Read the input file content
  final Uint8List fileContent = await inputFile.readAsBytes();

  // Create a Fernet encrypter with the generated key
  final encrypter = Encrypter(Fernet(b64key));

  // Encrypt the file content
  final encryptedBytes = encrypter.encryptBytes(fileContent);

  // Get the application's temporary directory
  final tempDir = await getApplicationCacheDirectory();
  final tempFilePath = '${tempDir.path}/${inputFile.uri.pathSegments.last}';
  logger.d('Temporary file path: $tempFilePath');

  // Write the encrypted content to a temporary file
  final encryptedFile = File(tempFilePath);
  await encryptedFile.writeAsBytes(encryptedBytes.bytes);

  return encryptedFile;
}

String filterUidFromKey(String key) {
  // if the key starts with the uid + /, remove it
  if (key.startsWith(pb.authStore.model.id + '/')) {
    return key.substring(pb.authStore.model.id.length + 1);
  } else {
    return key;
  }
}

String formatMinutes(int minutes) {
  // Format the minutes into a string using format 15m or 1h45m or 24h10m
  if (minutes < 60) {
    return '${minutes}m';
  } else {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '${hours}h';
    } else {
      return '${hours}h${remainingMinutes}m';
    }
  }
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

/// Get the download directory from Hive or prompt the user to select one.
Future<String> getExportDirectory(bool promptForDirectory) async {
  // check if Hive has a download directory saved
  final box = await Hive.openBox<String>('files');
  final downloadDirectory = box.get('downloadDirectory');

  if (downloadDirectory != null) {
    // check if the directory still exists or we still have access to it
    final directory = Directory(downloadDirectory);
    if (await directory.exists()) {
      // Hive has a download directory saved, so return
      logger.i('Download directory: $downloadDirectory');
      return downloadDirectory;
    }
  } else if (!promptForDirectory) {
    return '';
  }

  // toast
  Fluttertoast.showToast(
      msg: "Select a folder to store downloaded files",
      toastLength: Toast.LENGTH_LONG,
      fontSize: 16.0);

  final result = await fp.FilePicker.platform.getDirectoryPath();

  if (result != null) {
    // User selected a directory
    logger.i('User selected directory: $result');

    // Save the directory to Hive
    box.put('downloadDirectory', result);

    return result;
  } else {
    // User canceled the picker
    logger.i('User canceled directory picker');
    return '';
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
      fileName.endsWith('.png') ||
      fileName.endsWith('.hevc') ||
      fileName.endsWith('.gif')) {
    return FileType.image;
  } else if (fileName.endsWith('.mp4') ||
      fileName.endsWith('.avi') ||
      fileName.endsWith('.mkv')) {
    return FileType.video;
  } else if (fileName.endsWith('.mp3') ||
      fileName.endsWith('.wav') ||
      fileName.endsWith('.flac') ||
      fileName.endsWith('.m4a') ||
      fileName.endsWith('.aac')) {
    return FileType.audio;
  } else if (fileName.endsWith('.doc') ||
      fileName.endsWith('.docx') ||
      fileName.endsWith('.xls') ||
      fileName.endsWith('.xlsx') ||
      fileName.endsWith('.ppt') ||
      fileName.endsWith('.pptx') ||
      fileName.endsWith('.txt') ||
      fileName.endsWith('.rtf') ||
      fileName.endsWith('.csv') ||
      fileName.endsWith('.xml') ||
      fileName.endsWith('.json') ||
      fileName.endsWith('.html') ||
      fileName.endsWith('.htm') ||
      fileName.endsWith('.log') ||
      fileName.endsWith('.md') ||
      fileName.endsWith('.odt') ||
      fileName.endsWith('.ods') ||
      fileName.endsWith('.odp') ||
      fileName.endsWith('.odg') ||
      fileName.endsWith('.odf') ||
      fileName.endsWith('.epub') ||
      fileName.endsWith('.mobi') ||
      fileName.endsWith('.azw') ||
      fileName.endsWith('.azw3') ||
      fileName.endsWith('.djvu') ||
      fileName.endsWith('.fb2') ||
      fileName.endsWith('.xps') ||
      fileName.endsWith('.ps') ||
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

List<String> getKeysInFolder(
    ListBucketResult list, String folderKey, bool keepFullKey) {
  if (list.contents == null) {
    return [];
  }

  List<String> keys = [];
  for (var item in list.contents!) {
    final key = item.key;

    if (key!.startsWith(folderKey)) {
      if (keepFullKey) {
        keys.add(key);
      } else {
        keys.add(key.substring(folderKey.length));
      }
    }
  }
  return keys;
}

Future<File> getOfflineFile(String filename) async {
  // Get the directory for the app's internal storage
  final directory = await getExportDirectory(false);

  // Construct the file path using the filename
  final filePath = File('$directory/$filename');

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
  for (var download in downloads) {
    if (download.downloadKey == file && download.isDownloading) {
      return true;
    }
  }
  return false;
}

Future<bool> isFileSavedOffline(String filename) async {
  // Get the directory for the app's internal storage
  //final directory = await getApplicationDocumentsDirectory();
  final directory = await getExportDirectory(false);

  // Construct the file path using the filename
  final filePath = File('$directory/$filename');

  // Check if the file exists
  return filePath.exists();
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
  file.exists().then((exists) {
    if (exists) {
      OpenFilex.open(file.path);
    } else {
      logger.e('File does not exist: ${file.path}');
    }
  });
}

enum FileType { image, video, audio, doc, other, folder }
