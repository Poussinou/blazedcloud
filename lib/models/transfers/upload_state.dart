class UploadState {
  bool isUploading;
  bool isError;
  String? errorMessage;
  double progress;
  String uploadKey;
  double sent = 0.0;

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
  factory UploadState.fromJson(Map<String, dynamic> json) {
    return UploadState(
      isUploading: json['isUploading'] ?? false,
      isError: json['isError'] ?? false,
      errorMessage: json['errorMessage'],
      progress: json['progress'] ?? 0.0,
      uploadKey: json['uploadKey'] ?? '',
    );
  }
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

  void addTotalSent(int sent) {
    this.sent += sent;
  }

  void completed() => isUploading = false;

  void setError(String errorMessage) {
    isError = true;
    isUploading = false;
    this.errorMessage = errorMessage;
  }

  Map<String, dynamic> toJson() {
    return {
      'isUploading': isUploading,
      'isError': isError,
      'errorMessage': errorMessage,
      'progress': progress,
      'uploadKey': uploadKey,
    };
  }

  void updateProgress(double newProgress) {
    progress = newProgress;
  }
}
