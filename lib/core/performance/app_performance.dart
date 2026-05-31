import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PerformancePreset { high, balanced, batterySaver, custom }

enum MotionLevel { full, reduced, off }

enum FrameRatePreference { native, balanced, conservative }

enum ImageQualityPreference { high, balanced, low }

extension PerformancePresetLabel on PerformancePreset {
  String get label {
    return switch (this) {
      PerformancePreset.high => 'High',
      PerformancePreset.balanced => 'Balanced',
      PerformancePreset.batterySaver => 'Battery saver',
      PerformancePreset.custom => 'Custom',
    };
  }
}

extension MotionLevelLabel on MotionLevel {
  String get label {
    return switch (this) {
      MotionLevel.full => 'Full motion',
      MotionLevel.reduced => 'Reduced motion',
      MotionLevel.off => 'Off',
    };
  }
}

extension FrameRatePreferenceLabel on FrameRatePreference {
  String get label {
    return switch (this) {
      FrameRatePreference.native => 'Native',
      FrameRatePreference.balanced => 'Balanced',
      FrameRatePreference.conservative => 'Conservative',
    };
  }
}

extension ImageQualityPreferenceLabel on ImageQualityPreference {
  String get label {
    return switch (this) {
      ImageQualityPreference.high => 'High',
      ImageQualityPreference.balanced => 'Balanced',
      ImageQualityPreference.low => 'Low',
    };
  }
}

@immutable
class AppPerformanceSettings {
  const AppPerformanceSettings({
    required this.preset,
    required this.motionLevel,
    required this.frameRatePreference,
    required this.imageQuality,
    required this.cachePages,
    required this.isolateRepaints,
    required this.heavyVisualEffects,
  });

  factory AppPerformanceSettings.forPreset(PerformancePreset preset) {
    return switch (preset) {
      PerformancePreset.high => const AppPerformanceSettings(
        preset: PerformancePreset.high,
        motionLevel: MotionLevel.full,
        frameRatePreference: FrameRatePreference.native,
        imageQuality: ImageQualityPreference.high,
        cachePages: true,
        isolateRepaints: true,
        heavyVisualEffects: true,
      ),
      PerformancePreset.balanced => const AppPerformanceSettings(
        preset: PerformancePreset.balanced,
        motionLevel: MotionLevel.reduced,
        frameRatePreference: FrameRatePreference.balanced,
        imageQuality: ImageQualityPreference.balanced,
        cachePages: true,
        isolateRepaints: true,
        heavyVisualEffects: false,
      ),
      PerformancePreset.batterySaver => const AppPerformanceSettings(
        preset: PerformancePreset.batterySaver,
        motionLevel: MotionLevel.off,
        frameRatePreference: FrameRatePreference.conservative,
        imageQuality: ImageQualityPreference.low,
        cachePages: true,
        isolateRepaints: true,
        heavyVisualEffects: false,
      ),
      PerformancePreset.custom => AppPerformanceSettings.forPreset(
        PerformancePreset.balanced,
      ).copyWith(preset: PerformancePreset.custom),
    };
  }

  factory AppPerformanceSettings.fromJson(Map<String, dynamic> json) {
    final preset = _enumFromName(
      PerformancePreset.values,
      json['preset'] as String?,
      PerformancePreset.balanced,
    );
    if (preset != PerformancePreset.custom) {
      return AppPerformanceSettings.forPreset(preset);
    }

    return AppPerformanceSettings(
      preset: preset,
      motionLevel: _enumFromName(
        MotionLevel.values,
        json['motionLevel'] as String?,
        MotionLevel.reduced,
      ),
      frameRatePreference: _enumFromName(
        FrameRatePreference.values,
        json['frameRatePreference'] as String?,
        FrameRatePreference.balanced,
      ),
      imageQuality: _enumFromName(
        ImageQualityPreference.values,
        json['imageQuality'] as String?,
        ImageQualityPreference.balanced,
      ),
      cachePages: (json['cachePages'] as bool?) ?? true,
      isolateRepaints: (json['isolateRepaints'] as bool?) ?? true,
      heavyVisualEffects: (json['heavyVisualEffects'] as bool?) ?? false,
    );
  }

  final PerformancePreset preset;
  final MotionLevel motionLevel;
  final FrameRatePreference frameRatePreference;
  final ImageQualityPreference imageQuality;
  final bool cachePages;
  final bool isolateRepaints;
  final bool heavyVisualEffects;

  bool get animationsEnabled => motionLevel != MotionLevel.off;

  Duration get transitionDuration {
    return switch (motionLevel) {
      MotionLevel.full => const Duration(milliseconds: 220),
      MotionLevel.reduced => const Duration(milliseconds: 90),
      MotionLevel.off => Duration.zero,
    };
  }

  Duration get globeAnimationDuration {
    return switch (frameRatePreference) {
      FrameRatePreference.native => const Duration(seconds: 8),
      FrameRatePreference.balanced => const Duration(seconds: 14),
      FrameRatePreference.conservative => const Duration(seconds: 24),
    };
  }

