import 'dart:async';
import 'dart:io';

import 'package:blazedcloud/constants.dart';
import 'package:blazedcloud/log.dart';
import 'package:blazedcloud/models/transfers/upload_state.dart';
import 'package:blazedcloud/providers/files_providers.dart';
import 'package:blazedcloud/providers/transfers_providers.dart';
import 'package:blazedcloud/services/files_api.dart';
import 'package:blazedcloud/services/notifications.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class UploadController {
  final ProviderRef<Object> _ref;

  UploadController(this._ref);

  void selectFilesToUpload(String directory) async {
    final file = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (file != null) {
      final files = file.paths.map((path) => File(path!)).toList();
      final uid = pb.authStore.model.id;

      for (final fileToUpload in files) {
        startUpload(uid, fileToUpload, directory);
      }
    }
  }

  Future<void> startUpload(
      String uid, File fileToUpload, String directory) async {
    final uploadState = UploadState.inProgress(fileToUpload.path);
    final uploadNotifier = _ref.read(uploadStateProvider.notifier);
    final int index = uploadNotifier.addUpload(uploadState);

    final token = pb.authStore.token;
    final fileKey = '$directory${fileToUpload.path.split('/').last}';

    try {
      final totalBytes = fileToUpload.lengthSync();
      final bytes = http.ByteStream(fileToUpload.openRead());

      final response = await uploadFile(
        uid,
        fileKey,
        bytes,
        token,
      );

      NotificationService().initNotification().then((_) => NotificationService()
          .showUploadNotification(NotificationService().uploads + 1));

      // Add a progress callback to the response stream
      response.stream.listen(
        (data) {
          // Calculate progress and update the upload state
          final sent = data.length;
          final progress = sent / totalBytes;
          uploadState.updateProgress(progress);

          logger.i('Upload progress: $progress');

          // Update the upload state with the updated progress
          uploadNotifier.updateUploadState(index, uploadState);
        },
        onError: (error) {
          logger.e('Upload error: $error');

          // Handle any errors during the upload
          uploadState.setError(error.toString());
          uploadNotifier.updateUploadState(index, uploadState);

          NotificationService().initNotification().then((_) =>
              NotificationService()
                  .showUploadNotification(NotificationService().uploads - 1));
        },
        onDone: () {
          logger.i('Upload done');

          // Handle upload completion
          uploadState.completed();
          uploadNotifier.updateUploadState(index, uploadState);

          // Update the file list
          _ref.invalidate(fileListProvider);

          NotificationService().initNotification().then((_) =>
              NotificationService()
                  .showUploadNotification(NotificationService().uploads - 1));
        },
        cancelOnError: true,
      );
    } catch (error) {
      uploadState.setError(error.toString());
      uploadNotifier.updateUploadState(index, uploadState);
    }
  }
}
