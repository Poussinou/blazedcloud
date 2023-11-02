import 'dart:async';

import 'package:blazedcloud/constants.dart';
import 'package:blazedcloud/log.dart';
import 'package:blazedcloud/models/transfers/upload_state.dart';
import 'package:blazedcloud/pages/settings/usage_card.dart';
import 'package:blazedcloud/providers/files_providers.dart';
import 'package:blazedcloud/providers/transfers_providers.dart';
import 'package:blazedcloud/services/files_api.dart';
import 'package:blazedcloud/services/notifications.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

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
    final type =
        lookupMimeType(platformFile.path!) ?? 'application/octet-stream';

    try {
      final uploadUrl = await getUploadUrl(
        uid,
        fileKey,
        token,
        platformFile.size,
        contentType: type,
      );
      logger.i('Upload url: $uploadUrl');

      final dio = Dio();
      bytes() async* {
        yield* platformFile.readStream!;
      }

      final multipartFile = MultipartFile.fromStream(
        bytes,
        platformFile.size,
        filename: platformFile.name,
        contentType: MediaType.parse(type),
      );

      final response = await dio.put(
        uploadUrl,
        data: multipartFile.finalize(),
        options: Options(headers: {
          "Content-Type": type,
          "Content-Length": platformFile.size
        }),
        onSendProgress: (int sent, int total) {
          uploadState.addTotalSent(total);
          final progress = total / platformFile.size;
          uploadState.updateProgress(progress);
        },
      );
      uploadState.completed();

      logger.i(
          'Upload response: ${response.statusCode} ${response.statusMessage}');
    } catch (error) {
      switch (error) {
        case DioException():
          final response = error.response;
          logger.e('Error uploading file: ${error.message} - $response');
        default:
          logger.e('Upload error: $error');
      }

      uploadState.setError(error.toString());
      uploadState.completed();
      uploadNotifier.updateUploadState(index, uploadState);

      updateUploadNotification();
    } finally {
      _ref.invalidate(fileListProvider(""));
      _ref.invalidate(combinedDataProvider(pb.authStore.model.id));
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
