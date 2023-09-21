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
    this.errorMessage = errorMessage;
  }

  void updateProgress(double newProgress) {
    progress = newProgress;
  }
}
