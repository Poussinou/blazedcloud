import 'dart:async';
import 'dart:io';

import 'package:blazedcloud/constants.dart';
import 'package:blazedcloud/log.dart';
import 'package:blazedcloud/models/transfers/download_state.dart';
import 'package:blazedcloud/providers/transfers_providers.dart';
import 'package:blazedcloud/services/files_api.dart';
import 'package:blazedcloud/services/notifications.dart';
import 'package:blazedcloud/utils/files_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DownloadController {
  final ProviderRef<Object> _ref;

  DownloadController(this._ref);

  /// returns true if the download was started, false if the file already exists or is already being downloaded
  Future<bool> startDownload(String uid, String fileKey) async {
    // Get the app's internal storage directory
    final appDocDir = await getExportDirectory(true);
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

      if (isFileBeingDownloaded(fileKey, _ref.read(downloadStateProvider))) {
        logger.i('File is already being downloaded: $fileKey');
        return false;
      }
    });

    final downloadState = DownloadState.inProgress(fileKey);
    final downloadNotifier = _ref.read(downloadStateProvider.notifier);
    final int index = downloadNotifier.addDownload(downloadState);

    final token = pb.authStore.token;

    // pause thread if more than 3 downloads are running
    while (_ref
            .read(downloadStateProvider)
            .where((element) => element.isDownloading && !element.isError)
            .length >
        3) {
      await Future.delayed(const Duration(seconds: 1));
    }

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

      response.stream.listen(
        (data) {
          // Handle data chunks and update downloadState.progress
          final totalBytes = response.contentLength ?? 0;
          progress += data.length / totalBytes;
          downloadState.updateProgress(progress);

          // Update the download state with the updated progress
          downloadNotifier.updateDownloadState(index, downloadState);

          // Write the data to the file
          sink.add(data);
        },
        onError: (error) {
          sink.flush().then((_) => sink.close());

          // Handle download error
          downloadState.setError(error.toString());

          // Update the download state with the error
          downloadNotifier.updateDownloadState(index, downloadState);

          updateDownloadNotification();
        },
        onDone: () {
          sink.flush().then((_) => sink.close());

          // Update the download state to reflect completion
          downloadState.completed();

          downloadNotifier.updateDownloadState(index, downloadState);

          updateDownloadNotification();
        },
      );

      updateDownloadNotification();
    } catch (error) {
      logger.e('Download error: $error');

      // Handle download error
      downloadState.setError(error.toString());

      // Update the download state with the error
      downloadNotifier.updateDownloadState(index, downloadState);

      updateDownloadNotification();
    }

    return true;
  }

  void updateDownloadNotification() {
    NotificationService().initNotification().then((_) => NotificationService()
        .showDownloadNotification(_ref
            .read(downloadStateProvider)
            .where((element) => element.isDownloading && !element.isError)
            .length));
  }
}
