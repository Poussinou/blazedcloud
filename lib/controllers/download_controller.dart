import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:blazedcloud/constants.dart';
import 'package:blazedcloud/log.dart';
import 'package:blazedcloud/models/transfers/download_state.dart';
import 'package:blazedcloud/providers/transfers_providers.dart';
import 'package:blazedcloud/services/files_api.dart';
import 'package:blazedcloud/services/notifications.dart';
import 'package:blazedcloud/utils/files_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

class DownloadController {
  final ProviderRef<DownloadController> _ref;

  DownloadController(this._ref) {
    final port = _ref.read(downloadReceivePortProvider);
    IsolateNameServer.registerPortWithName(port.sendPort, "downloader");
    port.listen((dynamic data) async {
      try {
        final downloadState = DownloadState.fromJson(jsonDecode(data));

        final downloadNotifier = _ref.read(downloadStateProvider.notifier);

        downloadNotifier.updateDownloadStateByKey(
            downloadState.downloadKey, downloadState);

        updateDownloadNotification();
      } catch (error) {
        logger.e('Error updating download state: $error');
      }
    });
  }

  /// start a download with workmanager
  void queueDownload(String uid, String fileKey) async {
    getOfflineFile(fileKey).then((value) {
      if (value.existsSync()) {
        logger.i('File already exists: ${value.path}');
        return false;
      }
    });

    Workmanager().registerOneOffTask(fileKey.hashCode.toString(), "download",
        constraints: Constraints(
            networkType: NetworkType.unmetered, requiresStorageNotLow: true),
        tag: fileKey,
        backoffPolicy: BackoffPolicy.linear,
        outOfQuotaPolicy: OutOfQuotaPolicy.run_as_non_expedited_work_request,
        existingWorkPolicy: ExistingWorkPolicy.keep,
        inputData: {
          "uid": uid,
          "fileKey": fileKey,
          "exportDir": await getExportDirectoryFromHive(),
          "token": pb.authStore.token,
        });
  }

  void updateDownloadNotification() {
    NotificationService().initNotification().then((_) => NotificationService()
        .showDownloadNotification(_ref
            .read(downloadStateProvider)
            .where((element) => element.isDownloading && !element.isError)
            .length));
  }

  /// returns true if the download was started, false if the file already exists or is already being downloaded.
  ///
  /// Call this directly to bypass using workmanager
  static Future<bool> startDownload(
      String uid, String fileKey, String token, String appDocDir) async {
    SendPort? sendPort = IsolateNameServer.lookupPortByName("downloader");
    final filePath = '$appDocDir/$fileKey'; // Define the file path

    if (appDocDir.isEmpty) {
      logger.e('Could not get appDocDir');
      return false;
    }

    getOfflineFile(fileKey).then((value) {
      if (value.existsSync()) {
        logger.i('File already exists: ${value.path}');
        return false;
      }
    });

    final downloadState = DownloadState.inProgress(fileKey);
    final completer = Completer<bool>();
    try {
      final response = await getFile(uid, fileKey, token);

      // Ensure the directory exists
      final directory = Directory(appDocDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Initialize progress to 0
      double progress = 0.0;

      final file = File(filePath);

      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      final sink = file.openWrite();

      const Duration rateLimit =
          Duration(seconds: 1); // Adjust the duration as needed
      DateTime lastDataSentTime = DateTime.now();

      response.stream.listen((data) async {
        final totalBytes = response.contentLength ?? 0;
        progress += data.length / totalBytes;
        downloadState.updateProgress(progress);

        sink.add(data);

        // The port might be null if the main isolate is not running.
        if (sendPort != null) {
          // rate limit to prevent spamming the main isolate
          if (DateTime.now().difference(lastDataSentTime) >= rateLimit) {
            try {
              sendPort!.send(jsonEncode(downloadState.toJson()));
            } catch (error) {
              logger.e('send port error ($fileKey): $error');
            }
            lastDataSentTime = DateTime.now();
          }
        } else {
          sendPort = IsolateNameServer.lookupPortByName("downloader");
        }
      }, onError: (error) {
        logger.e('Download error: $error');
        sink.flush().then((_) => sink.close());
        downloadState.setError(error.toString());
        completer.complete(false);

        if (sendPort != null) {
          try {
            sendPort!.send(jsonEncode(downloadState.toJson()));
          } catch (error) {
            logger.e('send port error ($fileKey): $error');
          }
        }
      }, onDone: () {
        logger.i('Download complete');
        sink.flush().then((_) => sink.close());
        downloadState.completed();
        completer.complete(true);

        if (sendPort != null) {
          try {
            sendPort!.send(jsonEncode(downloadState.toJson()));
          } catch (error) {
            logger.e('send port error ($fileKey): $error');
          }
        }
      }, cancelOnError: true);
    } catch (error) {
      logger.e('Download error: $error');
      downloadState.setError(error.toString());
      completer.complete(false);

      if (sendPort != null) {
        try {
          sendPort!.send(jsonEncode(downloadState.toJson()));
        } catch (error) {
          logger.e('send port error ($fileKey): $error');
        }
      }
    }

    return completer.future;
  }
}