  FilterQuality get filterQuality {
    return switch (imageQuality) {
      ImageQualityPreference.high => FilterQuality.high,
      ImageQualityPreference.balanced => FilterQuality.medium,
      ImageQualityPreference.low => FilterQuality.low,
    };
  }

  String get estimatedPowerUse {
    if (!heavyVisualEffects &&
        motionLevel == MotionLevel.off &&
        imageQuality == ImageQualityPreference.low) {
      return 'Low';
    }
    if (motionLevel == MotionLevel.full &&
        frameRatePreference == FrameRatePreference.native &&
        imageQuality == ImageQualityPreference.high) {
      return 'Higher';
    }
    return 'Moderate';
  }

  String get framePolicy {
    return switch (frameRatePreference) {
      FrameRatePreference.native => 'Use normal Flutter frame pacing.',
      FrameRatePreference.balanced =>
        'Keep transitions short and decorative loops off unless enabled.',
      FrameRatePreference.conservative =>
        'Prefer static visuals and minimal animation work.',
    };
  }

  AppPerformanceSettings copyWith({
    PerformancePreset? preset,
    MotionLevel? motionLevel,
    FrameRatePreference? frameRatePreference,
    ImageQualityPreference? imageQuality,
    bool? cachePages,
    bool? isolateRepaints,
    bool? heavyVisualEffects,
  }) {
    return AppPerformanceSettings(
      preset: preset ?? this.preset,
      motionLevel: motionLevel ?? this.motionLevel,
      frameRatePreference: frameRatePreference ?? this.frameRatePreference,
      imageQuality: imageQuality ?? this.imageQuality,
      cachePages: cachePages ?? this.cachePages,
      isolateRepaints: isolateRepaints ?? this.isolateRepaints,
      heavyVisualEffects: heavyVisualEffects ?? this.heavyVisualEffects,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preset': preset.name,
      'motionLevel': motionLevel.name,
      'frameRatePreference': frameRatePreference.name,
      'imageQuality': imageQuality.name,
      'cachePages': cachePages,
      'isolateRepaints': isolateRepaints,
      'heavyVisualEffects': heavyVisualEffects,
    };
  }
}

class AppPerformanceController extends ChangeNotifier {
  static const _storageKey = 'app.performance.settings.v1';

  AppPerformanceController()
    : _settings = AppPerformanceSettings.forPreset(PerformancePreset.balanced);

  AppPerformanceSettings _settings;
  bool _loaded = false;

  AppPerformanceSettings get settings => _settings;
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _settings = AppPerformanceSettings.fromJson(decoded);
        }
      }
    } catch (_) {
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> applyPreset(PerformancePreset preset) {
    return update(AppPerformanceSettings.forPreset(preset));
  }

  Future<void> setMotionLevel(MotionLevel value) {
    return update(
      _settings.copyWith(preset: PerformancePreset.custom, motionLevel: value),
    );
  }

  Future<void> setFrameRatePreference(FrameRatePreference value) {
    return update(
      _settings.copyWith(
        preset: PerformancePreset.custom,
        frameRatePreference: value,
      ),
    );
  }

  Future<void> setImageQuality(ImageQualityPreference value) {
    return update(
      _settings.copyWith(preset: PerformancePreset.custom, imageQuality: value),
    );
  }

  Future<void> setCachePages(bool value) {
    return update(
      _settings.copyWith(preset: PerformancePreset.custom, cachePages: value),
    );
  }

  Future<void> setIsolateRepaints(bool value) {
    return update(
      _settings.copyWith(
        preset: PerformancePreset.custom,
        isolateRepaints: value,
      ),
    );
  }

  Future<void> setHeavyVisualEffects(bool value) {
    return update(
      _settings.copyWith(
        preset: PerformancePreset.custom,
        heavyVisualEffects: value,
      ),
    );
  }

  Future<void> update(AppPerformanceSettings settings) async {
    _settings = settings;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(settings.toJson()));
    } catch (_) {}
  }
}

class PerformanceScope extends InheritedNotifier<AppPerformanceController> {
  const PerformanceScope({
    required AppPerformanceController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppPerformanceController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<PerformanceScope>();
    assert(scope != null, 'No PerformanceScope found in context.');
    return scope!.notifier!;
  }

  static AppPerformanceSettings settingsOf(BuildContext context) {
    return of(context).settings;
  }

  static AppPerformanceSettings maybeSettingsOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<PerformanceScope>();
    return scope?.notifier?.settings ??
        AppPerformanceSettings.forPreset(PerformancePreset.balanced);
  }
}

class PerformanceBoundary extends StatelessWidget {
  const PerformanceBoundary({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings = PerformanceScope.maybeSettingsOf(context);
    if (!settings.isolateRepaints) return child;
    return RepaintBoundary(child: child);
  }
}

T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
