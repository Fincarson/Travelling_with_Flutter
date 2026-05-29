part of travel_agent_app;

class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.interests,
    this.language = 'en',
    this.notificationsEnabled = true,
    this.themeMode = 'Light',
  });
  final String name;
  final String email;
  final List<String> interests;
  final String language;
  final bool notificationsEnabled;
  final String themeMode;

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'interests': interests,
    'settings': {
      'language': language,
      'notificationsEnabled': notificationsEnabled,
      'themeMode': themeMode,
    },
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static UserProfile fromMap(Map<String, dynamic> map) {
    final settings = Map<String, dynamic>.from(
      (map['settings'] as Map?) ?? const <String, dynamic>{},
    );
    return UserProfile(
      name: (map['name'] as String?) ?? 'Explorer',
      email: (map['email'] as String?) ?? '',
      interests: ((map['interests'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(),
      language: (settings['language'] as String?) ?? 'en',
      notificationsEnabled: (settings['notificationsEnabled'] as bool?) ?? true,
      themeMode: (settings['themeMode'] as String?) ?? 'Light',
    );
  }
}

String _languageLabel(String language) {
  return switch (language) {
    'id' => 'Indonesian',
    'zh' => 'Chinese (Traditional)',
    'ja' => 'Japanese',
    'ko' => 'Korean',
    'es' => 'Spanish',
    'fr' => 'French',
    'de' => 'German',
    'it' => 'Italian',
    'pt' => 'Portuguese',
    'th' => 'Thai',
    'vi' => 'Vietnamese',
    'ar' => 'Arabic',
    _ => 'English (US)',
  };
}

String _profileText(String language, String key) {
  const values = {
    'en': {
      'welcome': 'Welcome Back',
      'currentTrip': 'Current trip',
      'language': 'Language',
      'notifications': 'Notifications',
      'theme': 'Theme',
      'interests': 'Travel interests',
      'account': 'Account',
      'saveProfile': 'Save profile',
      'signOut': 'Sign out',
      'deleteAccount': 'Delete account',
      'deleteQuestion': 'Delete account?',
      'deleteMessage':
          'This deletes your sign-in account, profile, and saved trips. This cannot be undone.',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'close': 'Close',
      'saveInterests': 'Save interests',
      'customInterest': 'Add custom interest',
      'interestBlocked': 'That interest is not allowed.',
      'on': 'On',
      'off': 'Off',
    },
    'id': {
      'welcome': 'Selamat Datang',
      'currentTrip': 'Perjalanan aktif',
      'language': 'Bahasa',
      'notifications': 'Notifikasi',
      'theme': 'Tema',
      'interests': 'Minat perjalanan',
      'account': 'Akun',
      'saveProfile': 'Simpan profil',
      'signOut': 'Keluar',
      'deleteAccount': 'Hapus akun',
      'deleteQuestion': 'Hapus akun?',
      'deleteMessage':
          'Ini menghapus akun masuk, profil, dan perjalanan tersimpan. Tidak dapat dibatalkan.',
      'cancel': 'Batal',
      'delete': 'Hapus',
      'close': 'Tutup',
      'saveInterests': 'Simpan minat',
      'customInterest': 'Tambah minat',
      'interestBlocked': 'Minat itu tidak diizinkan.',
      'on': 'Aktif',
      'off': 'Mati',
    },
    'zh': {
      'welcome': '歡迎回來',
      'currentTrip': '目前旅程',
      'language': '語言',
      'notifications': '通知',
      'theme': '主題',
      'interests': '旅行興趣',
      'account': '帳戶',
      'saveProfile': '儲存個人資料',
      'signOut': '登出',
      'deleteAccount': '刪除帳戶',
      'deleteQuestion': '刪除帳戶？',
      'deleteMessage': '這會刪除登入帳戶、個人資料和已儲存旅程，且無法復原。',
      'cancel': '取消',
      'delete': '刪除',
      'close': '關閉',
      'saveInterests': '儲存興趣',
      'customInterest': '新增興趣',
      'interestBlocked': '不允許使用此興趣。',
      'on': '開',
      'off': '關',
    },
  };
  if (!values.containsKey(language)) return values['en']![key] ?? key;
  return values[language]?[key] ?? values['en']![key] ?? key;
}

String _localizedSettingValue(String language, String key) {
  if (language == 'en' || language == 'id' || language == 'zh') {
    return _profileText(language, key);
  }
  return _profileText('en', key);
}

String? _cleanInterest(String value) {
  final cleaned = value
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[^a-zA-Z0-9 &/+-]'), '');
  if (cleaned.length < 2 || cleaned.length > 28) return null;
  return cleaned
      .split(' ')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

bool _isBlockedInterest(String value) {
  final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  const blocked = [
    'porn',
    'porno',
    'sex',
    'sexy',
    'nude',
    'nudes',
    'nudity',
    'xxx',
    'hentai',
    'fetish',
    'escort',
    'brothel',
    'prostitute',
    'prostitution',
    'onlyfans',
    'nsfw',
  ];
  return blocked.any(normalized.contains);
}
