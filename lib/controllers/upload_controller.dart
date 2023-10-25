import 'dart:async';

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
    final selection = await FilePicker.platform.pickFiles(
        allowMultiple: true, type: FileType.any, withReadStream: true);

    if (selection != null) {
      final uid = pb.authStore.model.id;

      for (final fileToUpload in selection.files) {
        startUpload(uid, fileToUpload, directory);
      }
    }
  }

  // TODO: move some of the logic to file_api.dart
  Future<void> startUpload(
      String uid, PlatformFile platformFile, String directory) async {
    final uploadState = UploadState.inProgress(platformFile.path!);
    final uploadNotifier = _ref.read(uploadStateProvider.notifier);
    final int index = uploadNotifier.addUpload(uploadState);

    final token = pb.authStore.token;
    final fileKey = '$directory${platformFile.name}';

    // create request
    final uploadUrl = await getUploadUrl(uid, fileKey, token);
    logger.i('Upload url: $uploadUrl');
    final request = http.StreamedRequest("PUT", Uri.parse(uploadUrl));

    try {
      final totalBytes = platformFile.size;
      final bytes = platformFile.readStream!.asBroadcastStream();

      // Add a progress callback to the response stream
      bytes.listen((data) {
        // Calculate progress and update the upload state
        uploadState.addTotalSent(data.length);
        final sent = uploadState.sent;
        final progress = sent / totalBytes;
        uploadState.updateProgress(progress);

        // Update the upload state with the updated progress
        uploadNotifier.updateUploadState(index, uploadState);
      }, onError: (error) {
        logger.e('Upload error: $error');
        try {
          request.sink.close();
        } catch (e) {
          logger.e('Error closing request sink: $e');
        }

        // Handle any errors during the upload
        uploadState.setError(error.toString());
        uploadState.completed();
        uploadNotifier.updateUploadState(index, uploadState);

        updateUploadNotification();
      }, onDone: () {
        logger.i('Upload done');

        // Handle upload completion
        uploadState.completed();
        uploadNotifier.updateUploadState(index, uploadState);

        updateUploadNotification();
        _ref.invalidate(fileListProvider(""));
      }, cancelOnError: true);

      request.contentLength = totalBytes;
      request.sink.addStream(bytes);
      await httpClient.send(request).then((response) {
        response.stream
            .drain()
            .then((_) => _ref.invalidate(fileListProvider("")));
      });
    } catch (error) {
      logger.e('Upload error: $error');

      uploadState.setError(error.toString());
      uploadState.completed();
      uploadNotifier.updateUploadState(index, uploadState);

      updateUploadNotification();

      request.sink.close();
    }
  }

  void updateUploadNotification() {
    NotificationService().initNotification().then((_) => NotificationService()
        .showUploadNotification(_ref
            .read(uploadStateProvider)
            .where((element) => element.isUploading && !element.isError)
            .length));
  }
}
