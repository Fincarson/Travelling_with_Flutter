import 'package:flutter/material.dart';

@immutable
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.englishName,
    required this.nativeName,
    this.locale,
  });

  final String code;
  final String englishName;
  final String nativeName;
  final Locale? locale;

  Locale get resolvedLocale => locale ?? Locale(code);

  String get displayName {
    if (nativeName == englishName) return englishName;
    return '$nativeName ($englishName)';
  }

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    return normalized.isEmpty ||
        code.toLowerCase().contains(normalized) ||
        englishName.toLowerCase().contains(normalized) ||
        nativeName.toLowerCase().contains(normalized);
  }
}

const appLanguages = <AppLanguage>[
  AppLanguage(code: 'af', englishName: 'Afrikaans', nativeName: 'Afrikaans'),
  AppLanguage(code: 'am', englishName: 'Amharic', nativeName: 'አማርኛ'),
  AppLanguage(code: 'ar', englishName: 'Arabic', nativeName: 'العربية'),
  AppLanguage(code: 'as', englishName: 'Assamese', nativeName: 'অসমীয়া'),
  AppLanguage(
    code: 'az',
    englishName: 'Azerbaijani',
    nativeName: 'Azərbaycanca',
  ),
  AppLanguage(code: 'be', englishName: 'Belarusian', nativeName: 'Беларуская'),
  AppLanguage(code: 'bg', englishName: 'Bulgarian', nativeName: 'Български'),
  AppLanguage(code: 'bn', englishName: 'Bengali', nativeName: 'বাংলা'),
  AppLanguage(code: 'bs', englishName: 'Bosnian', nativeName: 'Bosanski'),
  AppLanguage(code: 'ca', englishName: 'Catalan', nativeName: 'Català'),
  AppLanguage(code: 'cs', englishName: 'Czech', nativeName: 'Čeština'),
  AppLanguage(code: 'cy', englishName: 'Welsh', nativeName: 'Cymraeg'),
  AppLanguage(code: 'da', englishName: 'Danish', nativeName: 'Dansk'),
  AppLanguage(code: 'de', englishName: 'German', nativeName: 'Deutsch'),
  AppLanguage(code: 'el', englishName: 'Greek', nativeName: 'Ελληνικά'),
  AppLanguage(code: 'en', englishName: 'English', nativeName: 'English'),
  AppLanguage(code: 'es', englishName: 'Spanish', nativeName: 'Español'),
  AppLanguage(code: 'et', englishName: 'Estonian', nativeName: 'Eesti'),
  AppLanguage(code: 'eu', englishName: 'Basque', nativeName: 'Euskara'),
  AppLanguage(code: 'fa', englishName: 'Persian', nativeName: 'فارسی'),
  AppLanguage(code: 'fi', englishName: 'Finnish', nativeName: 'Suomi'),
  AppLanguage(code: 'fil', englishName: 'Filipino', nativeName: 'Filipino'),
  AppLanguage(code: 'fr', englishName: 'French', nativeName: 'Français'),
  AppLanguage(code: 'ga', englishName: 'Irish', nativeName: 'Gaeilge'),
  AppLanguage(code: 'gl', englishName: 'Galician', nativeName: 'Galego'),
  AppLanguage(
    code: 'gsw',
    englishName: 'Swiss German',
    nativeName: 'Schwiizerdütsch',
  ),
  AppLanguage(code: 'gu', englishName: 'Gujarati', nativeName: 'ગુજરાતી'),
  AppLanguage(code: 'he', englishName: 'Hebrew', nativeName: 'עברית'),
  AppLanguage(code: 'hi', englishName: 'Hindi', nativeName: 'हिन्दी'),
  AppLanguage(code: 'hr', englishName: 'Croatian', nativeName: 'Hrvatski'),
  AppLanguage(code: 'hu', englishName: 'Hungarian', nativeName: 'Magyar'),
  AppLanguage(code: 'hy', englishName: 'Armenian', nativeName: 'Հայերեն'),
  AppLanguage(
    code: 'id',
    englishName: 'Indonesian',
    nativeName: 'Bahasa Indonesia',
  ),
  AppLanguage(code: 'is', englishName: 'Icelandic', nativeName: 'Íslenska'),
  AppLanguage(code: 'it', englishName: 'Italian', nativeName: 'Italiano'),
  AppLanguage(code: 'ja', englishName: 'Japanese', nativeName: '日本語'),
  AppLanguage(code: 'ka', englishName: 'Georgian', nativeName: 'ქართული'),
  AppLanguage(code: 'kk', englishName: 'Kazakh', nativeName: 'Қазақша'),
  AppLanguage(code: 'km', englishName: 'Khmer', nativeName: 'ខ្មែរ'),
  AppLanguage(code: 'kn', englishName: 'Kannada', nativeName: 'ಕನ್ನಡ'),
  AppLanguage(code: 'ko', englishName: 'Korean', nativeName: '한국어'),
  AppLanguage(code: 'ky', englishName: 'Kyrgyz', nativeName: 'Кыргызча'),
  AppLanguage(code: 'lo', englishName: 'Lao', nativeName: 'ລາວ'),
  AppLanguage(code: 'lt', englishName: 'Lithuanian', nativeName: 'Lietuvių'),
  AppLanguage(code: 'lv', englishName: 'Latvian', nativeName: 'Latviešu'),
  AppLanguage(code: 'mk', englishName: 'Macedonian', nativeName: 'Македонски'),
  AppLanguage(code: 'ml', englishName: 'Malayalam', nativeName: 'മലയാളം'),
  AppLanguage(code: 'mn', englishName: 'Mongolian', nativeName: 'Монгол'),
  AppLanguage(code: 'mr', englishName: 'Marathi', nativeName: 'मराठी'),
  AppLanguage(code: 'ms', englishName: 'Malay', nativeName: 'Bahasa Melayu'),
  AppLanguage(code: 'my', englishName: 'Burmese', nativeName: 'မြန်မာ'),
  AppLanguage(
    code: 'nb',
    englishName: 'Norwegian Bokmål',
    nativeName: 'Norsk bokmål',
  ),
  AppLanguage(code: 'ne', englishName: 'Nepali', nativeName: 'नेपाली'),
  AppLanguage(code: 'nl', englishName: 'Dutch', nativeName: 'Nederlands'),
  AppLanguage(code: 'no', englishName: 'Norwegian', nativeName: 'Norsk'),
  AppLanguage(code: 'or', englishName: 'Odia', nativeName: 'ଓଡ଼ିଆ'),
  AppLanguage(code: 'pa', englishName: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ'),
  AppLanguage(code: 'pl', englishName: 'Polish', nativeName: 'Polski'),
  AppLanguage(code: 'ps', englishName: 'Pashto', nativeName: 'پښتو'),
  AppLanguage(code: 'pt', englishName: 'Portuguese', nativeName: 'Português'),
  AppLanguage(code: 'ro', englishName: 'Romanian', nativeName: 'Română'),
  AppLanguage(code: 'ru', englishName: 'Russian', nativeName: 'Русский'),
  AppLanguage(code: 'si', englishName: 'Sinhala', nativeName: 'සිංහල'),
  AppLanguage(code: 'sk', englishName: 'Slovak', nativeName: 'Slovenčina'),
  AppLanguage(code: 'sl', englishName: 'Slovenian', nativeName: 'Slovenščina'),
  AppLanguage(code: 'sq', englishName: 'Albanian', nativeName: 'Shqip'),
  AppLanguage(code: 'sr', englishName: 'Serbian', nativeName: 'Српски'),
  AppLanguage(code: 'sv', englishName: 'Swedish', nativeName: 'Svenska'),
  AppLanguage(code: 'sw', englishName: 'Swahili', nativeName: 'Kiswahili'),
  AppLanguage(code: 'ta', englishName: 'Tamil', nativeName: 'தமிழ்'),
  AppLanguage(code: 'te', englishName: 'Telugu', nativeName: 'తెలుగు'),
  AppLanguage(code: 'th', englishName: 'Thai', nativeName: 'ไทย'),
  AppLanguage(code: 'tl', englishName: 'Tagalog', nativeName: 'Tagalog'),
  AppLanguage(code: 'tr', englishName: 'Turkish', nativeName: 'Türkçe'),
  AppLanguage(code: 'ug', englishName: 'Uyghur', nativeName: 'ئۇيغۇرچە'),
  AppLanguage(code: 'uk', englishName: 'Ukrainian', nativeName: 'Українська'),
  AppLanguage(code: 'ur', englishName: 'Urdu', nativeName: 'اردو'),
  AppLanguage(code: 'uz', englishName: 'Uzbek', nativeName: 'O‘zbekcha'),
  AppLanguage(code: 'vi', englishName: 'Vietnamese', nativeName: 'Tiếng Việt'),
  AppLanguage(
    code: 'zh_Hans',
    englishName: 'Chinese (Simplified)',
    nativeName: '简体中文',
    locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  ),
  AppLanguage(
    code: 'zh_Hant_TW',
    englishName: 'Chinese (Traditional)',
    nativeName: '繁體中文',
    locale: Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
      countryCode: 'TW',
    ),
  ),
  AppLanguage(code: 'zu', englishName: 'Zulu', nativeName: 'IsiZulu'),
];

AppLanguage appLanguageForCode(String code) {
  final normalized = switch (code) {
    'zh' || 'zh-TW' => 'zh_Hant_TW',
    'zh-CN' => 'zh_Hans',
    _ => code,
  };
  return appLanguages.firstWhere(
    (language) => language.code == normalized,
    orElse: () => appLanguages.firstWhere((language) => language.code == 'en'),
  );
}

List<Locale> get appSupportedLocales => appLanguages
    .map((language) => language.resolvedLocale)
    .toList(growable: false);
