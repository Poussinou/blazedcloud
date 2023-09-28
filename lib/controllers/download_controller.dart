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

  Future<void> startDownload(String uid, String fileKey) async {
    final downloadState = DownloadState.inProgress(fileKey);
    final downloadNotifier = _ref.read(downloadStateProvider.notifier);
    final int index = downloadNotifier.addDownload(downloadState);

    final token = pb.authStore.token;

    try {
      final response = await getFile(uid, fileKey, token);

      // Get the app's internal storage directory
      final appDocDir = await geExportDirectory();
      final filePath = '$appDocDir/$fileKey'; // Define the file path

      // Ensure the directory exists
      final directory = Directory(appDocDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Initialize progress to 0
      double progress = 0.0;

      final file = File(filePath);

      if (!await file.exists()) {
        // Ensure the file exists before opening it
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
          // Handle download error
          downloadState.setError(error.toString());

          // Update the download state with the error
          downloadNotifier.updateDownloadState(index, downloadState);
        },
        onDone: () async {
          // When download is complete, close the file sink
          await sink.close();

          // Update the download state to reflect completion
          downloadState.completed();

          downloadNotifier.updateDownloadState(index, downloadState);
        },
      );

      final downloadStates = _ref.watch(downloadStateProvider);

      final activeDownloads =
          downloadStates.where((state) => state.isDownloading).toList();

      if (activeDownloads.isNotEmpty) {
        NotificationService().initNotification().then((_) =>
            NotificationService()
                .showDownloadNotification(activeDownloads.length));
      }
    } catch (error) {
      logger.e('Download error: $error');

      // Handle download error
      downloadState.setError(error.toString());

      // Update the download state with the error
      downloadNotifier.updateDownloadState(index, downloadState);
    }
  }
}
