part of travel_agent_app;

enum ChatAttachmentSource { camera, photos, videos, files }

class ChatAttachmentService {
  ChatAttachmentService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  static const maximumUploadBytes = 50 * 1024 * 1024;

  final ImagePicker _imagePicker;

  bool get cameraAvailable {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  Future<PendingChatAttachment?> pick({
    required ChatAttachmentSource source,
    required ImageQualityPreference imageQuality,
  }) async {
    return switch (source) {
      ChatAttachmentSource.camera => _pickImage(
        source: ImageSource.camera,
        imageQuality: imageQuality,
      ),
      ChatAttachmentSource.photos => _pickImage(
        source: ImageSource.gallery,
        imageQuality: imageQuality,
      ),
      ChatAttachmentSource.videos => _pickVideo(),
      ChatAttachmentSource.files => _pickFile(),
    };
  }

  Future<PendingChatAttachment?> _pickImage({
    required ImageSource source,
    required ImageQualityPreference imageQuality,
  }) async {
    if (source == ImageSource.camera && !cameraAvailable) {
      throw StateError('Camera capture is not available on this device.');
    }
    final quality = switch (imageQuality) {
      ImageQualityPreference.high => 90,
      ImageQualityPreference.balanced => 72,
      ImageQualityPreference.low => 52,
    };
    final maximumDimension = switch (imageQuality) {
      ImageQualityPreference.high => 1920.0,
      ImageQualityPreference.balanced => 1280.0,
      ImageQualityPreference.low => 800.0,
    };
    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: quality,
      maxWidth: maximumDimension,
      maxHeight: maximumDimension,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return _fromXFile(file);
  }

  Future<PendingChatAttachment?> _pickVideo() async {
    final file = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (file == null) return null;
    return _fromXFile(file);
  }

  Future<PendingChatAttachment?> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw StateError('The selected file could not be read.');
    }
    return _buildAttachment(
      name: file.name,
      mimeType: _mimeTypeForName(file.name),
      bytes: bytes,
    );
  }

  Future<PendingChatAttachment> _fromXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    return _buildAttachment(
      name: file.name,
      mimeType: file.mimeType ?? _mimeTypeForName(file.name),
      bytes: bytes,
    );
  }

  PendingChatAttachment _buildAttachment({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) {
    if (bytes.lengthInBytes > maximumUploadBytes) {
      throw StateError('The selected file must be smaller than 50 MB.');
    }
    return PendingChatAttachment(
      name: name,
      mimeType: mimeType,
      type: _attachmentType(name, mimeType),
      bytes: bytes,
    );
  }
}

String _attachmentType(String name, String mimeType) {
  final normalizedName = name.toLowerCase();
  final normalizedMime = mimeType.toLowerCase();
  if (normalizedMime == 'image/gif' || normalizedName.endsWith('.gif')) {
    return 'gif';
  }
  if (normalizedMime.startsWith('image/')) return 'image';
  if (normalizedMime.startsWith('video/')) return 'video';
  if (normalizedMime == 'application/pdf' || normalizedName.endsWith('.pdf')) {
    return 'pdf';
  }
  return 'file';
}

String _mimeTypeForName(String name) {
  final normalized = name.toLowerCase();
  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (normalized.endsWith('.png')) return 'image/png';
  if (normalized.endsWith('.gif')) return 'image/gif';
  if (normalized.endsWith('.webp')) return 'image/webp';
  if (normalized.endsWith('.mp4')) return 'video/mp4';
  if (normalized.endsWith('.mov')) return 'video/quicktime';
  if (normalized.endsWith('.webm')) return 'video/webm';
  if (normalized.endsWith('.pdf')) return 'application/pdf';
  if (normalized.endsWith('.txt')) return 'text/plain';
  if (normalized.endsWith('.zip')) return 'application/zip';
  return 'application/octet-stream';
}
