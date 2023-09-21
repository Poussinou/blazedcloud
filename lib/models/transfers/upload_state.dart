class UploadState {
  bool isUploading;
  bool isError;
  String? errorMessage;
  double progress;
  String uploadKey;

  UploadState({
    required this.isUploading,
    required this.isError,
    this.errorMessage,
    this.progress = 0.0,
    required this.uploadKey,
  });

  factory UploadState.error(String errorMessage) => UploadState(
        isUploading: false,
        isError: true,
        errorMessage: errorMessage,
        uploadKey: '',
      );
  factory UploadState.idle() => UploadState(
        isUploading: false,
        isError: false,
        uploadKey: '',
      );
  factory UploadState.inProgress(String name) => UploadState(
        isUploading: true,
        isError: false,
        uploadKey: name,
      );

  void completed() => isUploading = false;

  void setError(String errorMessage) {
    isError = true;
    this.errorMessage = errorMessage;
  }

  void updateProgress(double newProgress) {
    progress = newProgress;
  }
}
