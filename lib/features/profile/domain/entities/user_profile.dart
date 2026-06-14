part of travel_agent_app;

class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.interests,
    this.bio = '',
    this.photoUrl,
    this.language = 'en',
    this.notificationsEnabled = true,
    this.displayCurrencyCode = AppCurrency.fallbackCurrencyCode,
    this.currencyUpdateMode = CurrencyUpdateMode.automatic,
    this.currencySettingsVersion = 1,
    this.themeMode = 'Light',
    this.onboardingRequired = false,
    this.onboardingCompleted = true,
    this.performanceSettings = const AppPerformanceSettings(
      preset: PerformancePreset.balanced,
      motionLevel: MotionLevel.reduced,
      frameRatePreference: FrameRatePreference.balanced,
      imageQuality: ImageQualityPreference.balanced,
      cachePages: true,
      isolateRepaints: true,
      heavyVisualEffects: false,
    ),
  });

  final String name;
  final String email;
  final String bio;
  final String? photoUrl;
  final List<String> interests;
  final String language;
  final bool notificationsEnabled;
  final String displayCurrencyCode;
  final CurrencyUpdateMode currencyUpdateMode;
  final int currencySettingsVersion;
  final String themeMode;
  final bool onboardingRequired;
  final bool onboardingCompleted;
  final AppPerformanceSettings performanceSettings;

  UserProfile copyWith({
    String? name,
    String? email,
    String? bio,
    String? photoUrl,
    List<String>? interests,
    String? language,
    bool? notificationsEnabled,
    String? displayCurrencyCode,
    CurrencyUpdateMode? currencyUpdateMode,
    int? currencySettingsVersion,
    String? themeMode,
    bool? onboardingRequired,
    bool? onboardingCompleted,
    AppPerformanceSettings? performanceSettings,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      interests: interests ?? this.interests,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      displayCurrencyCode: displayCurrencyCode ?? this.displayCurrencyCode,
      currencyUpdateMode: currencyUpdateMode ?? this.currencyUpdateMode,
      currencySettingsVersion:
          currencySettingsVersion ?? this.currencySettingsVersion,
      themeMode: themeMode ?? this.themeMode,
      onboardingRequired: onboardingRequired ?? this.onboardingRequired,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      performanceSettings: performanceSettings ?? this.performanceSettings,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'bio': bio,
    'photoUrl': photoUrl,
    'interests': interests,
    'settings': {
      'language': language,
      'notificationsEnabled': notificationsEnabled,
      'displayCurrencyCode': displayCurrencyCode,
      'currencyUpdateMode': currencyUpdateMode.name,
      'currencySettingsVersion': currencySettingsVersion,
      'themeMode': themeMode,
      'onboardingRequired': onboardingRequired,
      'onboardingCompleted': onboardingCompleted,
      'performance': performanceSettings.toJson(),
    },
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> toLocalMap() => {
    'name': name,
    'email': email,
    'bio': bio,
    'photoUrl': photoUrl,
    'interests': interests,
    'settings': {
      'language': language,
      'notificationsEnabled': notificationsEnabled,
      'displayCurrencyCode': displayCurrencyCode,
      'currencyUpdateMode': currencyUpdateMode.name,
      'currencySettingsVersion': currencySettingsVersion,
      'themeMode': themeMode,
      'onboardingRequired': onboardingRequired,
      'onboardingCompleted': onboardingCompleted,
      'performance': performanceSettings.toJson(),
    },
  };

  static UserProfile fromMap(Map<String, dynamic> map) {
    final settings = Map<String, dynamic>.from(
      (map['settings'] as Map?) ?? const <String, dynamic>{},
    );
    return UserProfile(
      name: (map['name'] as String?) ?? 'Explorer',
      email: (map['email'] as String?) ?? '',
      bio: (map['bio'] as String?) ?? '',
      photoUrl: map['photoUrl'] as String?,
      interests: ((map['interests'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(),
      language: (settings['language'] as String?) ?? 'en',
      notificationsEnabled: (settings['notificationsEnabled'] as bool?) ?? true,
      displayCurrencyCode:
          ((settings['displayCurrencyCode'] as String?) ??
                  AppCurrency.fallbackCurrencyCode)
              .trim()
              .toUpperCase(),
      currencyUpdateMode: CurrencyUpdateMode.fromName(
        settings['currencyUpdateMode'],
      ),
      currencySettingsVersion:
          (settings['currencySettingsVersion'] as num?)?.toInt() ?? 0,
      themeMode: (settings['themeMode'] as String?) ?? 'Light',
      onboardingRequired: (settings['onboardingRequired'] as bool?) ?? false,
      onboardingCompleted: (settings['onboardingCompleted'] as bool?) ?? true,
      performanceSettings: AppPerformanceSettings.fromJson(
        Map<String, dynamic>.from(
          (settings['performance'] as Map?) ?? const <String, dynamic>{},
        ),
      ),
    );
  }
}

String _languageLabel(String language) {
  return appLanguageForCode(language).displayName;
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
