import 'package:blazedcloud/log.dart';

class DownloadState {
  bool isDownloading;
  bool isError;
  String? errorMessage;
  double progress;
  String downloadKey;

  DownloadState({
    required this.isDownloading,
    required this.isError,
    this.errorMessage,
    this.progress = 0.0,
    required this.downloadKey,
  });

  factory DownloadState.error(String errorMessage) => DownloadState(
        isDownloading: false,
        isError: true,
        errorMessage: errorMessage,
        downloadKey: '',
      );
  factory DownloadState.fromJson(Map<String, dynamic> json) {
    return DownloadState(
      isDownloading: json['isDownloading'] ?? false,
      isError: json['isError'] ?? false,
      errorMessage: json['errorMessage'],
      progress: json['progress'] ?? 0.0,
      downloadKey: json['downloadKey'] ?? '',
    );
  }
  factory DownloadState.idle() => DownloadState(
        isDownloading: false,
        isError: false,
        downloadKey: '',
      );
  factory DownloadState.inProgress(String name) => DownloadState(
        isDownloading: true,
        isError: false,
        downloadKey: name,
      );

  void completed() => isDownloading = false;

  void setError(String errorMessage) {
    isError = true;
    isDownloading = false;
    this.errorMessage = errorMessage;
    logger.e(errorMessage);
  }

  Map<String, dynamic> toJson() {
    return {
      'isDownloading': isDownloading,
      'isError': isError,
      'errorMessage': errorMessage,
      'progress': progress,
      'downloadKey': downloadKey,
    };
  }

  void updateProgress(double newProgress) {
    progress = newProgress;
  }
}
