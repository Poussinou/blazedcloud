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
    final file = File(platformFile.path!);
    final int index = uploadNotifier.addUpload(uploadState);

    final token = pb.authStore.token;
    final fileKey = '$directory${platformFile.name}';

    try {
      final totalBytes = platformFile.size;

      final uploadUrl = await getUploadUrl(uid, fileKey, token);
      logger.i('Upload url: $uploadUrl');

      // create request
      final request = http.StreamedRequest("PUT", Uri.parse(uploadUrl));
      final bytes = platformFile.readStream!.asBroadcastStream();

      updateUploadNotification();

      // Add a progress callback to the response stream
      bytes.listen(
        (data) {
          // Calculate progress and update the upload state
          uploadState.addTotalSent(data.length);
          final sent = uploadState.sent;
          final progress = sent / totalBytes;
          uploadState.updateProgress(progress);

          // Update the upload state with the updated progress
          uploadNotifier.updateUploadState(index, uploadState);
        },
        onError: (error) {
          logger.e('Upload error: $error');
          request.sink.close();

          // Handle any errors during the upload
          uploadState.setError(error.toString());
          uploadState.completed();
          uploadNotifier.updateUploadState(index, uploadState);

          updateUploadNotification();
        },
        onDone: () {
          logger.i('Upload done');
          request.sink.close();

          // Handle upload completion
          uploadState.completed();
          uploadNotifier.updateUploadState(index, uploadState);

          // Update the file list
          _ref.invalidate(fileListProvider);

          updateUploadNotification();
        },
      );

      request.contentLength = totalBytes;
      request.sink.addStream(bytes);
      final response = await httpClient.send(request);
      logger.d(
          'Upload response: ${response.statusCode} \n ${response.reasonPhrase}');
    } catch (error) {
      logger.e('Upload error: $error');

      uploadState.setError(error.toString());
      uploadState.completed();
      uploadNotifier.updateUploadState(index, uploadState);

      updateUploadNotification();
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
