import 'package:flutter_app/core/localization/app_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('language catalog exposes a broad set of translatable locales', () {
    final codes = appLanguages.map((language) => language.code).toSet();

    expect(appLanguages, hasLength(82));
    expect(codes, hasLength(appLanguages.length));
    expect(codes, containsAll(['en', 'zh_Hans', 'zh_Hant_TW', 'ar', 'zu']));
    expect(
      appLanguages.every(
        (language) =>
            language.englishName.isNotEmpty &&
            language.nativeName.isNotEmpty &&
            language.resolvedLocale.languageCode.isNotEmpty,
      ),
      isTrue,
    );
  });

  test('legacy Chinese profile codes resolve to Traditional Chinese', () {
    expect(appLanguageForCode('zh').code, 'zh_Hant_TW');
    expect(appLanguageForCode('zh-TW').code, 'zh_Hant_TW');
    expect(appLanguageForCode('zh-CN').code, 'zh_Hans');
  });
}
