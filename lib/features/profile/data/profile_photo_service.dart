part of travel_agent_app;

enum ProfilePhotoSource { camera, gallery }

class ProfilePhotoService {
  ProfilePhotoService({ImagePicker? picker, FirebaseStorage? storage})
    : _picker = picker ?? ImagePicker(),
      _storage = storage ?? FirebaseStorage.instance;

  static const _maximumUploadBytes = 5 * 1024 * 1024;

  final ImagePicker _picker;
  final FirebaseStorage _storage;

  bool get cameraAvailable {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  Future<String?> pickAndUpload({
    required String userId,
    required ProfilePhotoSource source,
    required ImageQualityPreference imageQuality,
  }) async {
    if (source == ProfilePhotoSource.camera && !cameraAvailable) {
      throw StateError('Camera capture is not available on this device.');
    }

    final settings = switch (imageQuality) {
      ImageQualityPreference.high => (quality: 90, maximumDimension: 1600.0),
      ImageQualityPreference.balanced => (
        quality: 72,
        maximumDimension: 1024.0,
      ),
      ImageQualityPreference.low => (quality: 52, maximumDimension: 640.0),
    };
    final image = await _picker.pickImage(
      source: source == ProfilePhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: settings.quality,
      maxWidth: settings.maximumDimension,
      maxHeight: settings.maximumDimension,
      requestFullMetadata: false,
    );
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    if (bytes.length > _maximumUploadBytes) {
      throw StateError('The selected image must be smaller than 5 MB.');
    }

    final contentType = image.mimeType ?? _contentTypeForName(image.name);
    final reference = _storage.ref('user_avatars/$userId/profile');
    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        cacheControl: 'public,max-age=3600',
      ),
    );
    final url = await reference.getDownloadURL();
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> deleteForUser(String userId) async {
    try {
      await _storage.ref('user_avatars/$userId/profile').delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  String _contentTypeForName(String name) {
    final normalized = name.toLowerCase();
    if (normalized.endsWith('.png')) return 'image/png';
    if (normalized.endsWith('.webp')) return 'image/webp';
    if (normalized.endsWith('.heic') || normalized.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }
}
