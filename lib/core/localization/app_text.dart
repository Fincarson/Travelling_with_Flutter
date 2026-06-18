import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';
import 'app_locale_controller.dart';

String appText(BuildContext context, String source) {
  final language = AppLocaleController.profileLanguage.value;
  if (language == 'en') return source;
  if (language == 'zh_Hant_TW') {
    if (source.startsWith('of ')) return '總預算 ${source.substring(3)}';
    if (source.contains(' route / ')) {
      return source
          .replaceFirst(' route / ', ' 路線 / ')
          .replaceFirst(' stops', ' 站');
    }
    return _zhHantTwText[source] ??
        AppTextController.translationFor(language, source);
  }
  return AppTextController.translationFor(language, source);
}

class AppTextController {
  static final ValueNotifier<int> revision = ValueNotifier(0);
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  static final Map<String, Map<String, String>> _translations = {};
  static final Set<String> _pending = {};
  static String _activeLanguage = 'en';
  static Timer? _batchTimer;
  static bool _requestInFlight = false;
  static DateTime? _retryAfter;

  static Future<void> activateLanguage(String language) async {
    _activeLanguage = language;
    _pending.clear();
    _batchTimer?.cancel();
    if (language == 'en') return;
    if (_translations.containsKey(language)) return;

    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('travel_agent.ui_translations.$language');
    if (raw == null || raw.isEmpty) {
      _translations[language] = <String, String>{};
      return;
    }
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _translations[language] = decoded.map(
        (key, value) => MapEntry(key, value.toString()),
      );
      revision.value++;
    } catch (_) {
      _translations[language] = <String, String>{};
    }
  }

  static Future<void> prepareLanguage(
    String language, {
    ValueChanged<double>? onProgress,
  }) async {
    await activateLanguage(language);
    if (language == 'en') {
      onProgress?.call(1);
      return;
    }

    final cache = _translations.putIfAbsent(language, () => <String, String>{});
    final alreadyTranslated = language == 'zh_Hant_TW'
        ? _zhHantTwText.keys.toSet()
        : const <String>{};
    final sources = _translatableUiSources
        .where(
          (source) =>
              !alreadyTranslated.contains(source) &&
              (cache[source]?.trim().isEmpty ?? true),
        )
        .toList(growable: false);
    final total = _translatableUiSources.length;
    var completed = total - sources.length;
    onProgress?.call(total == 0 ? 1 : completed / total);

    for (var start = 0; start < sources.length; start += 40) {
      final end = math.min(start + 40, sources.length);
      final batch = sources.sublist(start, end);
      final translated = await _requestTranslations(language, batch);
      for (var index = 0; index < batch.length; index++) {
        cache[batch[index]] = translated[index];
      }
      completed += batch.length;
      await _saveCache(language, cache);
      onProgress?.call(total == 0 ? 1 : completed / total);
    }

    _retryAfter = null;
    revision.value++;
    onProgress?.call(1);
  }

  static String translationFor(String language, String source) {
    final translated = _translations[language]?[source];
    if (translated != null && translated.trim().isNotEmpty) return translated;
    if (_isTranslatableUiText(source)) {
      _pending.add(source);
      _scheduleBatch();
    }
    return source;
  }

  static bool _isTranslatableUiText(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty || trimmed.length > 500) return false;
    // Curated strings are always eligible.
    if (_zhHantTwText.containsKey(source) ||
        _additionalTranslatableUiText.contains(source)) {
      return true;
    }
    // Otherwise translate anything that reads like human text: it must contain
    // letters and not be a URL/asset path. This lets every appText-wrapped
    // string translate on demand instead of only the hand-listed ones.
    if (!RegExp(r'[A-Za-z]').hasMatch(trimmed)) return false;
    if (trimmed.contains('://') ||
        trimmed.startsWith('http') ||
        trimmed.startsWith('assets/')) {
      return false;
    }
    return true;
  }

  static void _scheduleBatch() {
    final retryAfter = _retryAfter;
    if (_requestInFlight ||
        _activeLanguage == 'en' ||
        (retryAfter != null && DateTime.now().isBefore(retryAfter))) {
      return;
    }
    _batchTimer ??= Timer(const Duration(milliseconds: 180), () {
      _batchTimer = null;
      unawaited(_flush());
    });
  }

  static Future<void> _flush() async {
    if (_requestInFlight || _pending.isEmpty) return;
    final language = _activeLanguage;
    final sources = _pending.take(40).toList(growable: false);
    _pending.removeAll(sources);
    _requestInFlight = true;
    try {
      final translated = await _requestTranslations(language, sources);
      final cache = _translations.putIfAbsent(
        language,
        () => <String, String>{},
      );
      for (var index = 0; index < sources.length; index++) {
        cache[sources[index]] = translated[index];
      }
      await _saveCache(language, cache);
      if (_activeLanguage == language) revision.value++;
      _retryAfter = null;
    } catch (_) {
      _pending.addAll(sources);
      _retryAfter = DateTime.now().add(const Duration(minutes: 1));
    } finally {
      _requestInFlight = false;
      if (_pending.isNotEmpty) _scheduleBatch();
    }
  }

  static Future<List<String>> _requestTranslations(
    String language,
    List<String> sources,
  ) async {
    final option = appLanguageForCode(language);
    final result = await _functions.httpsCallable('translateUiStrings').call({
      'targetCode': language,
      'targetLanguage': option.englishName,
      'strings': sources,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final translated = (data['translations'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false);
    if (translated.length != sources.length) {
      throw const FormatException('Translation count did not match.');
    }
    return translated;
  }

  static Future<void> _saveCache(
    String language,
    Map<String, String> cache,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'travel_agent.ui_translations.$language',
      jsonEncode(cache),
    );
  }
}

final Set<String> _translatableUiSources = {
  ..._zhHantTwText.keys,
  ..._additionalTranslatableUiText,
};

const _additionalTranslatableUiText = {
  '1 linked account',
  '2 linked accounts',
  '3 linked accounts',
  'A new itinerary will be created from this preview. You can edit dates, bookings, and activities after it is created.',
  'Accept',
  'Accept invite',
  'Attach a trip',
  'Attach trip',
  'Attached trip',
  'Add option',
  'Add budget',
  'Add to trip',
  'Add to a new trip',
  'Add stops to build this schedule.',
  'Add the basics now, then build the day-by-day schedule after creation.',
  'Add with AI',
  'Adjust dates',
  'AI cover suggestions',
  'AI focus',
  'AI focuses',
  'AI planning workspace',
  'AI suggestions',
  'AI will use your picks as signals, then build a starter itinerary you can still edit.',
  'An unexpected error has occurred. Please try again later.',
  'Archive',
  'Archived',
  'Ask about this trip',
  'Automatic',
  'Automatic checks your country when the app opens and asks before changing currency. Manual only changes currency from Settings.',
  'Back',
  'Chat invite',
  'Check official requirements',
  'Check Spam, Junk, and Promotions. Also confirm the address is exactly the one used to create the account. Google-only accounts do not have an email password to reset.',
  'Check your email',
  'Choose a destination',
  'Choose a starting point',
  'Close',
  'Close tutorial',
  'Code',
  'Connect and sign in',
  'Connect Google account',
  'Copy',
  'Could not enable notifications.',
  'Create a group to start messaging.',
  'Create poll',
  'Create a trip to see it here.',
  'Create a trip to use this page.',
  'Create chat',
  'Create plans, swipe to manage trips, and rate completed journeys.',
  'Create or own a trip before attaching it to this group.',
  'Creating your trip',
  'Currency updates',
  'days',
  'Description',
  'Details',
  'Detach',
  'Detach trip',
  'Detach trip?',
  'Detect location changes and ask before switching.',
  'Display currency',
  'Done',
  'Delete group',
  'Delete group chat?',
  'Edit day',
  'Enter the email used for your password account. Firebase will send a secure reset link.',
  'Enter your existing password.',
  'Entry, visa, customs, and health rules can change. Confirm them with official authorities for your passport and travel dates.',
  'Error code',
  'Example: indoor lunch stop near the museum',
  'Example: Senso-ji Temple or Hokkaido day trip',
  'Existing password',
  'Existing trip members will keep their access to the trip.',
  'Facebook coming later',
  'Fill day with AI',
  'Filter',
  'Find favorite places and trips, settings, archives, and performance controls.',
  'Favorited',
  'Forgot password',
  'Group name',
  'Google is now linked to this account.',
  'Important',
  'Include archived items in this notification list.',
  'Invite',
  'Invite copied.',
  'Invite link',
  'Invite link or code',
  'Join trip',
  'Link another sign-in method before unlinking this one.',
  'Link another sign-in method before unlinking your current one.',
  'Link phone number',
  'Linked accounts',
  'Location access',
  'Manage the ways you can securely sign in to this account.',
  'Message',
  'More',
  'Never check location for currency changes.',
  'Next',
  'No activities yet',
  'No activities planned for this day.',
  'No chats yet',
  'No interests added yet.',
  'No messages yet',
  'No owned trips',
  'No trip attached',
  'No trip members found.',
  'No past trips yet. Completed trips will appear here as reusable templates.',
  'No stops yet. Add a place and AI will build this day.',
  'No trip yet',
  'No trips yet',
  'Not linked',
  'OK',
  'Not sure where to start?',
  'Notification archived',
  'Notification type',
  'Option',
  'Open the filter panel to change what appears here.',
  'Open time to adjust after creating the trip.',
  'or continue with',
  'Pick travel style',
  'Plan together',
  'Place to add',
  'Preview',
  'Preview itinerary',
  'Preview saved past trips or recommendation cards before creating the itinerary.',
  'Profile saved.',
  'Question',
  'Phone number linked successfully.',
  'Please restart the app to apply the selected language.',
  'Refresh local context',
  'Remove trip member?',
  'Replace attached trip',
  'Replace trip',
  'Remove activity',
  'Restore',
  'Return to sign in',
  'Review searched images and daily stops before creating the trip.',
  'Save',
  'Save place',
  'Saving the itinerary, checklist, budget, and daily route.',
  'Searched images',
  'See your current trip, AI suggestions, saved places, and important alerts.',
  'Share',
  'Show archived notifications',
  'Sign in before changing linked accounts.',
  'Sign-in method was unlinked.',
  'Start a different trip?',
  'Start the conversation.',
  'Start exploring',
  'Start trip',
  'Start your trip',
  'Tap the recommendation cards you want AI to emphasize.',
  'That sign-in method cannot be unlinked here.',
  'That sign-in method is not linked.',
  'Trip Basics',
  'Trip members',
  'Trip owner',
  'Trip preview',
  'Travel Agent',
  'Trips in one place',
  'Unlink',
  'Unlink sign-in method?',
  'Unread',
  'Use current location',
  'Use group chat and the travel assistant while keeping every trip organized.',
  'Use template',
  'Use this template?',
  'User ID or email',
  'View only: the trip owner manages this plan.',
  'View trip',
  'Viewer',
  'Waiting for budget',
  'You',
  'Your travel dashboard',
  'Your travel profile',
  'You can remove members from this trip.',
  'You have view-only access to this trip.',
  'You will lose access to this trip but will remain in the group chat.',
  'The group owner can attach one of their trips.',
  'Choose a new group owner',
  'Ownership must be transferred before you leave.',
  'You are the only member, so leaving will delete this group chat.',
  'This permanently deletes the chat and its messages. The attached trip and its members will not be changed.',
  'will lose access to this trip but will remain in the group chat.',
  'Leave trip',
  'Leave trip?',
  'Waiting for destination',
  'You can use this number to sign in after it is verified.',
  'You will no longer be able to sign in with this method.',
  'Add members',
  'Admin',
  'Attach',
  'Camera',
  'Chat notifications are muted.',
  'Chat notifications are on.',
  'Created',
  'Creation date unavailable',
  'Edit group details',
  'Exit',
  'Exit chat',
  'Exit chat?',
  'Files',
  'Group description',
  'Group info',
  'Group media',
  'Group title',
  'Make admin',
  'Make member',
  'Manage member',
  'Media',
  'Member',
  'Members',
  'Mute for 1 hour',
  'Mute for 24 hours',
  'Mute for 30 minutes',
  'Mute forever',
  'Muted',
  'No files yet.',
  'No links yet.',
  'No photos, videos, or GIFs yet.',
  'Open GIF',
  'Owner',
  'Photos',
  'Remove',
  'Remove member',
  'Remove option',
  'Remove member?',
  'Report',
  'Report received. No data was submitted.',
  'Saving...',
  'Tap to play GIF',
  'Today',
  'This file is unavailable or has expired.',
  'This link could not be opened.',
  'Unmute notifications',
  'Video',
  'Videos',
  'Yesterday',
  'will no longer have access to this chat.',
  'You will lose access until another member invites you again.',
  'All',
  "Ask AI: 'Best ramen in Kyoto?'",
  'Close details',
  'Close place details',
  'Completed trips and travel memories will appear here.',
  'CONTINUE TRIP',
  'Could not update favorite.',
  'Could not update favorite place.',
  'Favorite trip',
  'Grid view',
  'Highest spending',
  'How well did this trip match your preferences?',
  'Latest first',
  'List view',
  'No matching trips',
  'Optional feedback',
  'Personalizing...',
  'Places picked for you',
  'Rate',
  'Refresh',
  'Remove favorite trip',
  'Remove from favorites',
  'Save rating',
  'Search trips',
  'Sort by',
  'Soonest first',
  'START TRIP',
  'TRAVELERS',
  'Trip memories',
  'Try clearing a filter or searching for another destination.',
  'VIEW TRIP',
  'What should future recommendations change?',
  'Change display currency?',
  'Change to',
  'Daily agent notifications are ready.',
  'Enable',
  'Enabled',
  'Keep',
  'Needs setup',
  'Notification center',
  'Notifications are off for this browser.',
  'Open trip',
  'This trip will be queued for deletion. You can still undo it from the confirmation message.',
  'to',
  'You appear to be in',
  'Would you like to change your display currency from',
};

const _zhHantTwText = {
  'Home': '首頁',
  'Trips': '旅程',
  'Chat': '聊天',
  'Profile': '個人資料',
  'Info': '資訊',
  'Map': '地圖',
  'Translate': '翻譯',
  'AI': 'AI',
  'Ready for your next Adventure': '準備好下一段冒險',
  'AI Travel Agent': 'AI 旅行助理',
  'UP NEXT': '下一站',
  'Kyoto City Zoo': '京都市動物園',
  'Overview': '總覽',
  'Schedule': '日程',
  'Checklist': '清單',
  'DAY': '第',
  'Day': '第',
  'Add to': '新增到',
  'New activity': '新活動',
  'New booking': '新預訂',
  'New trip': '新旅程',
  'None': '無',
  'Travelling with Flutter': 'Travelling with Flutter',
  'Tokyo, Japan': '東京，日本',
  'Sign in to keep your trips, AI plans, budgets, and packing lists synced.':
      '登入即可同步你的旅程、AI 計畫、預算和打包清單。',
  'or': '或',
  'I already have an account': '我已經有帳號',
  'Create a new account': '建立新帳號',
  'Pick your travel style': '選擇你的旅行風格',
  'Choose the things you usually look for so routes, packing lists, and budgets start closer to your taste.':
      '選擇你平常重視的旅行元素，路線、打包清單和預算會更貼近你的偏好。',
  'Shopping': '購物',
  'Museums': '博物館',
  'Hidden Gems': '私房景點',
  'Culture': '文化',
  'Zen': '禪意',
  'City': '城市',
  'Romantic': '浪漫',
  'Scenic': '景觀',
  'Sunset': '夕陽',
  'Relax': '放鬆',
  'Nightlife': '夜生活',
  'Adventure': '冒險',
  'Budget-friendly': '平價',
  'Luxury': '奢華',
  'Walking': '步行',
  'Beach': '海灘',
  'Gate changed': '登機門變更',
  'Flight JAL 402 now boards at Gate A7.': 'JAL 402 航班現在改在 A7 登機門登機。',
  'Rain window': '降雨時段',
  'Kyoto rain expected after 2 PM.': '京都下午 2 點後可能下雨。',
  'ADD PRIMARY PHOTO': '新增主要照片',
  'AI generation was unavailable, so a local draft plan was created.':
      'AI 生成功能暫時無法使用，因此已建立本機草稿計畫。',
  'Generating schedule...': '正在產生日程...',
  'AI is shaping the route, bookings, budget, and packing list.':
      'AI 正在整理路線、預訂、預算和打包清單。',
  'Ask for routes, food, bookings, packing, or swaps.': '詢問路線、美食、預訂、打包或替換方案。',
  'Vote on lunch and share plan changes with friends.': '和朋友投票決定午餐，並分享計畫變更。',
  'AI Agent active. I can optimize routes, compare ideas, and turn chat into schedule changes.':
      'AI 助理已啟用。我可以最佳化路線、比較想法，並把聊天內容轉成日程變更。',
  'I could not generate a travel suggestion right now.': '我現在無法產生旅行建議。',
  'AI chat is unavailable right now. Please try again in a moment.':
      'AI 聊天目前無法使用，請稍後再試。',
  'Ask for route changes, cheaper options, packing help, or booking reminders.':
      '詢問路線變更、更便宜的選項、打包協助或預訂提醒。',
  'Keep this window open while the SMS arrives.': '等待簡訊時請保持此視窗開啟。',
  'Phone SMS sign-in works on web, Android, and iOS. Use email on this device.':
      '電話簡訊登入支援 Web、Android 和 iOS。此裝置請使用電子郵件登入。',
  'Enter your email first.': '請先輸入電子郵件。',
  'Password reset email sent.': '密碼重設郵件已送出。',
  'Use international phone format, for example +15551234567.':
      '請使用國際電話格式，例如 +15551234567。',
  'SMS code sent.': '簡訊驗證碼已送出。',
  'Send an SMS code first.': '請先傳送簡訊驗證碼。',
  'Could not sign in.': '無法登入。',
  'Enter a valid email.': '請輸入有效的電子郵件。',
  'Use at least 6 characters.': '請至少使用 6 個字元。',
  'Use international format with + country code.': '請使用含 + 國碼的國際格式。',
  'Enter the 6-digit SMS code.': '請輸入 6 位數簡訊驗證碼。',
  'That email already has an account.': '該電子郵件已經有帳號。',
  'Enter a valid email address.': '請輸入有效的電子郵件地址。',
  'Email or password is incorrect.': '電子郵件或密碼不正確。',
  'No account was found for that email.': '找不到該電子郵件的帳號。',
  'Use a stronger password.': '請使用更強的密碼。',
  'Check your connection and try again.': '請檢查網路連線後再試一次。',
  'Too many attempts. Try again later.': '嘗試次數過多，請稍後再試。',
  'This sign-in provider is not enabled in Firebase.': 'Firebase 尚未啟用此登入提供者。',
  'The sign-in window was closed.': '登入視窗已關閉。',
  'The SMS code is not correct.': '簡訊驗證碼不正確。',
  'Enter a valid phone number with country code.': '請輸入含國碼的有效電話號碼。',
  'Could not sign in. Please try again.': '無法登入，請再試一次。',
  'Please sign out, sign in again, then delete the account.':
      '請先登出、重新登入，然後再刪除帳號。',
  'Kyoto Group': '京都群組',
  'Ask about Kyoto, budgets, packing...': '詢問京都、預算、打包清單...',
  'Important updates': '重要更新',
  'AI planning cards': 'AI 規劃卡片',
  'Food': '美食',
  'Route': '路線',
  'Market lunch': '市場午餐',
  'Less walking': '減少步行',
  'Travel interests': '旅行興趣',
  'Start exploring': '開始探索',
  'Performance': '效能',
  'Preset': '預設模式',
  'Custom': '自訂',
  'Current behavior': '目前行為',
  'Power': '耗電',
  'Estimated impact': '估計影響',
  'Motion': '動態效果',
  'High': '高效能',
  'Balanced': '平衡',
  'Battery saver': '省電',
  'Full motion': '完整動態',
  'Reduced motion': '減少動態',
  'Off': '關閉',
  'Native': '原生',
  'Conservative': '保守',
  'Low': '低',
  'Moderate': '中等',
  'Higher': '較高',
  'Use normal Flutter frame pacing.': '使用 Flutter 一般畫面節奏。',
  'Keep transitions short and decorative loops off unless enabled.':
      '縮短轉場，除非啟用否則關閉裝飾循環動畫。',
  'Prefer static visuals and minimal animation work.': '偏好靜態畫面並減少動畫工作。',
  'Advanced': '進階',
  'Animations': '動畫',
  'Frame pacing': '畫面節奏',
  'Image quality': '圖片品質',
  'Cache pages': '快取頁面',
  'Keep tab pages alive instead of rebuilding from zero.': '保留分頁狀態，避免從零重建。',
  'Repaint isolation': '重繪隔離',
  'Wrap major pages in repaint boundaries.': '用重繪邊界包住主要頁面。',
  'Heavy visual effects': '高負載視覺效果',
  'Allow decorative animated visuals when enabled.': '啟用時允許裝飾性動畫視覺效果。',
  'Booking': '訂位',
  'Budget': '預算',
  'Dates': '日期',
  'Travelers': '旅行人數',
  'ongoing': '進行中',
  'upcoming': '即將開始',
  'completed': '已完成',
  'TBD': '待定',
  'Confirmed': '已確認',
  'Review': '檢查',
  'AI Prepared': 'AI 已準備',
  'Cheaper': '更便宜',
  'More food': '更多美食',
  'Slower': '慢一點',
  'Nature': '自然',
  'Customize': '自訂',
  'CUSTOMIZE': '自訂',
  'CONFIRM': '確認',
  'CONFIRMED': '已確認',
  'USE CUSTOMIZED PLAN': '使用自訂計畫',
  'Thinking...': '思考中...',
  'Start date': '開始日期',
  'End date': '結束日期',
  'Trip dates': '旅程日期',
  'Trip tags': '旅程標籤',
  'Bookings': '預訂',
  'First schedule stops': '前幾個日程停靠點',
  'Add schedule stop': '新增日程停靠點',
  'Add destination': '新增目的地',
  'Activity': '活動',
  'Time': '時間',
  'Cost': '費用',
  'Cancel': '取消',
  'Add': '新增',
  'Edit': '編輯',
  'Save': '儲存',
  'Amount': '金額',
  'Note': '備註',
  'Used': '已使用',
  'Unused': '未使用',
  'Create new spending': '新增支出',
  'Edit spending': '編輯支出',
  'No spendings yet': '尚無支出',
  'Route map': '路線地圖',
  'Open map': '開啟地圖',
  'Checklist item': '清單項目',
  'Category name': '分類名稱',
  'New item': '新項目',
  'Add category': '新增分類',
  'Add booking': '新增預訂',
  'Title': '標題',
  'Date': '日期',
  'Reference': '參考編號',
  'Open chat': '開啟聊天',
  'Planned': '預計',
  'Actual': '實際',
  'Free': '免費',
  'Start': '開始',
  'Delete': '刪除',
  'Delete trip': '刪除旅程',
  'Trip options': '旅程選項',
  'Undo': '復原',
  'Travel Info': '旅行資訊',
  'Weather': '天氣',
  'Rain expected after 2 PM. Move outdoor shrines earlier.':
      '下午 2 點後可能下雨。建議把戶外神社行程提前。',
  'Transport': '交通',
  'IC cards work across trains and buses around central Kyoto.':
      'IC 卡可用於京都市中心多數電車與公車。',
  'Local costs': '當地花費',
  'Temples are often low-cost; cash is still useful for markets.':
      '寺廟通常花費不高；市場仍建議準備現金。',
  'Where is Kyoto Station?': '京都車站在哪裡？',
  'No pork, please.': '請不要豬肉。',
  'I have a reservation.': '我有預約。',
  'Spent': '已花費',
  'Stay': '住宿',
  'Activities': '活動',
  'Essentials': '必需品',
  'Passport': '護照',
  'Travel adapter': '旅行轉接頭',
  'Power bank': '行動電源',
  'Clothing': '衣物',
  'Comfortable walking shoes': '舒適步行鞋',
  'Light rain jacket': '輕便雨衣',
  'Arrive at Kyoto Station': '抵達京都車站',
  'Nishiki Market Food Tour': '錦市場美食導覽',
  'Fushimi Inari-taisha Hike': '伏見稻荷大社健行',
  'Kinkaku-ji Golden Pavilion': '金閣寺',
  'Gion District Walk': '祇園散步',
  'AI Packing List': 'AI 打包清單',
  'How do you want to start?': '你想怎麼開始？',
  'Plan Step-by-Step': '逐步規劃',
  'Explore ideas, compare pacing, then let AI draft it.':
      '探索想法、比較節奏，再讓 AI 草擬行程。',
  'Plan with AI': '用 AI 規劃',
  'Search a real city, choose dates, tags, and generate.': '搜尋真實城市、選擇日期與標籤後產生。',
  'Create Manually': '手動建立',
  'Enter destination, dates, budget, people, and tags.': '輸入目的地、日期、預算、人數與標籤。',
  'Use Saved Trip Template': '使用已儲存旅程範本',
  'Start from a polished Kyoto sample and edit later.': '從整理好的京都範例開始，之後再編輯。',
  'Hello, where would you like to go?': '你好，想去哪裡？',
  'Choose guided suggestions or describe the full trip.': '選擇引導建議，或直接描述完整旅程。',
  'Describe the trip...': '描述這趟旅程...',
  'Type changes or confirm...': '輸入修改或確認...',
  'AI Flow': 'AI 流程',
  'Manual': '手動',
  'Generate with AI': '使用 AI 產生',
  'Create schedule': '建立日程',
  'Create a schedule to see your route here.': '建立日程後即可在這裡查看路線。',
  'Destination': '目的地',
  'Search a real city': '搜尋真實城市',
  'Currency': '貨幣',
  'Local': '本地',
  'Original': '原始',
  'Local / Original': '本地 / 原始',
  'Total budget': '總預算',
  'US dollars': '美元',
  'New Taiwan dollars': '新台幣',
  'Indonesian rupiah': '印尼盾',
  'Japanese yen': '日圓',
  'euros': '歐元',
  'Number of travelers': '旅行人數',
  'Decrease travelers': '減少旅客',
  'Increase travelers': '增加旅客',
  '1 traveler': '1 位旅客',
  '2 travelers': '2 位旅客',
  '4 travelers': '4 位旅客',
  'Single-traveler pacing': '單人旅行節奏',
  'Pair-friendly route': '適合兩人的路線',
  'Small group timing': '小團體行程節奏',
  'Airline optional': '航空公司（選填）',
  'Confirmation': '確認碼',
  'Add custom tag': '新增自訂標籤',
  'Save draft edits': '儲存草稿修改',
  'Popular starting points': '熱門起點',
  'Trip length': '旅程長度',
  'Comfortable timing': '舒適的時間安排',
  'Shared plans and votes': '共享計畫與投票',
  'Personal route and pace': '個人路線與節奏',
  'Balanced pace': '平衡節奏',
  'Fast weekend plan': '快速週末計畫',
  'More room for day trips': '更多一日遊空間',
  'Lean and efficient': '精簡有效率',
  'Comfortable mid-range': '舒適中等預算',
  'More flexible picks': '更彈性的選擇',
  'Name': '姓名',
  'Language': '語言',
  'Notifications': '通知',
  'Theme': '主題',
  'Light': '淺色',
  'Dark': '深色',
  'Save profile': '儲存個人資料',
  'Sign out': '登出',
  'Delete account': '刪除帳戶',
  'Email': '電子郵件',
  'Phone': '電話',
  'Continue with Google': '使用 Google 繼續',
  'Facebook setup needed': '需要設定 Facebook',
  'Password': '密碼',
  'Create account': '建立帳戶',
  'Sign in': '登入',
  'Forgot password?': '忘記密碼？',
  'Phone number': '電話號碼',
  'SMS code': '簡訊驗證碼',
  'Verify code': '驗證代碼',
  'Send SMS code': '傳送簡訊代碼',
  'Resend code': '重新傳送代碼',
  'Change phone': '更改電話',
  'Login': '登入',
  'Customize AI Draft': '自訂 AI 草稿',
  'End': '結束',
  'English (US)': '英文（美國）',
  'Chinese (Taiwan / Traditional)': '繁體中文（台灣）',
  'e.g. anime, halal food, wheelchair access': '例如：動漫、清真食物、無障礙通行',
  'Remember me for 30 days': '記住我 30 天',
  'Useful while debugging. Sign out anytime from Profile.':
      '除錯時很方便。可隨時在個人資料登出。',
  'Welcome Back': '歡迎回來',
  'Current trip': '目前旅程',
  'Settings': '設定',
  'General': '一般',
  'Travel preferences': '旅行偏好',
  'Appearance & performance': '外觀與效能',
  'Data': '資料',
  'Account actions': '帳戶操作',
  'Profile identity, sign-in methods, and account access.': '個人身分、登入方式與帳戶存取。',
  'Language, notifications, and device permissions.': '語言、通知與裝置權限。',
  'Currency behavior and the interests used for trip planning.':
      '貨幣顯示方式與旅程規劃使用的興趣。',
  'Theme, animation, image quality, and battery behavior.':
      '主題、動畫、圖片品質與電池使用方式。',
  'Review content that is no longer active.': '查看已不再使用的內容。',
  'Sign out of this device or permanently delete data.': '登出此裝置或永久刪除資料。',
  'Display name': '顯示名稱',
  'Edit display name': '編輯顯示名稱',
  'Display name cannot be empty.': '顯示名稱不能空白。',
  'Display name updated.': '顯示名稱已更新。',
  'Change profile photo': '更換個人照片',
  'Take a photo': '拍照',
  'Choose from gallery': '從相簿選擇',
  'Profile photo updated.': '個人照片已更新。',
  'Search languages': '搜尋語言',
  'Search currency or code': '搜尋貨幣或代碼',
  'No results found.': '找不到結果。',
  'Account': '帳戶',
  'Google': 'Google',
  'Linked': '已連結',
  'Link': '連結',
  'On': '開啟',
  'Delete account?': '刪除帳戶？',
  'This deletes your sign-in account, profile, and saved trips. This cannot be undone.':
      '這會刪除你的登入帳戶、個人資料和已儲存旅程，且無法復原。',
  'Add custom interest': '新增自訂興趣',
  'Save interests': '儲存興趣',
  'That interest is not allowed.': '不允許使用這個興趣。',
};
