part of travel_agent_app;

class FavoritePlace {
  const FavoritePlace({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.tags,
  });

  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final List<String> tags;

  factory FavoritePlace.fromDestination(Destination destination) {
    return FavoritePlace(
      id: _favoritePlaceId(destination.name),
      name: destination.name,
      description: destination.description,
      imageUrl: destination.image,
      tags: destination.tags,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'imageUrl': imageUrl,
    'tags': tags,
  };

  static FavoritePlace fromMap(Map<String, dynamic> map) {
    return FavoritePlace(
      id:
          (map['id'] as String?) ??
          _favoritePlaceId((map['name'] as String?) ?? ''),
      name: (map['name'] as String?) ?? 'Saved place',
      description: (map['description'] as String?) ?? '',
      imageUrl: (map['imageUrl'] as String?) ?? '',
      tags: ((map['tags'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

String _favoritePlaceId(String name) {
  return name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

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
    this.ageRange,
    this.travelPace = 'Balanced',
    this.termsAcceptedVersion,
    this.termsAcceptedAt,
    this.favoritePlaces = const [],
    this.favoriteTripIds = const [],
    this.tutorialCompleted = false,
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
  final bool hasImportantAlerts =
      false; // TODO later: implement this based on user alerts
  final String displayCurrencyCode;
  final CurrencyUpdateMode currencyUpdateMode;
  final int currencySettingsVersion;
  final String themeMode;
  final bool onboardingRequired;
  final bool onboardingCompleted;
  final String? ageRange;
  final String travelPace;
  final String? termsAcceptedVersion;
  final DateTime? termsAcceptedAt;
  final List<FavoritePlace> favoritePlaces;
  final List<String> favoriteTripIds;
  final bool tutorialCompleted;
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
    String? ageRange,
    String? travelPace,
    String? termsAcceptedVersion,
    DateTime? termsAcceptedAt,
    List<FavoritePlace>? favoritePlaces,
    List<String>? favoriteTripIds,
    bool? tutorialCompleted,
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
      ageRange: ageRange ?? this.ageRange,
      travelPace: travelPace ?? this.travelPace,
      termsAcceptedVersion: termsAcceptedVersion ?? this.termsAcceptedVersion,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      favoritePlaces: favoritePlaces ?? this.favoritePlaces,
      favoriteTripIds: favoriteTripIds ?? this.favoriteTripIds,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      performanceSettings: performanceSettings ?? this.performanceSettings,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'bio': bio,
    'photoUrl': photoUrl,
    'interests': interests,
    'favoritePlaces': favoritePlaces.map((place) => place.toMap()).toList(),
    'favoriteTripIds': favoriteTripIds,
    'onboarding': {'ageRange': ageRange, 'travelPace': travelPace},
    if (termsAcceptedVersion != null)
      'legalConsent': {
        'termsVersion': termsAcceptedVersion,
        'acceptedAt': termsAcceptedAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(termsAcceptedAt!),
        'draftTerms': true,
      },
    'settings': {
      'language': language,
      'notificationsEnabled': notificationsEnabled,
      'displayCurrencyCode': displayCurrencyCode,
      'currencyUpdateMode': currencyUpdateMode.name,
      'currencySettingsVersion': currencySettingsVersion,
      'themeMode': themeMode,
      'onboardingRequired': onboardingRequired,
      'onboardingCompleted': onboardingCompleted,
      'tutorialCompleted': tutorialCompleted,
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
    'favoritePlaces': favoritePlaces.map((place) => place.toMap()).toList(),
    'favoriteTripIds': favoriteTripIds,
    'onboarding': {'ageRange': ageRange, 'travelPace': travelPace},
    if (termsAcceptedVersion != null)
      'legalConsent': {
        'termsVersion': termsAcceptedVersion,
        'acceptedAt': termsAcceptedAt?.toUtc().toIso8601String(),
        'draftTerms': true,
      },
    'settings': {
      'language': language,
      'notificationsEnabled': notificationsEnabled,
      'displayCurrencyCode': displayCurrencyCode,
      'currencyUpdateMode': currencyUpdateMode.name,
      'currencySettingsVersion': currencySettingsVersion,
      'themeMode': themeMode,
      'onboardingRequired': onboardingRequired,
      'onboardingCompleted': onboardingCompleted,
      'tutorialCompleted': tutorialCompleted,
      'performance': performanceSettings.toJson(),
    },
  };

  static UserProfile fromMap(Map<String, dynamic> map) {
    final settings = Map<String, dynamic>.from(
      (map['settings'] as Map?) ?? const <String, dynamic>{},
    );
    final onboarding = Map<String, dynamic>.from(
      (map['onboarding'] as Map?) ?? const <String, dynamic>{},
    );
    final legalConsent = Map<String, dynamic>.from(
      (map['legalConsent'] as Map?) ?? const <String, dynamic>{},
    );
    final acceptedAtValue = legalConsent['acceptedAt'];
    return UserProfile(
      name: (map['name'] as String?) ?? 'Explorer',
      email: (map['email'] as String?) ?? '',
      bio: (map['bio'] as String?) ?? '',
      photoUrl: map['photoUrl'] as String?,
      interests: ((map['interests'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(),
      favoritePlaces: ((map['favoritePlaces'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map(
            (place) => FavoritePlace.fromMap(Map<String, dynamic>.from(place)),
          )
          .toList(),
      favoriteTripIds: ((map['favoriteTripIds'] as List<dynamic>?) ?? const [])
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
      tutorialCompleted: (settings['tutorialCompleted'] as bool?) ?? false,
      ageRange: onboarding['ageRange'] as String?,
      travelPace: (onboarding['travelPace'] as String?) ?? 'Balanced',
      termsAcceptedVersion: legalConsent['termsVersion'] as String?,
      termsAcceptedAt: switch (acceptedAtValue) {
        Timestamp value => value.toDate(),
        String value => DateTime.tryParse(value),
        _ => null,
      },
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
