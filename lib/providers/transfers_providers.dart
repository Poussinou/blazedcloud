import 'package:blazedcloud/controllers/download_controller.dart';
import 'package:blazedcloud/controllers/upload_controller.dart';
import 'package:blazedcloud/models/transfers/download_state.dart';
import 'package:blazedcloud/models/transfers/upload_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final downloadControllerProvider = Provider<DownloadController>((ref) {
  return DownloadController(ref);
});

final downloadStateProvider =
    StateNotifierProvider<DownloadStateNotifier, List<DownloadState>>(
  (ref) => DownloadStateNotifier(),
);

final uploadControllerProvider = Provider<UploadController>((ref) {
  return UploadController(ref);
});

final uploadStateProvider =
    StateNotifierProvider<UploadStateNotifier, List<UploadState>>(
  (ref) => UploadStateNotifier(),
);

class DownloadStateNotifier extends StateNotifier<List<DownloadState>> {
  DownloadStateNotifier() : super([]);

  int addDownload(DownloadState downloadState) {
    state = [...state, downloadState];
    return state.length -
        1; // Return the index where the download state was added
  }

  void updateDownloadState(int index, DownloadState downloadState) {
    final updatedStates = List.of(state);
    updatedStates[index] = downloadState;
    state = updatedStates;
  }
}

class UploadStateNotifier extends StateNotifier<List<UploadState>> {
  UploadStateNotifier() : super([]);

  int addUpload(UploadState uploadState) {
    state = [...state, uploadState];
    return state.length -
        1; // Return the index where the upload state was added
  }

  void updateUploadState(int index, UploadState uploadState) {
    final updatedStates = List.of(state);
    updatedStates[index] = uploadState;
    state = updatedStates;
  }
}
