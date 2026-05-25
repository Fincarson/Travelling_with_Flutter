import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/local_api_keys.dart';
import '../auth/data/account_auth_service.dart';

const _primary = Color(0xFF355872);
const _secondary = Color(0xFF7AAACE);
const _accent = Color(0xFF9CD5FF);
const _bg = Color(0xFFF7F8F0);

class TravelAgentTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primary,
        primary: _primary,
        secondary: _secondary,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: _bg,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: _primary,
        displayColor: _primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFEFF3F6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFEFF3F6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: _accent, width: 2),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = light();
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF17232A),
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        surface: const Color(0xFF22313A),
      ),
    );
  }
}

class TravelAgentApp extends StatefulWidget {
  const TravelAgentApp({required this.account, super.key});

  final AuthenticatedAccount account;

  @override
  State<TravelAgentApp> createState() => _TravelAgentAppState();
}

class _TravelAgentAppState extends State<TravelAgentApp> {
  final _repository = TravelDataRepository(FirebaseFirestore.instance);
  final _authService = AccountAuthService();
  var _showOnboarding = true;
  var _isLoading = true;
  var _tab = _NavTab.home;
  var _screen = _Screen.dashboard;
  var _user = const UserProfile(name: '', email: '', interests: []);
  final List<Trip> _trips = [];
  Trip? _selectedTrip;
  Trip? _activeTrip;
  String _initialChat = '';
  String? _accountId;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final accountId = widget.account.uid;

    try {
      final profile = await _repository.loadUser(accountId);
      final trips = await _repository.loadTrips(accountId);
      if (!mounted) return;
      setState(() {
        _accountId = accountId;
        _user =
            profile ??
            UserProfile(
              name: widget.account.name,
              email: widget.account.email ?? '',
              interests: const [],
              language: 'en',
              notificationsEnabled: true,
              themeMode: 'Light',
            );
        _trips
          ..clear()
          ..addAll(trips);
        _activeTrip = _firstOngoingTrip(trips);
        _showOnboarding = profile == null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load online trip data: $error';
        _isLoading = false;
      });
    }
  }

  void _openTrip(Trip trip) {
    setState(() {
      _selectedTrip = trip;
      _screen = _Screen.itinerary;
      _tab = _NavTab.trips;
    });
  }

  Future<void> _completeOnboarding(UserProfile profile) async {
    final accountId = widget.account.uid;

    setState(() {
      _accountId = accountId;
      _user = profile;
      _showOnboarding = false;
      _loadError = null;
    });

    try {
      await _repository.saveUser(accountId, profile);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not save profile online: $error');
    }
  }

  Future<void> _saveProfile(UserProfile profile) async {
    setState(() {
      _user = profile;
      _loadError = null;
    });

    final accountId = _accountId;
    if (accountId == null) return;
    try {
      await _repository.saveUser(accountId, profile);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not save profile online: $error');
    }
  }

  Future<void> _createTrip(Trip trip) async {
    setState(() {
      _trips.insert(0, trip);
      _selectedTrip = trip;
      _screen = _Screen.itinerary;
      _tab = _NavTab.trips;
      _loadError = null;
    });

    await _saveTripOnline(trip);
  }

  Future<void> _startTrip(Trip trip) async {
    final previousActive = _activeTrip;
    setState(() {
      final started = trip.copyWith(status: TripStatus.ongoing);
      final index = _trips.indexWhere((item) => item.id == trip.id);
      if (index >= 0) _trips[index] = started;
      _activeTrip = started;
      _selectedTrip = started;
      _screen = _Screen.dashboard;
      _tab = _NavTab.home;
    });

    final started = _selectedTrip;
    if (started != null) await _saveTripOnline(started);
    if (previousActive != null && previousActive.id != trip.id) {
      await _saveTripOnline(
        previousActive.copyWith(status: TripStatus.upcoming),
      );
    }
  }

  Future<void> _updateTrip(Trip trip) async {
    setState(() {
      final index = _trips.indexWhere((item) => item.id == trip.id);
      if (index >= 0) _trips[index] = trip;
      if (_selectedTrip?.id == trip.id) _selectedTrip = trip;
      if (_activeTrip?.id == trip.id) _activeTrip = trip;
      _loadError = null;
    });

    await _saveTripOnline(trip);
  }

  Future<void> _saveTripOnline(Trip trip) async {
    final accountId = _accountId;
    if (accountId == null) return;
    try {
      await _repository.saveTrip(accountId, trip);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not save trip online: $error');
    }
  }

  Future<void> _deleteAccount() async {
    final accountId = _accountId ?? widget.account.uid;
    try {
      _authService.ensureCanDeleteCurrentAccount();
      await _repository.deleteUserData(accountId);
      await _authService.deleteCurrentAccount();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not delete account: $error');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _user.themeMode == 'Dark'
          ? TravelAgentTheme.dark()
          : TravelAgentTheme.light(),
      child: ColoredBox(
        color: const Color(0xFFE5E7EB),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ClipRect(
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                body: SafeArea(
                  bottom: false,
                  child: _isLoading
                      ? const LoadingScreen()
                      : _showOnboarding
                      ? OnboardingScreen(
                          account: widget.account,
                          onComplete: _completeOnboarding,
                        )
                      : Stack(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: _buildScreen(),
                            ),
                            if (_screen != _Screen.create)
                              _BottomNav(tab: _tab, onSelect: _selectTab),
                            if (_loadError != null)
                              Positioned(
                                left: 16,
                                right: 16,
                                top: 12,
                                child: SyncBanner(message: _loadError!),
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreen() {
    final trips = _trips.isEmpty ? [mockKyotoTrip] : _trips;
    switch (_screen) {
      case _Screen.dashboard:
        return DashboardScreen(
          key: const ValueKey('dashboard'),
          user: _user,
          trips: trips,
          activeTrip: _activeTrip,
          onCreate: () => setState(() {
            _screen = _Screen.create;
            _tab = _NavTab.add;
          }),
          onOpenTrip: _openTrip,
          onAskAi: (query) => setState(() {
            _initialChat = query;
            _screen = _Screen.chatRoom;
            _tab = _NavTab.chat;
          }),
          onOpenInfo: () => setState(() => _screen = _Screen.info),
          onOpenTranslate: () => setState(() => _screen = _Screen.translate),
          onOpenMap: () => setState(() => _screen = _Screen.map),
        );
      case _Screen.create:
        return CreateTripScreen(
          key: const ValueKey('create'),
          onBack: () => setState(() {
            _screen = _Screen.dashboard;
            _tab = _NavTab.home;
          }),
          onGenerate: _createTrip,
        );
      case _Screen.itinerary:
        return ItineraryScreen(
          key: ValueKey('itinerary-${_selectedTrip?.id}'),
          trip: _selectedTrip ?? mockKyotoTrip,
          onBack: () => setState(() {
            _screen = _Screen.dashboard;
            _tab = _NavTab.home;
          }),
          onOpenChat: () => setState(() {
            _initialChat =
                'Help optimize ${(_selectedTrip ?? mockKyotoTrip).destination}.';
            _screen = _Screen.chatRoom;
            _tab = _NavTab.chat;
          }),
          onOpenBudget: () => setState(() => _screen = _Screen.budget),
          onOpenPacking: () => setState(() => _screen = _Screen.packing),
          onOpenMap: () => setState(() => _screen = _Screen.map),
          onUpdateTrip: _updateTrip,
        );
      case _Screen.trips:
        return TripsScreen(
          key: const ValueKey('trips'),
          trips: _trips,
          onBack: () => setState(() => _screen = _Screen.dashboard),
          onCreate: () => setState(() {
            _screen = _Screen.create;
            _tab = _NavTab.add;
          }),
          onOpenTrip: _openTrip,
          onStartTrip: _startTrip,
        );
      case _Screen.chatList:
        return ChatListScreen(
          key: const ValueKey('chat-list'),
          trips: _trips,
          onOpen: (query) => setState(() {
            _initialChat = query;
            _screen = _Screen.chatRoom;
          }),
        );
      case _Screen.chatRoom:
        return ChatRoomScreen(
          key: ValueKey('chat-$_initialChat'),
          initialQuery: _initialChat,
          onBack: () => setState(() => _screen = _Screen.chatList),
        );
      case _Screen.profile:
        return ProfileScreen(
          key: const ValueKey('profile'),
          account: widget.account,
          user: _user,
          onSave: _saveProfile,
          onSignOut: _authService.signOut,
          onDeleteAccount: _deleteAccount,
        );
      case _Screen.map:
        return MapScreen(
          key: const ValueKey('map'),
          trip: _selectedTrip ?? mockKyotoTrip,
          onBack: () => setState(
            () => _screen = _selectedTrip == null
                ? _Screen.dashboard
                : _Screen.itinerary,
          ),
        );
      case _Screen.info:
        return InfoScreen(
          key: const ValueKey('info'),
          onBack: () => setState(() => _screen = _Screen.dashboard),
        );
      case _Screen.translate:
        return TranslateScreen(
          key: const ValueKey('translate'),
          onBack: () => setState(() => _screen = _Screen.dashboard),
        );
      case _Screen.budget:
        return BudgetScreen(
          key: const ValueKey('budget'),
          trip: _selectedTrip ?? mockKyotoTrip,
          onBack: () => setState(() => _screen = _Screen.itinerary),
        );
      case _Screen.packing:
        return PackingScreen(
          key: const ValueKey('packing'),
          trip: _selectedTrip ?? mockKyotoTrip,
          onBack: () => setState(() => _screen = _Screen.itinerary),
        );
    }
  }

  void _selectTab(_NavTab tab) {
    setState(() {
      _tab = tab;
      _screen = switch (tab) {
        _NavTab.home => _Screen.dashboard,
        _NavTab.trips => _Screen.trips,
        _NavTab.add => _Screen.create,
        _NavTab.chat => _Screen.chatList,
        _NavTab.profile => _Screen.profile,
      };
    });
  }
}

Trip? _firstOngoingTrip(List<Trip> trips) {
  for (final trip in trips) {
    if (trip.status == TripStatus.ongoing) return trip;
  }
  return null;
}

enum _Screen {
  dashboard,
  create,
  itinerary,
  trips,
  chatList,
  chatRoom,
  profile,
  map,
  info,
  translate,
  budget,
  packing,
}

enum _NavTab { home, trips, add, chat, profile }

enum TripStatus { upcoming, ongoing, past }

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

class Trip {
  const Trip({
    required this.id,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.spent,
    required this.groupType,
    required this.status,
    required this.images,
    required this.items,
    required this.bookings,
    required this.checklist,
    this.currency = 'USD',
    this.preferences = const [],
    this.budgetCategories = const [],
    this.placeId,
    this.formattedAddress,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String destination;
  final String startDate;
  final String endDate;
  final int budget;
  final int spent;
  final String groupType;
  final TripStatus status;
  final List<String> images;
  final List<ItineraryItem> items;
  final List<Booking> bookings;
  final List<ChecklistCategory> checklist;
  final String currency;
  final List<String> preferences;
  final List<BudgetCategory> budgetCategories;
  final String? placeId;
  final String? formattedAddress;
  final double? latitude;
  final double? longitude;

  Trip copyWith({
    TripStatus? status,
    int? spent,
    int? budget,
    String? destination,
    String? startDate,
    String? endDate,
    String? groupType,
    String? currency,
    List<String>? images,
    List<ItineraryItem>? items,
    List<Booking>? bookings,
    List<ChecklistCategory>? checklist,
    List<String>? preferences,
    List<BudgetCategory>? budgetCategories,
  }) => Trip(
    id: id,
    destination: destination ?? this.destination,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    budget: budget ?? this.budget,
    spent: spent ?? this.spent,
    groupType: groupType ?? this.groupType,
    status: status ?? this.status,
    images: images ?? this.images,
    items: items ?? this.items,
    bookings: bookings ?? this.bookings,
    checklist: checklist ?? this.checklist,
    currency: currency ?? this.currency,
    preferences: preferences ?? this.preferences,
    budgetCategories: budgetCategories ?? this.budgetCategories,
    placeId: placeId,
    formattedAddress: formattedAddress,
    latitude: latitude,
    longitude: longitude,
  );

  Map<String, dynamic> toMap() => {
    'destination': destination,
    'placeId': placeId,
    'formattedAddress': formattedAddress,
    'latitude': latitude,
    'longitude': longitude,
    'startDate': startDate,
    'endDate': endDate,
    'budget': budget,
    'spent': spent,
    'groupType': groupType,
    'currency': currency,
    'status': status.name,
    'images': images,
    'items': items.map((item) => item.toMap()).toList(),
    'bookings': bookings.map((booking) => booking.toMap()).toList(),
    'checklist': checklist.map((category) => category.toMap()).toList(),
    'preferences': preferences,
    'budgetCategories': budgetCategories
        .map((category) => category.toMap())
        .toList(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static Trip fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? const <String, dynamic>{};
    return Trip(
      id: doc.id,
      destination: (map['destination'] as String?) ?? 'Untitled trip',
      placeId: map['placeId'] as String?,
      formattedAddress: map['formattedAddress'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      startDate: (map['startDate'] as String?) ?? '',
      endDate: (map['endDate'] as String?) ?? '',
      budget: (map['budget'] as num?)?.toInt() ?? 0,
      spent: (map['spent'] as num?)?.toInt() ?? 0,
      groupType: (map['groupType'] as String?) ?? 'Solo',
      currency: (map['currency'] as String?) ?? 'USD',
      status: TripStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => TripStatus.upcoming,
      ),
      images: ((map['images'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(),
      items: ((map['items'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((item) => ItineraryItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      bookings: ((map['bookings'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((item) => Booking.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      checklist: ((map['checklist'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                ChecklistCategory.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
      preferences: ((map['preferences'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(),
      budgetCategories:
          ((map['budgetCategories'] as List<dynamic>?) ?? const [])
              .whereType<Map>()
              .map(
                (item) =>
                    BudgetCategory.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList(),
    );
  }
}

class ItineraryItem {
  const ItineraryItem(this.day, this.time, this.activity, this.type, this.cost);
  final int day;
  final String time;
  final String activity;
  final IconData type;
  final int cost;

  Map<String, dynamic> toMap() => {
    'day': day,
    'time': time,
    'activity': activity,
    'type': _iconToMap(type),
    'cost': cost,
  };

  static ItineraryItem fromMap(Map<String, dynamic> map) => ItineraryItem(
    (map['day'] as num?)?.toInt() ?? 1,
    (map['time'] as String?) ?? '',
    (map['activity'] as String?) ?? 'Activity',
    _iconFromMap(map['type']),
    (map['cost'] as num?)?.toInt() ?? 0,
  );
}

class Booking {
  const Booking(
    this.title,
    this.date,
    this.time,
    this.reference,
    this.cost,
    this.icon,
  );
  final String title;
  final String date;
  final String time;
  final String reference;
  final int cost;
  final IconData icon;

  Map<String, dynamic> toMap() => {
    'title': title,
    'date': date,
    'time': time,
    'reference': reference,
    'cost': cost,
    'icon': _iconToMap(icon),
  };

  static Booking fromMap(Map<String, dynamic> map) => Booking(
    (map['title'] as String?) ?? 'Booking',
    (map['date'] as String?) ?? '',
    (map['time'] as String?) ?? '',
    (map['reference'] as String?) ?? '',
    (map['cost'] as num?)?.toInt() ?? 0,
    _iconFromMap(map['icon']),
  );
}

class BudgetCategory {
  const BudgetCategory({
    required this.id,
    required this.category,
    required this.planned,
    required this.actual,
  });

  final String id;
  final String category;
  final int planned;
  final int actual;

  BudgetCategory copyWith({int? planned, int? actual}) => BudgetCategory(
    id: id,
    category: category,
    planned: planned ?? this.planned,
    actual: actual ?? this.actual,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'planned': planned,
    'actual': actual,
  };

  static BudgetCategory fromMap(Map<String, dynamic> map) => BudgetCategory(
    id: (map['id'] as String?) ?? 'category',
    category: (map['category'] as String?) ?? 'Category',
    planned: (map['planned'] as num?)?.toInt() ?? 0,
    actual: (map['actual'] as num?)?.toInt() ?? 0,
  );
}

class ChecklistCategory {
  const ChecklistCategory(this.category, this.items);
  final String category;
  final List<String> items;

  Map<String, dynamic> toMap() => {'category': category, 'items': items};

  static ChecklistCategory fromMap(Map<String, dynamic> map) =>
      ChecklistCategory(
        (map['category'] as String?) ?? 'Checklist',
        ((map['items'] as List<dynamic>?) ?? const [])
            .whereType<String>()
            .toList(),
      );
}

Map<String, dynamic> _iconToMap(IconData icon) => {'name': _iconName(icon)};

IconData _iconFromMap(Object? value) {
  if (value is! Map) return Icons.place_rounded;
  final map = Map<String, dynamic>.from(value);
  return _iconByName(map['name'] as String?);
}

String _iconName(IconData icon) {
  if (icon == Icons.train_rounded) return 'train';
  if (icon == Icons.restaurant_rounded) return 'restaurant';
  if (icon == Icons.hiking_rounded) return 'hiking';
  if (icon == Icons.temple_buddhist_rounded) return 'temple';
  if (icon == Icons.directions_walk_rounded) return 'walk';
  if (icon == Icons.flight_takeoff_rounded) return 'flight';
  if (icon == Icons.hotel_rounded) return 'hotel';
  if (icon == Icons.museum_rounded) return 'museum';
  if (icon == Icons.beach_access_rounded) return 'beach';
  if (icon == Icons.local_cafe_rounded) return 'cafe';
  if (icon == Icons.shopping_bag_rounded) return 'shopping';
  return 'place';
}

IconData _iconByName(String? name) {
  switch (name) {
    case 'train':
      return Icons.train_rounded;
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'hiking':
      return Icons.hiking_rounded;
    case 'temple':
      return Icons.temple_buddhist_rounded;
    case 'walk':
      return Icons.directions_walk_rounded;
    case 'flight':
      return Icons.flight_takeoff_rounded;
    case 'hotel':
      return Icons.hotel_rounded;
    case 'museum':
      return Icons.museum_rounded;
    case 'beach':
      return Icons.beach_access_rounded;
    case 'cafe':
      return Icons.local_cafe_rounded;
    case 'shopping':
      return Icons.shopping_bag_rounded;
    default:
      return Icons.place_rounded;
  }
}

class TravelDataRepository {
  const TravelDataRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String accountId) =>
      _firestore.collection('travel_users').doc(accountId);

  CollectionReference<Map<String, dynamic>> _tripsRef(String accountId) =>
      _userDoc(accountId).collection('trips');

  Future<UserProfile?> loadUser(String accountId) async {
    final snapshot = await _userDoc(accountId).get();
    if (!snapshot.exists) return null;
    return UserProfile.fromMap(snapshot.data() ?? const <String, dynamic>{});
  }

  Future<void> saveUser(String accountId, UserProfile profile) =>
      _userDoc(accountId).set(profile.toMap(), SetOptions(merge: true));

  Future<List<Trip>> loadTrips(String accountId) async {
    final snapshot = await _tripsRef(accountId).orderBy('updatedAt').get();
    final trips = snapshot.docs.map(Trip.fromDoc).toList();
    return trips.reversed.toList();
  }

  Future<void> saveTrip(String accountId, Trip trip) => _tripsRef(
    accountId,
  ).doc(trip.id).set(trip.toMap(), SetOptions(merge: true));

  Future<void> deleteUserData(String accountId) async {
    final trips = await _tripsRef(accountId).get();
    final batch = _firestore.batch();
    for (final trip in trips.docs) {
      batch.delete(trip.reference);
    }
    batch.delete(_userDoc(accountId));
    await batch.commit();
  }
}

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.name,
    required this.formatted,
    required this.latitude,
    required this.longitude,
    required this.placeId,
    this.country,
  });

  final String name;
  final String formatted;
  final double latitude;
  final double longitude;
  final String placeId;
  final String? country;

  static PlaceSuggestion fromMap(Map<String, dynamic> map) {
    final city =
        map['name'] as String? ??
        map['city'] as String? ??
        map['county'] as String? ??
        map['state'] as String? ??
        map['name'] as String?;
    final country = map['country'] as String?;
    final formatted = (map['formatted'] as String?) ?? city ?? 'Unknown place';
    final name = city == null
        ? formatted
        : country == null
        ? city
        : '$city, $country';
    return PlaceSuggestion(
      name: name,
      formatted: formatted,
      latitude:
          (map['latitude'] as num?)?.toDouble() ??
          (map['lat'] as num?)?.toDouble() ??
          0,
      longitude:
          (map['longitude'] as num?)?.toDouble() ??
          (map['lon'] as num?)?.toDouble() ??
          0,
      placeId:
          (map['placeId'] as String?) ??
          (map['place_id'] as String?) ??
          formatted,
      country: country,
    );
  }
}

class GeoapifyPlacesService {
  GeoapifyPlacesService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<List<PlaceSuggestion>> searchDestinations(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];

    if (LocalApiKeys.hasGeoapifyApiKey) {
      return _searchDestinationsDirectly(trimmed);
    }

    final callable = _functions.httpsCallable('searchPlaces');
    final response = await callable.call<Map<String, dynamic>>({
      'query': trimmed,
    });
    final results = (response.data['results'] as List<dynamic>?) ?? const [];
    return _placeSuggestionsFromResults(results);
  }

  Future<List<PlaceSuggestion>> _searchDestinationsDirectly(
    String query,
  ) async {
    final url = Uri.https('api.geoapify.com', '/v1/geocode/autocomplete', {
      'text': query,
      'format': 'json',
      'type': 'city',
      'limit': '6',
      'apiKey': LocalApiKeys.geoapifyApiKey,
    });

    final response = await http.get(url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Place search is unavailable.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (body['results'] as List<dynamic>?) ?? const [];
    return _placeSuggestionsFromResults(results);
  }

  List<PlaceSuggestion> _placeSuggestionsFromResults(List<dynamic> results) {
    return results
        .whereType<Map>()
        .map((item) => PlaceSuggestion.fromMap(Map<String, dynamic>.from(item)))
        .where((place) => place.latitude != 0 && place.longitude != 0)
        .toList();
  }
}

class TravelAssistantService {
  TravelAssistantService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<String> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return '';

    if (LocalApiKeys.hasOpenAiApiKey) {
      return _sendMessageDirectly(trimmed);
    }

    final callable = _functions.httpsCallable('chatWithAssistant');
    final response = await callable.call<Map<String, dynamic>>({
      'message': trimmed,
    });
    return (response.data['reply'] as String?)?.trim() ?? '';
  }

  Future<String> _sendMessageDirectly(String message) async {
    final response = await http.post(
      Uri.https('api.openai.com', '/v1/responses'),
      headers: {
        'Authorization': 'Bearer ${LocalApiKeys.openAiApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-5.5',
        'instructions':
            'You are a concise travel planning assistant inside a mobile app. '
            'Help with itinerary order, budget tradeoffs, packing, food, '
            'transit, and practical destination advice. Keep replies friendly '
            'and short.',
        'input': message,
        'store': false,
        'reasoning': {'effort': 'low'},
        'text': {'verbosity': 'low'},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI chat is unavailable.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final outputText = body['output_text'];
    if (outputText is String && outputText.trim().isNotEmpty) {
      return outputText.trim();
    }

    final output = (body['output'] as List<dynamic>?) ?? const [];
    return output
        .whereType<Map>()
        .expand((item) => (item['content'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((content) => content['text'])
        .whereType<String>()
        .join('\n')
        .trim();
  }

  Future<GeneratedTripPlan> generateTripPlan({
    required PlaceSuggestion place,
    required DateTime startDate,
    required DateTime endDate,
    required int budget,
    required String groupType,
    required List<String> preferences,
    required String currency,
    String airline = '',
    String flightConfirmation = '',
  }) async {
    if (!LocalApiKeys.hasOpenAiApiKey) {
      throw Exception('OpenAI API key is missing.');
    }

    final response = await http.post(
      Uri.https('api.openai.com', '/v1/responses'),
      headers: {
        'Authorization': 'Bearer ${LocalApiKeys.openAiApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-5.5',
        'instructions': [
          'Generate a practical travel itinerary as strict JSON only.',
          'Use current attraction names for the destination.',
          'Keep costs realistic but approximate.',
          'Return no markdown and no explanation.',
        ].join(' '),
        'input': jsonEncode({
          'destination': place.name,
          'formattedAddress': place.formatted,
          'startDate': _dateKey(startDate),
          'endDate': _dateKey(endDate),
          'budgetUsd': budget,
          'currency': currency,
          'groupType': groupType,
          'preferences': preferences,
          'flight': {'airline': airline, 'confirmation': flightConfirmation},
          'schema': {
            'items': [
              {
                'day': 1,
                'time': '09:00 AM',
                'activity': 'Activity name',
                'type': 'place|food|walk|museum|beach|shopping|train',
                'cost': 25,
              },
            ],
            'bookings': [
              {
                'title': 'Hotel or transport booking',
                'date': 'YYYY-MM-DD',
                'time': '15:00',
                'reference': 'short reference',
                'cost': 300,
                'type': 'hotel|flight|train|place',
              },
            ],
            'checklist': [
              {
                'category': 'Essentials',
                'items': ['Passport'],
              },
            ],
          },
        }),
        'store': false,
        'reasoning': {'effort': 'low'},
        'text': {'verbosity': 'low'},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI itinerary generation failed.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _responseOutputText(body);
    final data = _decodeJsonObject(text);
    return GeneratedTripPlan.fromMap(data);
  }

  Future<CreateTripAiResponse> createTripReply({
    required String message,
    required CreateTripDraft currentDraft,
    required List<CreateTripChatMessage> history,
  }) async {
    if (!LocalApiKeys.hasOpenAiApiKey) {
      throw Exception('OpenAI API key is missing.');
    }

    final response = await http.post(
      Uri.https('api.openai.com', '/v1/responses'),
      headers: {
        'Authorization': 'Bearer ${LocalApiKeys.openAiApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-5.5',
        'instructions': [
          'You are the Create Trip assistant inside a mobile travel app.',
          'Actually interpret the user message and update the trip draft.',
          'Ask for exactly one missing important field at a time.',
          'When useful, create a tappable widget with 2 to 4 options.',
          'Widget option values must be short user messages the app can send back.',
          'Required final fields: destination, startDate, endDate, budget, groupType.',
          'Dates must be ISO yyyy-MM-dd. groupType must be Solo, Friends, Family, or Tour.',
          'Return only JSON matching the schema.',
        ].join(' '),
        'input': jsonEncode({
          'latestMessage': message,
          'currentDraft': currentDraft.toAiMap(),
          'recentHistory': history
              .take(8)
              .map(
                (item) => {
                  'role': item.fromUser ? 'user' : 'assistant',
                  'text': item.text,
                },
              )
              .toList(),
          'today': _dateKey(DateTime.now()),
        }),
        'store': false,
        'reasoning': {'effort': 'low'},
        'text': {
          'verbosity': 'low',
          'format': {
            'type': 'json_schema',
            'name': 'create_trip_reply',
            'strict': true,
            'schema': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'message': {'type': 'string'},
                'draft': {
                  'type': 'object',
                  'additionalProperties': false,
                  'properties': {
                    'destination': {
                      'type': ['string', 'null'],
                    },
                    'startDate': {
                      'type': ['string', 'null'],
                    },
                    'endDate': {
                      'type': ['string', 'null'],
                    },
                    'budget': {
                      'type': ['string', 'null'],
                    },
                    'groupType': {
                      'type': ['string', 'null'],
                    },
                    'preferences': {
                      'type': 'array',
                      'items': {'type': 'string'},
                    },
                  },
                  'required': [
                    'destination',
                    'startDate',
                    'endDate',
                    'budget',
                    'groupType',
                    'preferences',
                  ],
                },
                'widget': {
                  'type': ['object', 'null'],
                  'additionalProperties': false,
                  'properties': {
                    'title': {'type': 'string'},
                    'options': {
                      'type': 'array',
                      'minItems': 2,
                      'maxItems': 4,
                      'items': {
                        'type': 'object',
                        'additionalProperties': false,
                        'properties': {
                          'label': {'type': 'string'},
                          'value': {'type': 'string'},
                          'description': {'type': 'string'},
                        },
                        'required': ['label', 'value', 'description'],
                      },
                    },
                  },
                  'required': ['title', 'options'],
                },
              },
              'required': ['message', 'draft', 'widget'],
            },
          },
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI create trip chat failed.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = _decodeJsonObject(_responseOutputText(body));
    return CreateTripAiResponse.fromMap(data, fallbackDraft: currentDraft);
  }
}

class GeneratedTripPlan {
  const GeneratedTripPlan({
    required this.items,
    required this.bookings,
    required this.checklist,
  });

  final List<ItineraryItem> items;
  final List<Booking> bookings;
  final List<ChecklistCategory> checklist;

  static GeneratedTripPlan fromMap(Map<String, dynamic> map) {
    final items = ((map['items'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((item) {
          final data = Map<String, dynamic>.from(item);
          return ItineraryItem(
            (data['day'] as num?)?.toInt() ?? 1,
            (data['time'] as String?) ?? '09:00 AM',
            (data['activity'] as String?) ?? 'Explore local highlights',
            _iconByName(data['type'] as String?),
            (data['cost'] as num?)?.toInt() ?? 0,
          );
        })
        .take(12)
        .toList();

    final bookings = ((map['bookings'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((booking) {
          final data = Map<String, dynamic>.from(booking);
          return Booking(
            (data['title'] as String?) ?? 'Trip booking',
            (data['date'] as String?) ?? '',
            (data['time'] as String?) ?? '',
            (data['reference'] as String?) ?? 'TBD',
            (data['cost'] as num?)?.toInt() ?? 0,
            _iconByName(data['type'] as String?),
          );
        })
        .take(4)
        .toList();

    final checklist = ((map['checklist'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((category) {
          final data = Map<String, dynamic>.from(category);
          return ChecklistCategory(
            (data['category'] as String?) ?? 'Essentials',
            ((data['items'] as List<dynamic>?) ?? const [])
                .whereType<String>()
                .take(8)
                .toList(),
          );
        })
        .where((category) => category.items.isNotEmpty)
        .take(5)
        .toList();

    return GeneratedTripPlan(
      items: items,
      bookings: bookings,
      checklist: checklist,
    );
  }
}

String _responseOutputText(Map<String, dynamic> body) {
  final outputText = body['output_text'];
  if (outputText is String) return outputText;

  final output = (body['output'] as List<dynamic>?) ?? const [];
  return output
      .whereType<Map>()
      .expand((item) => (item['content'] as List<dynamic>?) ?? const [])
      .whereType<Map>()
      .map((content) => content['text'])
      .whereType<String>()
      .join('\n')
      .trim();
}

Map<String, dynamic> _decodeJsonObject(String text) {
  final trimmed = text.trim();
  final cleaned = trimmed
      .replaceFirst(RegExp(r'^```(?:json)?', multiLine: true), '')
      .replaceFirst(RegExp(r'```$', multiLine: true), '')
      .trim();
  final start = cleaned.indexOf('{');
  final end = cleaned.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const FormatException('AI response did not contain JSON.');
  }
  final decoded =
      jsonDecode(cleaned.substring(start, end + 1)) as Map<String, dynamic>;
  return decoded;
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

const destinations = [
  Destination(
    'Kyoto, Japan',
    'Bustling city meets serene temples and gardens.',
    'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=900',
    ['Culture', 'Zen'],
  ),
  Destination(
    'Tokyo, Japan',
    'Neon neighborhoods, food alleys, temples, and day trips.',
    'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?q=80&w=900',
    ['Food', 'City'],
  ),
  Destination(
    'Seoul, South Korea',
    'Palaces, cafes, street markets, skincare, and late-night food.',
    'https://images.unsplash.com/photo-1538485399081-7191377e8241?q=80&w=900',
    ['Culture', 'Shopping'],
  ),
  Destination(
    'Taipei, Taiwan',
    'Night markets, mountain views, hot springs, and easy transit.',
    'https://images.unsplash.com/photo-1470004914212-05527e49370b?q=80&w=900',
    ['Food', 'Nature'],
  ),
  Destination(
    'Bangkok, Thailand',
    'Temples, river boats, markets, rooftop views, and bold food.',
    'https://images.unsplash.com/photo-1508009603885-50cf7c579365?q=80&w=900',
    ['Food', 'Culture'],
  ),
  Destination(
    'Singapore',
    'Clean transit, gardens, hawker centers, and waterfront views.',
    'https://images.unsplash.com/photo-1525625293386-3f8f99389edd?q=80&w=900',
    ['Food', 'City'],
  ),
  Destination(
    'Bali, Indonesia',
    'Beaches, rice terraces, temples, waterfalls, and slow mornings.',
    'https://images.unsplash.com/photo-1537996194471-e657df975ab4?q=80&w=900',
    ['Relax', 'Nature'],
  ),
  Destination(
    'Paris, France',
    'Museums, cafes, gardens, architecture, and classic walks.',
    'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?q=80&w=900',
    ['Museums', 'Romantic'],
  ),
  Destination(
    'London, United Kingdom',
    'Museums, markets, parks, theatre, and historic neighborhoods.',
    'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?q=80&w=900',
    ['Museums', 'City'],
  ),
  Destination(
    'New York City, USA',
    'Iconic sights, food neighborhoods, parks, museums, and shows.',
    'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?q=80&w=900',
    ['City', 'Food'],
  ),
  Destination(
    'Los Angeles, USA',
    'Beaches, studios, museums, hikes, and neighborhood food scenes.',
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?q=80&w=900',
    ['Scenic', 'City'],
  ),
  Destination(
    'Hong Kong',
    'Harbor views, dense streets, dim sum, hikes, and island escapes.',
    'https://images.unsplash.com/photo-1536599018102-9f803c140fc1?q=80&w=900',
    ['Food', 'Scenic'],
  ),
  Destination(
    'Osaka, Japan',
    'Street food, castles, shopping arcades, and easy Kansai day trips.',
    'https://images.unsplash.com/photo-1590559899731-a382839e5549?q=80&w=900',
    ['Food', 'Shopping'],
  ),
  Destination(
    'Amalfi Coast',
    'Vertical villages, cliffs, and turquoise water.',
    'https://images.unsplash.com/photo-1533929736458-ca588d08c8be?q=80&w=900',
    ['Relax', 'Scenic'],
  ),
  Destination(
    'Santorini',
    'Whitewashed homes above the caldera.',
    'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?q=80&w=900',
    ['Romantic', 'Sunset'],
  ),
];

class Destination {
  const Destination(this.name, this.description, this.image, this.tags);
  final String name;
  final String description;
  final String image;
  final List<String> tags;
}

const mockKyotoTrip = Trip(
  id: 't1',
  destination: 'Kyoto, Japan',
  startDate: '2026-04-16',
  endDate: '2026-04-27',
  budget: 3500,
  spent: 450,
  groupType: 'Friends',
  status: TripStatus.ongoing,
  currency: 'USD',
  preferences: ['Culture', 'Food', 'Walking'],
  images: [
    'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=900',
    'https://images.unsplash.com/photo-1554797589-7241bb691973?q=80&w=900',
    'https://images.unsplash.com/photo-1545569341-9eb8b30979d9?q=80&w=900',
  ],
  items: [
    ItineraryItem(
      1,
      '10:00 AM',
      'Arrive at Kyoto Station',
      Icons.train_rounded,
      0,
    ),
    ItineraryItem(
      1,
      '12:30 PM',
      'Nishiki Market Food Tour',
      Icons.restaurant_rounded,
      45,
    ),
    ItineraryItem(
      1,
      '02:00 PM',
      'Fushimi Inari-taisha Hike',
      Icons.hiking_rounded,
      0,
    ),
    ItineraryItem(
      2,
      '09:00 AM',
      'Kinkaku-ji Golden Pavilion',
      Icons.temple_buddhist_rounded,
      15,
    ),
    ItineraryItem(
      2,
      '05:30 PM',
      'Gion District Walk',
      Icons.directions_walk_rounded,
      0,
    ),
  ],
  bookings: [
    Booking(
      'JAL Flight 402',
      '2026-04-16',
      '08:30',
      'JL402-TPEKIX',
      850,
      Icons.flight_takeoff_rounded,
    ),
    Booking(
      'Kyoto Granbell Hotel',
      '2026-04-16',
      '15:00',
      'KGH-4821',
      420,
      Icons.hotel_rounded,
    ),
  ],
  checklist: [
    ChecklistCategory('Essentials', [
      'Passport',
      'Travel adapter',
      'Power bank',
    ]),
    ChecklistCategory('Clothing', [
      'Comfortable walking shoes',
      'Light rain jacket',
    ]),
  ],
  budgetCategories: [
    BudgetCategory(
      id: 'transport',
      category: 'Transport',
      planned: 1000,
      actual: 850,
    ),
    BudgetCategory(id: 'stay', category: 'Stay', planned: 900, actual: 420),
    BudgetCategory(id: 'food', category: 'Food', planned: 650, actual: 45),
    BudgetCategory(
      id: 'activities',
      category: 'Activities',
      planned: 550,
      actual: 15,
    ),
  ],
);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.account,
    required this.onComplete,
    super.key,
  });

  final AuthenticatedAccount account;
  final ValueChanged<UserProfile> onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    const tags = [
      'Culture',
      'Food',
      'Nature',
      'Shopping',
      'Museums',
      'Hidden Gems',
    ];
    return ScreenScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        children: [
          const IconBadge(icon: Icons.travel_explore_rounded, size: 64),
          const SizedBox(height: 24),
          Text(
            'Pick your travel style',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          const Text(
            'Choose the things you usually look for so routes, packing lists, and budgets start closer to your taste.',
            style: TextStyle(
              color: _secondary,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          const LabelText('Travel interests'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                ChoiceChip(
                  label: Text(tag),
                  selected: _selected.contains(tag),
                  onSelected: (_) => setState(
                    () => _selected.contains(tag)
                        ? _selected.remove(tag)
                        : _selected.add(tag),
                  ),
                  selectedColor: _accent,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide.none,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Start exploring',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => widget.onComplete(
              UserProfile(
                name: widget.account.name,
                email: widget.account.email ?? '',
                interests: _selected.toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.user,
    required this.trips,
    required this.activeTrip,
    required this.onCreate,
    required this.onOpenTrip,
    required this.onAskAi,
    required this.onOpenMap,
    required this.onOpenInfo,
    required this.onOpenTranslate,
    super.key,
  });
  final UserProfile user;
  final List<Trip> trips;
  final Trip? activeTrip;
  final VoidCallback onCreate;
  final ValueChanged<Trip> onOpenTrip;
  final ValueChanged<String> onAskAi;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenInfo;
  final VoidCallback onOpenTranslate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _query = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final trip = widget.activeTrip ?? widget.trips.first;
    return ScreenScaffold(
      bottomPadding: 92,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 112),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LabelText(_profileText(widget.user.language, 'welcome')),
                    Text(
                      '${widget.user.name.isEmpty ? 'Explorer' : widget.user.name}!',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Stack(
                children: [
                  const IconSquare(icon: Icons.notifications_none_rounded),
                  if (widget.user.notificationsEnabled)
                    const Positioned(right: 10, top: 10, child: Dot()),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SearchBox(
            controller: _query,
            hint: "Ask AI: 'Best ramen in Kyoto?'",
            onSubmit: () {
              final query = _query.text.trim();
              if (query.isNotEmpty) widget.onAskAi(query);
            },
          ),
          const SizedBox(height: 10),
          if (widget.user.notificationsEnabled) const AlertRail(),
          const SizedBox(height: 28),
          LabelText(_profileText(widget.user.language, 'currentTrip')),
          const SizedBox(height: 8),
          CurrentTripCard(trip: trip, onTap: () => widget.onOpenTrip(trip)),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              QuickAction(
                icon: Icons.info_outline_rounded,
                label: 'Info',
                onTap: widget.onOpenInfo,
              ),
              QuickAction(
                icon: Icons.map_rounded,
                label: 'Map',
                onTap: widget.onOpenMap,
              ),
              QuickAction(
                icon: Icons.translate_rounded,
                label: 'Translate',
                onTap: widget.onOpenTranslate,
              ),
              QuickAction(
                icon: Icons.auto_awesome_rounded,
                label: 'AI',
                onTap: () => widget.onAskAi('Plan my next Kyoto stop.'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SectionHeader(
            title: 'Ready for your next Adventure',
            action: 'Create',
            onTap: widget.onCreate,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: destinations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) => DestinationCard(
                destination: destinations[index],
                onTap: widget.onCreate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({
    required this.onBack,
    required this.onGenerate,
    super.key,
  });
  final VoidCallback onBack;
  final ValueChanged<Trip> onGenerate;

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _places = GeoapifyPlacesService();
  final _assistant = TravelAssistantService();
  final _destination = TextEditingController(text: 'Tokyo');
  final _budget = TextEditingController(text: '3500');
  final _chatInput = TextEditingController();
  final _customPreference = TextEditingController();
  final _airline = TextEditingController();
  final _flightConfirmation = TextEditingController();
  Timer? _searchTimer;
  PlaceSuggestion? _selectedPlace;
  List<PlaceSuggestion> _placeSuggestions = const [];
  final List<CreateTripChatMessage> _chatMessages = [];
  CreateTripDraft? _pendingDraft;
  var _group = 'Friends';
  var _currency = 'USD';
  var _mode = 0;
  String? _formError;
  var _isSearching = false;
  var _isGenerating = false;
  var _isThinking = false;
  var _usedFallbackPlan = false;
  var _pendingDraftConfirmed = false;
  DateTime _startDate = DateTime.now().add(const Duration(days: 30));
  DateTime _endDate = DateTime.now().add(const Duration(days: 35));
  String? _selectedImage;
  final Set<String> _preferences = {'Culture', 'Food'};

  static const _preferenceOptions = [
    'Culture',
    'Food',
    'Nature',
    'Shopping',
    'Relax',
    'Nightlife',
    'Museums',
    'Adventure',
    'Budget-friendly',
    'Luxury',
    'Walking',
  ];

  static const _currencyOptions = ['USD', 'TWD', 'JPY', 'EUR'];

  static const _galleryOptions = [
    'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=600',
    'https://images.unsplash.com/photo-1542051841857-5f90071e7989?q=80&w=600',
    'https://images.unsplash.com/photo-1492571350019-22de08371fd3?q=80&w=600',
    'https://images.unsplash.com/photo-1464817739973-0128fe72aa1b?q=80&w=600',
    'https://images.unsplash.com/photo-1454391304352-2bf4678b1a7a?q=80&w=600',
    'https://images.unsplash.com/photo-1533105079780-92b9be482077?q=80&w=600',
  ];

  @override
  void initState() {
    super.initState();
    _searchPlaces(_destination.text);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _destination.dispose();
    _budget.dispose();
    _chatInput.dispose();
    _customPreference.dispose();
    _airline.dispose();
    _flightConfirmation.dispose();
    super.dispose();
  }

  void _schedulePlaceSearch(String value) {
    _searchTimer?.cancel();
    setState(() {
      _selectedPlace = null;
      _formError = null;
      _isSearching = value.trim().length >= 3;
    });
    _searchTimer = Timer(
      const Duration(milliseconds: 450),
      () => _searchPlaces(value),
    );
  }

  Future<void> _searchPlaces(String value) async {
    final query = value.trim();
    if (query.length < 3) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _placeSuggestions = const [];
      });
      return;
    }

    try {
      final suggestions = await _places.searchDestinations(query);
      if (!mounted || _destination.text.trim() != query) return;
      setState(() {
        _placeSuggestions = suggestions;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _formError = 'Could not search places right now: $error';
      });
    }
  }

  void _selectPlace(PlaceSuggestion place) {
    setState(() {
      _selectedPlace = place;
      _destination.text = place.name;
      _placeSuggestions = const [];
      _formError = null;
    });
  }

  Future<void> _pickStartDate() async {
    final today = DateTime.now();
    final firstDate = DateTime(today.year, today.month, today.day);
    final initialDate = _startDate.isBefore(firstDate) ? firstDate : _startDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2028, 12, 31),
    );
    if (date == null) return;
    setState(() {
      _startDate = date;
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate.add(const Duration(days: 4));
      }
      _formError = null;
    });
  }

  Future<void> _pickEndDate() async {
    final today = DateTime.now();
    final firstDate = _startDate.isBefore(today)
        ? DateTime(today.year, today.month, today.day)
        : _startDate;
    final initialDate = _endDate.isBefore(firstDate) ? firstDate : _endDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2028, 12, 31),
    );
    if (date == null) return;
    setState(() {
      _endDate = date;
      _formError = null;
    });
  }

  void _togglePreference(String preference) {
    setState(() {
      if (_preferences.contains(preference)) {
        _preferences.remove(preference);
      } else {
        _preferences.add(preference);
      }
      _formError = null;
    });
  }

  void _addCustomPreference() {
    final tag = _customPreference.text.trim();
    if (tag.isEmpty) return;
    setState(() {
      _preferences.add(tag);
      _customPreference.clear();
      _formError = null;
    });
  }

  Future<void> _showImagePicker() async {
    final image = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: _galleryOptions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
            ),
            itemBuilder: (context, index) {
              final option = _galleryOptions[index];
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(option),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(option, fit: BoxFit.cover),
                ),
              );
            },
          ),
        ),
      ),
    );
    if (image == null) return;
    setState(() => _selectedImage = image);
  }

  void _startAiChat() {
    setState(() {
      _mode = 3;
      _formError = null;
      if (_chatMessages.isEmpty) {
        _chatMessages.add(
          const CreateTripChatMessage(
            fromUser: false,
            text:
                'Hello, where would you like to go? Pick a suggestion or describe the full trip.',
          ),
        );
      }
    });
  }

  Future<void> _sendCreateTripChat([String? value]) async {
    final text = (value ?? _chatInput.text).trim();
    if (text.isEmpty || _isThinking || _isGenerating) return;

    _chatInput.clear();

    if (_pendingDraft != null &&
        RegExp(
          r'^(confirm|confirmed|approve|approved|yes|use it|looks good)$',
          caseSensitive: false,
        ).hasMatch(text)) {
      setState(() {
        _pendingDraftConfirmed = true;
        _chatMessages.add(CreateTripChatMessage(fromUser: true, text: text));
        _chatMessages.add(
          const CreateTripChatMessage(
            fromUser: false,
            text: 'Confirmed. I will use this draft for the itinerary.',
          ),
        );
      });
      return;
    }

    setState(() {
      _isThinking = true;
      _pendingDraftConfirmed = false;
      _chatMessages.add(CreateTripChatMessage(fromUser: true, text: text));
    });

    CreateTripAiResponse aiResponse;
    try {
      aiResponse = await _assistant.createTripReply(
        message: text,
        currentDraft: _pendingDraft ?? const CreateTripDraft(),
        history: _chatMessages,
      );
    } catch (_) {
      final fallbackDraft = _parseTripDraft(text, _pendingDraft);
      final missing = _missingDraftFields(fallbackDraft);
      aiResponse = CreateTripAiResponse(
        message: missing.isEmpty
            ? 'I prepared a draft plan. Review it first, then confirm it when you are ready.'
            : _questionForMissingField(missing.first),
        draft: fallbackDraft,
        widget: _fallbackWidgetForMissingField(
          missing.isEmpty ? null : missing.first,
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _isThinking = false;
      _pendingDraft = aiResponse.draft;
      _chatMessages.add(
        CreateTripChatMessage(
          fromUser: false,
          text: aiResponse.message,
          widget: aiResponse.widget,
        ),
      );
    });
  }

  CreateTripDraft _parseTripDraft(String text, CreateTripDraft? current) {
    final lower = text.toLowerCase();
    final draft = (current ?? const CreateTripDraft()).copyWith();

    String? destination = draft.destination;
    final destinationMatch =
        RegExp(
          r'(?:to|in|for)\s+([A-Za-z][A-Za-z\s.,-]+?)(?:\s+(?:from|on|with|for|under|budget|solo|family|friends|tour)|[.!?]|$)',
          caseSensitive: false,
        ).firstMatch(text) ??
        RegExp(
          r'^(?:plan\s+)?(?:a\s+)?(?:trip\s+)?([A-Za-z][A-Za-z\s.,-]{2,50})(?:\s+\d|\s+for|\s+with|[.!?]|$)',
          caseSensitive: false,
        ).firstMatch(text);
    if (destinationMatch != null) {
      destination = destinationMatch.group(1)?.trim().replaceAll(',', '');
    }

    String? groupType = draft.groupType;
    if (lower.contains('solo')) groupType = 'Solo';
    if (lower.contains('friend')) groupType = 'Friends';
    if (lower.contains('family')) groupType = 'Family';
    if (lower.contains('tour')) groupType = 'Tour';

    String? budget = draft.budget;
    final budgetMatch = RegExp(
      r'\$\s?(\d{2,7})|(?:budget|under|around|about|usd|dollars?)\D{0,12}(\d{2,7})|(\d{2,7})\s?(?:usd|dollars?)',
      caseSensitive: false,
    ).firstMatch(text);
    budget =
        budgetMatch?.group(1) ??
        budgetMatch?.group(2) ??
        budgetMatch?.group(3) ??
        budget;

    DateTime? startDate = draft.startDate;
    DateTime? endDate = draft.endDate;
    final rangeMatch = RegExp(
      r'(\d{1,2})[\/\-.](\d{1,2})(?:[\/\-.](\d{2,4}))?\s*(?:-|to|until|through)\s*(\d{1,2})[\/\-.](\d{1,2})(?:[\/\-.](\d{2,4}))?',
      caseSensitive: false,
    ).firstMatch(text);
    if (rangeMatch != null) {
      final year = _fullYear(rangeMatch.group(3) ?? rangeMatch.group(6));
      final endYear = _fullYear(rangeMatch.group(6) ?? rangeMatch.group(3));
      startDate = DateTime(
        year,
        int.parse(rangeMatch.group(2)!),
        int.parse(rangeMatch.group(1)!),
      );
      endDate = DateTime(
        endYear,
        int.parse(rangeMatch.group(5)!),
        int.parse(rangeMatch.group(4)!),
      );
    }

    final durationMatch = RegExp(
      r'\b(\d{1,2})\s*(?:days?|nights?)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (durationMatch != null && (startDate == null || endDate == null)) {
      final duration = math.max(1, int.parse(durationMatch.group(1)!));
      final today = DateTime.now();
      startDate = lower.contains('tomorrow')
          ? today.add(const Duration(days: 1))
          : today;
      endDate = startDate.add(Duration(days: duration - 1));
    }

    final preferenceAdds = <String>{...draft.preferences};
    for (final option in _preferenceOptions) {
      if (lower.contains(option.toLowerCase())) preferenceAdds.add(option);
    }
    if (lower.contains('cheap') || lower.contains('budget')) {
      preferenceAdds.add('Budget-friendly');
    }

    return draft.copyWith(
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      budget: budget,
      groupType: groupType,
      preferences: preferenceAdds.toList(),
    );
  }

  int _fullYear(String? value) {
    final year = int.tryParse(value ?? '') ?? 2026;
    return year < 100 ? 2000 + year : year;
  }

  List<String> _missingDraftFields(CreateTripDraft draft) {
    final missing = <String>[];
    if ((draft.destination ?? '').trim().isEmpty) missing.add('destination');
    if (draft.startDate == null || draft.endDate == null) missing.add('dates');
    if ((draft.budget ?? '').trim().isEmpty) missing.add('total budget');
    if ((draft.groupType ?? '').trim().isEmpty) missing.add('who is coming');
    return missing;
  }

  String _questionForMissingField(String field) {
    switch (field) {
      case 'destination':
        return 'Where would you like to go? Pick one or type your own.';
      case 'dates':
        return 'Choose a date range, like 15/05/2026 to 20/05/2026, or say 5 days.';
      case 'total budget':
        return 'What total budget should I plan around?';
      case 'who is coming':
        return 'Who is coming with you: Solo, Friends, Family, or Tour?';
      default:
        return 'Tell me one more detail for the trip.';
    }
  }

  CreateTripChoiceWidget? _fallbackWidgetForMissingField(String? field) {
    switch (field) {
      case 'destination':
        return const CreateTripChoiceWidget(
          title: 'Popular starting points',
          options: [
            CreateTripChoiceOption(
              label: 'Kyoto',
              value: 'Kyoto, Japan',
              description: 'Culture, temples, food streets',
            ),
            CreateTripChoiceOption(
              label: 'Tokyo',
              value: 'Tokyo, Japan',
              description: 'City energy, shopping, day trips',
            ),
            CreateTripChoiceOption(
              label: 'Bali',
              value: 'Bali, Indonesia',
              description: 'Beaches, villas, relaxed pace',
            ),
          ],
        );
      case 'dates':
        return const CreateTripChoiceWidget(
          title: 'Trip length',
          options: [
            CreateTripChoiceOption(
              label: '3 days',
              value: '15/05/2026 to 17/05/2026',
              description: 'Fast weekend plan',
            ),
            CreateTripChoiceOption(
              label: '5 days',
              value: '15/05/2026 to 19/05/2026',
              description: 'Balanced pace',
            ),
            CreateTripChoiceOption(
              label: '7 days',
              value: '15/05/2026 to 21/05/2026',
              description: 'More room for day trips',
            ),
          ],
        );
      case 'total budget':
        return const CreateTripChoiceWidget(
          title: 'Total budget',
          options: [
            CreateTripChoiceOption(
              label: '\$1,500',
              value: 'budget 1500 dollars',
              description: 'Lean and efficient',
            ),
            CreateTripChoiceOption(
              label: '\$3,500',
              value: 'budget 3500 dollars',
              description: 'Comfortable mid-range',
            ),
            CreateTripChoiceOption(
              label: '\$5,000',
              value: 'budget 5000 dollars',
              description: 'More flexible picks',
            ),
          ],
        );
      case 'who is coming':
        return const CreateTripChoiceWidget(
          title: 'Travel party',
          options: [
            CreateTripChoiceOption(
              label: 'Solo',
              value: 'Solo',
              description: 'Personal route and pace',
            ),
            CreateTripChoiceOption(
              label: 'Friends',
              value: 'Friends',
              description: 'Shared plans and votes',
            ),
            CreateTripChoiceOption(
              label: 'Family',
              value: 'Family',
              description: 'Comfortable timing',
            ),
          ],
        );
      default:
        return null;
    }
  }

  void _applyDraftToForm(CreateTripDraft draft) {
    final destination = draft.destination?.trim();
    if (destination != null && destination.isNotEmpty) {
      _destination.text = destination;
      _selectedPlace = null;
    }
    final startDate = draft.startDate;
    final endDate = draft.endDate;
    if (startDate != null) _startDate = startDate;
    if (endDate != null) _endDate = endDate;
    final budget = draft.budget?.trim();
    if (budget != null && budget.isNotEmpty) _budget.text = budget;
    final groupType = draft.groupType;
    if (groupType != null && groupType.isNotEmpty) _group = groupType;
    _preferences
      ..clear()
      ..addAll(
        draft.preferences.isEmpty ? ['Culture', 'Food'] : draft.preferences,
      );
  }

  Future<void> _usePendingDraft() async {
    final draft = _pendingDraft;
    if (draft == null) return;
    final missing = _missingDraftFields(draft);
    if (missing.isNotEmpty) {
      setState(() {
        _chatMessages.add(
          CreateTripChatMessage(
            fromUser: false,
            text: _questionForMissingField(missing.first),
          ),
        );
      });
      return;
    }

    setState(() {
      _applyDraftToForm(draft);
      _mode = 1;
    });
    await _generateTrip();
  }

  Future<void> _editPendingDraft() async {
    final draft = _pendingDraft;
    if (draft == null) return;

    final destination = TextEditingController(text: draft.destination ?? '');
    final budget = TextEditingController(text: draft.budget ?? '');
    final customTag = TextEditingController();
    var startDate = draft.startDate ?? _startDate;
    var endDate = draft.endDate ?? _endDate;
    var groupType = draft.groupType ?? _group;
    final preferences = <String>{...draft.preferences};

    try {
      final edited = await showModalBottomSheet<CreateTripDraft>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> pickStart() async {
                final today = DateTime.now();
                final firstDate = DateTime(today.year, today.month, today.day);
                final date = await showDatePicker(
                  context: context,
                  initialDate: startDate.isBefore(firstDate)
                      ? firstDate
                      : startDate,
                  firstDate: firstDate,
                  lastDate: DateTime(2028, 12, 31),
                );
                if (date == null) return;
                setSheetState(() {
                  startDate = date;
                  if (endDate.isBefore(startDate)) {
                    endDate = startDate.add(const Duration(days: 4));
                  }
                });
              }

              Future<void> pickEnd() async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: endDate.isBefore(startDate)
                      ? startDate
                      : endDate,
                  firstDate: startDate,
                  lastDate: DateTime(2028, 12, 31),
                );
                if (date == null) return;
                setSheetState(() => endDate = date);
              }

              void addTag() {
                final tag = customTag.text.trim();
                if (tag.isEmpty) return;
                setSheetState(() {
                  preferences.add(tag);
                  customTag.clear();
                });
              }

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const IconBadge(
                                icon: Icons.tune_rounded,
                                size: 42,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Customize AI Draft',
                                  style: TextStyle(
                                    color: _primary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: destination,
                            decoration: const InputDecoration(
                              labelText: 'Destination',
                              prefixIcon: Icon(Icons.place_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DraftEditButton(
                                  label: 'Start',
                                  value: _dateKey(startDate),
                                  onTap: pickStart,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DraftEditButton(
                                  label: 'End',
                                  value: _dateKey(endDate),
                                  onTap: pickEnd,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: budget,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Total budget',
                              prefixText: '\$ ',
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: groupType,
                            decoration: const InputDecoration(
                              labelText: 'Who is coming',
                            ),
                            items: const ['Solo', 'Family', 'Friends', 'Tour']
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setSheetState(
                              () => groupType = value ?? groupType,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const LabelText('Trip tags'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in _preferenceOptions)
                                FilterChip(
                                  selected: preferences.contains(option),
                                  label: Text(option),
                                  onSelected: (_) => setSheetState(() {
                                    preferences.contains(option)
                                        ? preferences.remove(option)
                                        : preferences.add(option);
                                  }),
                                ),
                              for (final tag in preferences.where(
                                (tag) => !_preferenceOptions.contains(tag),
                              ))
                                InputChip(
                                  label: Text(tag),
                                  onDeleted: () => setSheetState(
                                    () => preferences.remove(tag),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: customTag,
                                  decoration: const InputDecoration(
                                    labelText: 'Add custom tag',
                                  ),
                                  onSubmitted: (_) => addTag(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  fixedSize: const Size(54, 54),
                                ),
                                onPressed: addTag,
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          PrimaryButton(
                            label: 'Save draft edits',
                            icon: Icons.check_rounded,
                            onPressed: () => Navigator.of(context).pop(
                              CreateTripDraft(
                                destination: destination.text.trim(),
                                startDate: startDate,
                                endDate: endDate,
                                budget: budget.text
                                    .replaceAll(RegExp(r'\D'), '')
                                    .trim(),
                                groupType: groupType,
                                preferences: preferences.toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (edited == null || !mounted) return;
      setState(() {
        _pendingDraft = edited;
        _pendingDraftConfirmed = false;
        _chatMessages.add(
          const CreateTripChatMessage(
            fromUser: false,
            text:
                'Draft updated. Review the custom version, then confirm it when it looks right.',
          ),
        );
      });
    } finally {
      destination.dispose();
      budget.dispose();
      customTag.dispose();
    }
  }

  Future<void> _generateTrip() async {
    final budget =
        int.tryParse(_budget.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    if (budget <= 0) {
      setState(() => _formError = 'Enter a budget greater than zero.');
      return;
    }

    final typedDestination = _destination.text.trim();
    final place =
        _selectedPlace ??
        (typedDestination.length >= 2
            ? PlaceSuggestion(
                name: typedDestination,
                formatted: typedDestination,
                latitude: 0,
                longitude: 0,
                placeId: typedDestination.toLowerCase().replaceAll(
                  RegExp(r'[^a-z0-9]+'),
                  '-',
                ),
              )
            : null);
    if (place == null) {
      setState(() {
        _formError = _mode == 1
            ? 'Choose a real destination from the search results first.'
            : 'Enter a destination.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _usedFallbackPlan = false;
      _formError = null;
    });

    GeneratedTripPlan plan;
    try {
      plan = await _assistant.generateTripPlan(
        place: place,
        startDate: _startDate,
        endDate: _endDate,
        budget: budget,
        groupType: _group,
        preferences: _preferences.toList(),
        currency: _currency,
        airline: _airline.text.trim(),
        flightConfirmation: _flightConfirmation.text.trim(),
      );
      if (plan.items.isEmpty) {
        throw Exception('AI returned no itinerary items.');
      }
    } catch (_) {
      plan = _fallbackTripPlan(
        place: place,
        startDate: _startDate,
        budget: budget,
        preferences: _preferences.toList(),
      );
      _usedFallbackPlan = true;
    }

    if (!mounted) return;
    setState(() => _isGenerating = false);

    widget.onGenerate(
      Trip(
        id: 't-${DateTime.now().millisecondsSinceEpoch}',
        destination: place.name,
        placeId: place.placeId,
        formattedAddress: place.formatted,
        latitude: place.latitude,
        longitude: place.longitude,
        startDate: _dateKey(_startDate),
        endDate: _dateKey(_endDate),
        budget: budget,
        spent: 0,
        groupType: _group,
        currency: _currency,
        status: TripStatus.upcoming,
        images: [
          if (_selectedImage != null) _selectedImage!,
          ..._imagesForDestination(place.name),
        ],
        items: plan.items,
        bookings: _bookingsWithManualDetails(plan.bookings),
        checklist: plan.checklist,
        preferences: _preferences.toList(),
        budgetCategories: _defaultBudgetCategories(
          budget: budget,
          actual: 0,
          items: plan.items,
          bookings: plan.bookings,
        ),
      ),
    );
  }

  List<Booking> _bookingsWithManualDetails(List<Booking> generated) {
    final airline = _airline.text.trim();
    final confirmation = _flightConfirmation.text.trim();
    if (airline.isEmpty && confirmation.isEmpty) return generated;
    final manualFlight = Booking(
      airline.isEmpty ? 'Flight booking' : airline,
      _dateKey(_startDate),
      'TBD',
      confirmation.isEmpty ? 'CONFIRMATION-TBD' : confirmation,
      0,
      Icons.flight_takeoff_rounded,
    );
    return [manualFlight, ...generated];
  }

  void _useTemplateTrip() {
    widget.onGenerate(
      Trip(
        id: 't-${DateTime.now().millisecondsSinceEpoch}',
        destination: mockKyotoTrip.destination,
        startDate: '2026-05-15',
        endDate: '2026-05-20',
        budget: mockKyotoTrip.budget,
        spent: 0,
        groupType: mockKyotoTrip.groupType,
        currency: mockKyotoTrip.currency,
        status: TripStatus.upcoming,
        images: mockKyotoTrip.images,
        items: mockKyotoTrip.items,
        bookings: mockKyotoTrip.bookings,
        checklist: mockKyotoTrip.checklist,
        preferences: mockKyotoTrip.preferences,
        budgetCategories: mockKyotoTrip.budgetCategories,
        placeId: mockKyotoTrip.placeId,
        formattedAddress: mockKyotoTrip.formattedAddress,
        latitude: mockKyotoTrip.latitude,
        longitude: mockKyotoTrip.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == 0) {
      return ScreenScaffold(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          children: [
            TopBar(title: 'How do you want to start?', onBack: widget.onBack),
            const SizedBox(height: 18),
            const AnimatedGlobe(),
            const SizedBox(height: 22),
            CreateOptionCard(
              icon: Icons.explore_rounded,
              title: 'Plan Step-by-Step',
              text: 'Explore ideas, compare pacing, then let AI draft it.',
              onTap: () => setState(() => _mode = 1),
            ),
            const SizedBox(height: 12),
            CreateOptionCard(
              icon: Icons.auto_awesome_rounded,
              title: 'Plan with AI',
              text: 'Search a real city, choose dates, tags, and generate.',
              onTap: _startAiChat,
            ),
            const SizedBox(height: 12),
            CreateOptionCard(
              icon: Icons.edit_note_rounded,
              title: 'Create Manually',
              text: 'Enter destination, dates, budget, people, and tags.',
              onTap: () => setState(() => _mode = 2),
            ),
            const SizedBox(height: 12),
            CreateOptionCard(
              icon: Icons.work_rounded,
              title: 'Use Saved Trip Template',
              text: 'Start from a polished Kyoto sample and edit later.',
              onTap: _useTemplateTrip,
            ),
          ],
        ),
      );
    }

    if (_mode == 3) {
      final pendingDraft = _pendingDraft;
      final canUsePlan =
          pendingDraft != null && _missingDraftFields(pendingDraft).isEmpty;
      return ScreenScaffold(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
              child: TopBar(
                title: 'Plan with AI',
                onBack: () => setState(() => _mode = 0),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
                children: [
                  if (_chatMessages.length <= 1) ...[
                    const AnimatedGlobe(),
                    const SizedBox(height: 16),
                    Text(
                      'Hello, where would you like to go?',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose guided suggestions or describe the full trip.',
                      style: TextStyle(
                        color: _secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                                'Kyoto, Japan',
                                'Tokyo, Japan',
                                'Bali, Indonesia',
                                'Paris, France',
                              ]
                              .map(
                                (prompt) => ActionChip(
                                  label: Text(prompt),
                                  onPressed: () => _sendCreateTripChat(prompt),
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                  backgroundColor: const Color(0xFFF8FAFC),
                                  side: const BorderSide(
                                    color: Color(0xFFEFF3F6),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                  for (final message in _chatMessages)
                    CreateTripChatTurn(
                      message: message,
                      onSelect: _sendCreateTripChat,
                    ),
                  if (_isThinking) const CreateTripThinkingBubble(),
                  if (pendingDraft != null && canUsePlan) ...[
                    const SizedBox(height: 12),
                    CreateTripDraftCard(
                      draft: pendingDraft,
                      confirmed: _pendingDraftConfirmed,
                      onConfirm: () => _sendCreateTripChat('confirm'),
                      onEdit: _editPendingDraft,
                      onUse: _pendingDraftConfirmed ? _usePendingDraft : null,
                      onChange: _sendCreateTripChat,
                    ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_chatMessages.length <= 1)
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            CreateTripPromptChip(
                              label: 'Kyoto',
                              prompt:
                                  'Trip to Kyoto with friends, 15/05/2026 to 20/05/2026, budget \$3500',
                              onTap: _sendCreateTripChat,
                            ),
                            CreateTripPromptChip(
                              label: 'Beach',
                              prompt:
                                  'Trip to Bali with family, 10/07/2026 to 16/07/2026, budget \$5000',
                              onTap: _sendCreateTripChat,
                            ),
                            CreateTripPromptChip(
                              label: 'Solo',
                              prompt:
                                  'Solo trip to Tokyo, 01/06/2026 to 05/06/2026, budget \$2500',
                              onTap: _sendCreateTripChat,
                            ),
                          ],
                        ),
                      ),
                    if (_chatMessages.length <= 1) const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatInput,
                            enabled: !_isThinking && !_isGenerating,
                            decoration: InputDecoration(
                              hintText: pendingDraft == null
                                  ? 'Describe the trip...'
                                  : 'Type changes or confirm...',
                            ),
                            onSubmitted: _sendCreateTripChat,
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            fixedSize: const Size(54, 54),
                          ),
                          onPressed: _isThinking || _isGenerating
                              ? null
                              : () => _sendCreateTripChat(),
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ScreenScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        children: [
          TopBar(
            title: _mode == 1 ? 'Plan with AI' : 'Create Manually',
            onBack: () => setState(() => _mode = 0),
          ),
          const SizedBox(height: 18),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 1,
                label: Text('AI Flow'),
                icon: Icon(Icons.auto_awesome_rounded),
              ),
              ButtonSegment(
                value: 2,
                label: Text('Manual'),
                icon: Icon(Icons.edit_note_rounded),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (value) => setState(() => _mode = value.first),
          ),
          const SizedBox(height: 18),
          if (_mode == 1) ...[
            const AnimatedGlobe(),
            const SizedBox(height: 14),
            const FormNotice(
              message:
                  'Tell AI the basics below. It will build stops, bookings, and a packing list.',
            ),
          ],
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _showImagePicker,
            child: SizedBox(
              height: 128,
              child: _selectedImage == null
                  ? const GlassPanel(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_rounded,
                            color: _accent,
                            size: 30,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'ADD PRIMARY PHOTO',
                            style: TextStyle(
                              color: _secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(_selectedImage!, fit: BoxFit.cover),
                          Container(color: Colors.black.withValues(alpha: .18)),
                          const Center(
                            child: Icon(
                              Icons.add_photo_alternate_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _destination,
            onChanged: _schedulePlaceSearch,
            decoration: InputDecoration(
              labelText: 'Destination',
              hintText: 'Search a real city',
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.travel_explore_rounded),
            ),
          ),
          if (_selectedPlace != null) ...[
            const SizedBox(height: 10),
            SelectedPlaceCard(place: _selectedPlace!),
          ] else if (_placeSuggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            PlaceSuggestionList(
              suggestions: _placeSuggestions,
              onSelect: _selectPlace,
            ),
          ],
          const SizedBox(height: 12),
          DateRangeCard(
            startDate: _startDate,
            endDate: _endDate,
            onPickStart: _pickStartDate,
            onPickEnd: _pickEndDate,
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: _currencyOptions
                .map(
                  (currency) =>
                      ButtonSegment(value: currency, label: Text(currency)),
                )
                .toList(),
            selected: {_currency},
            onSelectionChanged: (value) =>
                setState(() => _currency = value.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _budget,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Total budget',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _group,
            decoration: const InputDecoration(labelText: 'Who is coming'),
            items: const ['Solo', 'Family', 'Friends', 'Tour']
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) => setState(() => _group = value ?? _group),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _airline,
                  decoration: const InputDecoration(
                    labelText: 'Airline optional',
                    prefixIcon: Icon(Icons.flight_takeoff_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _flightConfirmation,
                  decoration: const InputDecoration(
                    labelText: 'Confirmation',
                    prefixIcon: Icon(Icons.confirmation_number_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _preferenceOptions.map((preference) {
              final selected = _preferences.contains(preference);
              return FilterChip(
                selected: selected,
                label: Text(preference),
                onSelected: (_) => _togglePreference(preference),
                selectedColor: _accent.withValues(alpha: .35),
                checkmarkColor: _primary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customPreference,
                  decoration: const InputDecoration(
                    labelText: 'Add custom tag',
                    hintText: 'e.g. anime, halal food, wheelchair access',
                  ),
                  onSubmitted: (_) => _addCustomPreference(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(54, 54),
                ),
                onPressed: _addCustomPreference,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const PlanningIdeaStrip(),
          if (_usedFallbackPlan) ...[
            const SizedBox(height: 16),
            const FormNotice(
              message:
                  'AI generation was unavailable, so a local draft plan was created.',
            ),
          ],
          if (_formError != null) ...[
            const SizedBox(height: 16),
            FormNotice(message: _formError!),
          ],
          const SizedBox(height: 24),
          if (_isGenerating)
            const GeneratingTripPanel()
          else
            PrimaryButton(
              label: _mode == 1 ? 'Generate with AI' : 'Create itinerary',
              icon: _mode == 1
                  ? Icons.auto_awesome_rounded
                  : Icons.arrow_forward_rounded,
              onPressed: _generateTrip,
            ),
        ],
      ),
    );
  }
}

class CreateOptionCard extends StatelessWidget {
  const CreateOptionCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        child: Row(
          children: [
            IconBadge(icon: icon, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      color: _secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: _secondary),
          ],
        ),
      ),
    );
  }
}

class CreateTripDraft {
  const CreateTripDraft({
    this.destination,
    this.startDate,
    this.endDate,
    this.budget,
    this.groupType,
    this.preferences = const [],
  });

  final String? destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? budget;
  final String? groupType;
  final List<String> preferences;

  CreateTripDraft copyWith({
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    String? budget,
    String? groupType,
    List<String>? preferences,
  }) {
    return CreateTripDraft(
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
      groupType: groupType ?? this.groupType,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, dynamic> toAiMap() => {
    'destination': destination,
    'startDate': startDate == null ? null : _dateKey(startDate!),
    'endDate': endDate == null ? null : _dateKey(endDate!),
    'budget': budget,
    'groupType': groupType,
    'preferences': preferences,
  };

  static CreateTripDraft fromAiMap(
    Map<String, dynamic> map, {
    required CreateTripDraft fallback,
  }) {
    return fallback.copyWith(
      destination: _nonEmptyString(map['destination']) ?? fallback.destination,
      startDate: _parseIsoDate(map['startDate']) ?? fallback.startDate,
      endDate: _parseIsoDate(map['endDate']) ?? fallback.endDate,
      budget: _nonEmptyString(map['budget']) ?? fallback.budget,
      groupType: _normalGroupType(map['groupType']) ?? fallback.groupType,
      preferences: ((map['preferences'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .where((item) => item.trim().isNotEmpty)
          .toList(),
    );
  }
}

class CreateTripChatMessage {
  const CreateTripChatMessage({
    required this.fromUser,
    required this.text,
    this.widget,
  });

  final bool fromUser;
  final String text;
  final CreateTripChoiceWidget? widget;
}

class CreateTripAiResponse {
  const CreateTripAiResponse({
    required this.message,
    required this.draft,
    this.widget,
  });

  final String message;
  final CreateTripDraft draft;
  final CreateTripChoiceWidget? widget;

  static CreateTripAiResponse fromMap(
    Map<String, dynamic> map, {
    required CreateTripDraft fallbackDraft,
  }) {
    final draftMap = map['draft'] is Map
        ? Map<String, dynamic>.from(map['draft'] as Map)
        : const <String, dynamic>{};
    return CreateTripAiResponse(
      message: (map['message'] as String?)?.trim().isNotEmpty == true
          ? (map['message'] as String).trim()
          : 'I updated the trip draft.',
      draft: CreateTripDraft.fromAiMap(draftMap, fallback: fallbackDraft),
      widget: CreateTripChoiceWidget.fromMap(map['widget']),
    );
  }
}

class CreateTripChoiceWidget {
  const CreateTripChoiceWidget({required this.title, required this.options});

  final String title;
  final List<CreateTripChoiceOption> options;

  static CreateTripChoiceWidget? fromMap(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final options = ((map['options'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((item) => CreateTripChoiceOption.fromMap(item))
        .whereType<CreateTripChoiceOption>()
        .take(4)
        .toList();
    if (options.isEmpty) return null;
    return CreateTripChoiceWidget(
      title: (map['title'] as String?)?.trim().isNotEmpty == true
          ? (map['title'] as String).trim()
          : 'Choose an option',
      options: options,
    );
  }
}

class CreateTripChoiceOption {
  const CreateTripChoiceOption({
    required this.label,
    required this.value,
    required this.description,
  });

  final String label;
  final String value;
  final String description;

  static CreateTripChoiceOption? fromMap(Map<dynamic, dynamic> map) {
    final label = _nonEmptyString(map['label']);
    final value = _nonEmptyString(map['value']);
    if (label == null || value == null) return null;
    return CreateTripChoiceOption(
      label: label,
      value: value,
      description: _nonEmptyString(map['description']) ?? '',
    );
  }
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _parseIsoDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim());
}

String? _normalGroupType(Object? value) {
  final text = _nonEmptyString(value)?.toLowerCase();
  if (text == null) return null;
  if (text.contains('solo')) return 'Solo';
  if (text.contains('family')) return 'Family';
  if (text.contains('tour')) return 'Tour';
  if (text.contains('friend')) return 'Friends';
  return null;
}

class CreateTripChatTurn extends StatelessWidget {
  const CreateTripChatTurn({
    required this.message,
    required this.onSelect,
    super.key,
  });

  final CreateTripChatMessage message;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: message.fromUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        CreateTripChatBubble(message: message),
        if (!message.fromUser && message.widget != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CreateTripChoicePanel(
              widget: message.widget!,
              onSelect: onSelect,
            ),
          ),
      ],
    );
  }
}

class CreateTripChatBubble extends StatelessWidget {
  const CreateTripChatBubble({required this.message, super.key});
  final CreateTripChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: message.fromUser ? _primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(message.fromUser ? 22 : 6),
            topRight: Radius.circular(message.fromUser ? 6 : 22),
            bottomLeft: const Radius.circular(22),
            bottomRight: const Radius.circular(22),
          ),
          border: message.fromUser
              ? null
              : Border.all(color: const Color(0xFFEFF3F6)),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.fromUser ? Colors.white : _primary,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class CreateTripThinkingBubble extends StatelessWidget {
  const CreateTripThinkingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: GlassPanel(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Thinking...', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class CreateTripChoicePanel extends StatelessWidget {
  const CreateTripChoicePanel({
    required this.widget,
    required this.onSelect,
    super.key,
  });

  final CreateTripChoiceWidget widget;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: _primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (final option in widget.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelect(option.value),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEFF3F6)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.label,
                              style: const TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (option.description.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                option.description,
                                style: const TextStyle(
                                  color: _secondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: _secondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CreateTripDraftCard extends StatelessWidget {
  const CreateTripDraftCard({
    required this.draft,
    required this.confirmed,
    required this.onConfirm,
    required this.onChange,
    required this.onEdit,
    this.onUse,
    super.key,
  });

  final CreateTripDraft draft;
  final bool confirmed;
  final VoidCallback onConfirm;
  final ValueChanged<String> onChange;
  final VoidCallback onEdit;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.auto_awesome_rounded, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LabelText('AI Prepared'),
                    Text(
                      draft.destination ?? 'New trip',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SmallPill(label: confirmed ? 'Confirmed' : 'Review'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DraftStat(
                  label: 'Dates',
                  value: draft.startDate == null || draft.endDate == null
                      ? 'TBD'
                      : '${_dateKey(draft.startDate!)} / ${_dateKey(draft.endDate!)}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DraftStat(
                  label: 'Budget',
                  value: draft.budget == null ? 'TBD' : '\$${draft.budget}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DraftStat(
                  label: 'Party',
                  value: draft.groupType ?? 'TBD',
                ),
              ),
            ],
          ),
          if (draft.preferences.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: draft.preferences
                  .map((item) => SmallPill(label: item))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                CreateTripPromptChip(
                  label: 'Cheaper',
                  prompt: 'Make it cheaper',
                  onTap: onChange,
                ),
                CreateTripPromptChip(
                  label: 'More food',
                  prompt: 'Add more food',
                  onTap: onChange,
                ),
                CreateTripPromptChip(
                  label: 'Slower',
                  prompt: 'Slow the pace',
                  onTap: onChange,
                ),
                CreateTripPromptChip(
                  label: 'Nature',
                  prompt: 'More nature',
                  onTap: onChange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onEdit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF8FAFC),
                    foregroundColor: _primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('CUSTOMIZE'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: confirmed ? _accent : _primary,
                    foregroundColor: confirmed ? _primary : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(confirmed ? 'CONFIRMED' : 'CONFIRM'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onUse,
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: Color(0xFFEFF3F6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('USE CUSTOMIZED PLAN'),
          ),
        ],
      ),
    );
  }
}

class DraftEditButton extends StatelessWidget {
  const DraftEditButton({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEFF3F6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: _secondary,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: _primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DraftStat extends StatelessWidget {
  const DraftStat({required this.label, required this.value, super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _secondary,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class CreateTripPromptChip extends StatelessWidget {
  const CreateTripPromptChip({
    required this.label,
    required this.prompt,
    required this.onTap,
    super.key,
  });

  final String label;
  final String prompt;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: () => onTap(prompt),
        labelStyle: const TextStyle(fontWeight: FontWeight.w900),
        backgroundColor: const Color(0xFFF8FAFC),
        side: const BorderSide(color: Color(0xFFEFF3F6)),
      ),
    );
  }
}

GeneratedTripPlan _fallbackTripPlan({
  required PlaceSuggestion place,
  required DateTime startDate,
  required int budget,
  required List<String> preferences,
}) {
  final placeName = place.name.split(',').first;
  final wantsFood = preferences.any(
    (item) => item.toLowerCase().contains('food'),
  );
  final wantsNature = preferences.any(
    (item) =>
        item.toLowerCase().contains('nature') ||
        item.toLowerCase().contains('adventure'),
  );
  final wantsShopping = preferences.any(
    (item) => item.toLowerCase().contains('shopping'),
  );

  final items = [
    ItineraryItem(
      1,
      '09:30 AM',
      '$placeName arrival and neighborhood orientation',
      Icons.directions_walk_rounded,
      0,
    ),
    ItineraryItem(
      1,
      '12:30 PM',
      wantsFood ? '$placeName local food crawl' : 'Central cafe lunch stop',
      wantsFood ? Icons.restaurant_rounded : Icons.local_cafe_rounded,
      (budget * .03).round(),
    ),
    ItineraryItem(
      1,
      '03:00 PM',
      wantsShopping
          ? 'Market and boutique shopping route'
          : 'Historic district walk',
      wantsShopping ? Icons.shopping_bag_rounded : Icons.museum_rounded,
      (budget * .02).round(),
    ),
    ItineraryItem(
      2,
      '09:00 AM',
      wantsNature
          ? 'Scenic outdoor viewpoint and easy trail'
          : 'Signature landmark visit',
      wantsNature ? Icons.hiking_rounded : Icons.place_rounded,
      (budget * .02).round(),
    ),
    ItineraryItem(
      2,
      '06:00 PM',
      '$placeName evening dinner plan',
      Icons.restaurant_rounded,
      (budget * .04).round(),
    ),
  ];

  final bookings = [
    Booking(
      '$placeName stay placeholder',
      _dateKey(startDate),
      '15:00',
      'HOTEL-TBD',
      (budget * .28).round(),
      Icons.hotel_rounded,
    ),
    Booking(
      '$placeName transport placeholder',
      _dateKey(startDate),
      '09:00',
      'TRANSIT-TBD',
      (budget * .12).round(),
      Icons.train_rounded,
    ),
  ];

  final checklist = [
    const ChecklistCategory('Essentials', [
      'Passport or ID',
      'Wallet and payment cards',
      'Phone charger',
      'Travel adapter',
    ]),
    ChecklistCategory('Trip Style', [
      if (wantsNature) 'Comfortable walking shoes',
      if (wantsFood) 'Restaurant reservation notes',
      if (wantsShopping) 'Extra tote bag',
      'Reusable water bottle',
    ]),
  ];

  return GeneratedTripPlan(
    items: items,
    bookings: bookings,
    checklist: checklist,
  );
}

List<String> _imagesForDestination(String destination) {
  final lower = destination.toLowerCase();
  for (final option in destinations) {
    final optionName = option.name.toLowerCase();
    if (lower.contains(optionName.split(',').first) ||
        optionName.contains(lower.split(',').first)) {
      return [option.image, ...mockKyotoTrip.images.take(2)];
    }
  }
  return mockKyotoTrip.images;
}

List<BudgetCategory> _defaultBudgetCategories({
  required int budget,
  required int actual,
  required List<ItineraryItem> items,
  required List<Booking> bookings,
}) {
  final bookingCost = bookings.fold<int>(0, (total, item) => total + item.cost);
  final activityCost = items.fold<int>(0, (total, item) => total + item.cost);
  final transportCost = bookings
      .where(
        (item) =>
            item.icon == Icons.flight_takeoff_rounded ||
            item.icon == Icons.train_rounded,
      )
      .fold<int>(0, (total, item) => total + item.cost);
  final stayCost = bookings
      .where((item) => item.icon == Icons.hotel_rounded)
      .fold<int>(0, (total, item) => total + item.cost);
  final foodCost = items
      .where((item) => item.type == Icons.restaurant_rounded)
      .fold<int>(0, (total, item) => total + item.cost);
  final fallback = math.max(0, budget - transportCost - stayCost - foodCost);

  return [
    BudgetCategory(
      id: 'transport',
      category: 'Transport',
      planned: math.max(transportCost, (budget * .25).round()),
      actual: transportCost,
    ),
    BudgetCategory(
      id: 'stay',
      category: 'Stay',
      planned: math.max(stayCost, (budget * .28).round()),
      actual: stayCost,
    ),
    BudgetCategory(
      id: 'food',
      category: 'Food',
      planned: math.max(foodCost, (budget * .18).round()),
      actual: foodCost,
    ),
    BudgetCategory(
      id: 'activities',
      category: 'Activities',
      planned: math.max(activityCost, fallback ~/ 2),
      actual: math.max(0, activityCost - foodCost),
    ),
    BudgetCategory(
      id: 'other',
      category: 'Other',
      planned: math.max(0, budget ~/ 10),
      actual: math.max(0, actual - bookingCost - activityCost),
    ),
  ];
}

class ItineraryScreen extends StatelessWidget {
  const ItineraryScreen({
    required this.trip,
    required this.onBack,
    required this.onOpenChat,
    required this.onOpenBudget,
    required this.onOpenPacking,
    required this.onOpenMap,
    required this.onUpdateTrip,
    super.key,
  });
  final Trip trip;
  final VoidCallback onBack;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenBudget;
  final VoidCallback onOpenPacking;
  final VoidCallback onOpenMap;
  final ValueChanged<Trip> onUpdateTrip;

  @override
  Widget build(BuildContext context) {
    return _EditableItineraryScreen(
      trip: trip,
      onBack: onBack,
      onOpenChat: onOpenChat,
      onOpenMap: onOpenMap,
      onUpdateTrip: onUpdateTrip,
    );
  }
}

class _EditableItineraryScreen extends StatefulWidget {
  const _EditableItineraryScreen({
    required this.trip,
    required this.onBack,
    required this.onOpenChat,
    required this.onOpenMap,
    required this.onUpdateTrip,
  });

  final Trip trip;
  final VoidCallback onBack;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenMap;
  final ValueChanged<Trip> onUpdateTrip;

  @override
  State<_EditableItineraryScreen> createState() =>
      _EditableItineraryScreenState();
}

class _EditableItineraryScreenState extends State<_EditableItineraryScreen> {
  late Trip _trip;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
  }

  @override
  void didUpdateWidget(covariant _EditableItineraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trip.id != oldWidget.trip.id || widget.trip != oldWidget.trip) {
      _trip = widget.trip;
    }
  }

  void _save(Trip trip) {
    setState(() => _trip = trip);
    widget.onUpdateTrip(trip);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: ScreenScaffold(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
              child: TopBar(title: _trip.destination, onBack: widget.onBack),
            ),
            SizedBox(height: 190, child: HeroTripCard(trip: _trip)),
            const SizedBox(height: 8),
            const SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: _primary,
                unselectedLabelColor: _secondary,
                indicatorColor: _accent,
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Itinerary'),
                  Tab(text: 'Budget'),
                  Tab(text: 'Map'),
                  Tab(text: 'Checklist'),
                  Tab(text: 'Booking'),
                  Tab(text: 'Chat'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  TripOverviewTab(trip: _trip),
                  EditableItineraryTab(trip: _trip, onSave: _save),
                  EditableBudgetTab(trip: _trip, onSave: _save),
                  TripMapTab(trip: _trip, onOpenMap: widget.onOpenMap),
                  EditableChecklistTab(trip: _trip, onSave: _save),
                  EditableBookingTab(trip: _trip, onSave: _save),
                  TripChatTab(trip: _trip, onOpenChat: widget.onOpenChat),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TripOverviewTab extends StatelessWidget {
  const TripOverviewTab({required this.trip, super.key});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final categories = trip.budgetCategories.isEmpty
        ? _defaultBudgetCategories(
            budget: trip.budget,
            actual: trip.spent,
            items: trip.items,
            bookings: trip.bookings,
          )
        : trip.budgetCategories;
    final actual = categories.fold<int>(
      0,
      (total, item) => total + item.actual,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Dates',
                value: trip.startDate,
                detail: trip.endDate,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                title: 'Budget',
                value: '${trip.currency} $actual',
                detail: 'of ${trip.currency} ${trip.budget}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelText('Trip tags'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    (trip.preferences.isEmpty
                            ? ['Culture', 'Food']
                            : trip.preferences)
                        .map((tag) => SmallPill(label: tag))
                        .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader(title: 'Bookings'),
        const SizedBox(height: 10),
        for (final booking in trip.bookings.take(2))
          BookingTile(booking: booking),
        const SizedBox(height: 12),
        const SectionHeader(title: 'First stops'),
        const SizedBox(height: 10),
        for (final item in trip.items.take(3)) ItineraryTile(item: item),
      ],
    );
  }
}

class EditableItineraryTab extends StatelessWidget {
  const EditableItineraryTab({
    required this.trip,
    required this.onSave,
    super.key,
  });

  final Trip trip;
  final ValueChanged<Trip> onSave;

  Future<void> _addStop(BuildContext context) async {
    final activity = TextEditingController();
    final time = TextEditingController(text: '10:00 AM');
    final cost = TextEditingController(text: '0');
    var day = 1;
    try {
      final item = await showDialog<ItineraryItem>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add stop'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: activity,
                  decoration: const InputDecoration(labelText: 'Activity'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: time,
                  decoration: const InputDecoration(labelText: 'Time'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: cost,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cost'),
                ),
                const SizedBox(height: 10),
                StepperControl(
                  label: 'Day $day',
                  onMinus: () =>
                      setDialogState(() => day = math.max(1, day - 1)),
                  onPlus: () => setDialogState(() => day += 1),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  ItineraryItem(
                    day,
                    time.text.trim().isEmpty ? '10:00 AM' : time.text.trim(),
                    activity.text.trim().isEmpty
                        ? 'New activity'
                        : activity.text.trim(),
                    Icons.place_rounded,
                    int.tryParse(cost.text.replaceAll(RegExp(r'\D'), '')) ?? 0,
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      );
      if (item == null) return;
      onSave(trip.copyWith(items: [...trip.items, item]));
    } finally {
      activity.dispose();
      time.dispose();
      cost.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<ItineraryItem>>{};
    for (final item in trip.items) {
      grouped.putIfAbsent(item.day, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        PrimaryButton(
          label: 'Add stop',
          icon: Icons.add_rounded,
          onPressed: () => _addStop(context),
        ),
        const SizedBox(height: 16),
        for (final day in grouped.keys.toList()..sort()) ...[
          LabelText('Day $day'),
          const SizedBox(height: 10),
          for (final item in grouped[day]!)
            Dismissible(
              key: ValueKey('${item.day}-${item.time}-${item.activity}'),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.only(bottom: 10),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.red),
              ),
              onDismissed: (_) => onSave(
                trip.copyWith(
                  items: trip.items
                      .where((candidate) => candidate != item)
                      .toList(),
                ),
              ),
              child: ItineraryTile(item: item),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class EditableBudgetTab extends StatelessWidget {
  const EditableBudgetTab({
    required this.trip,
    required this.onSave,
    super.key,
  });
  final Trip trip;
  final ValueChanged<Trip> onSave;

  @override
  Widget build(BuildContext context) {
    final categories = trip.budgetCategories.isEmpty
        ? _defaultBudgetCategories(
            budget: trip.budget,
            actual: trip.spent,
            items: trip.items,
            bookings: trip.bookings,
          )
        : trip.budgetCategories;
    final actual = categories.fold<int>(
      0,
      (total, item) => total + item.actual,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelText('Budget'),
              const SizedBox(height: 8),
              Text(
                '${trip.currency} $actual of ${trip.currency} ${trip.budget}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: trip.budget == 0
                      ? 0
                      : (actual / trip.budget).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: _secondary.withValues(alpha: .16),
                  color: _secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final category in categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: BudgetCategoryEditor(
              category: category,
              currency: trip.currency,
              onChanged: (updated) {
                final next = categories
                    .map((item) => item.id == updated.id ? updated : item)
                    .toList();
                onSave(
                  trip.copyWith(
                    budgetCategories: next,
                    spent: next.fold<int>(
                      0,
                      (total, item) => total + item.actual,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class TripMapTab extends StatelessWidget {
  const TripMapTab({required this.trip, required this.onOpenMap, super.key});
  final Trip trip;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelText('Route map'),
              const SizedBox(height: 8),
              Text(
                trip.formattedAddress ?? trip.destination,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Open map',
                icon: Icons.map_rounded,
                onPressed: onOpenMap,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final item in trip.items.take(6)) ItineraryTile(item: item),
      ],
    );
  }
}

class EditableChecklistTab extends StatelessWidget {
  const EditableChecklistTab({
    required this.trip,
    required this.onSave,
    super.key,
  });
  final Trip trip;
  final ValueChanged<Trip> onSave;

  Future<void> _addItem(
    BuildContext context,
    ChecklistCategory category,
  ) async {
    final controller = TextEditingController();
    try {
      final item = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Add to ${category.category}'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Checklist item'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      if (item == null || item.isEmpty) return;
      final next = trip.checklist
          .map(
            (candidate) => candidate == category
                ? ChecklistCategory(candidate.category, [
                    ...candidate.items,
                    item,
                  ])
                : candidate,
          )
          .toList();
      onSave(trip.copyWith(checklist: next));
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        for (final category in trip.checklist)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.category,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _addItem(context, category),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  for (final item in category.items)
                    CheckboxListTile(
                      dense: true,
                      value: false,
                      onChanged: (_) {},
                      title: Text(item),
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () {
                          final next = trip.checklist
                              .map(
                                (candidate) => candidate == category
                                    ? ChecklistCategory(
                                        candidate.category,
                                        candidate.items
                                            .where((value) => value != item)
                                            .toList(),
                                      )
                                    : candidate,
                              )
                              .toList();
                          onSave(trip.copyWith(checklist: next));
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class EditableBookingTab extends StatelessWidget {
  const EditableBookingTab({
    required this.trip,
    required this.onSave,
    super.key,
  });
  final Trip trip;
  final ValueChanged<Trip> onSave;

  Future<void> _addBooking(BuildContext context) async {
    final title = TextEditingController();
    final date = TextEditingController(text: trip.startDate);
    final time = TextEditingController(text: '10:00');
    final reference = TextEditingController(text: 'TBD');
    final cost = TextEditingController(text: '0');
    try {
      final booking = await showDialog<Booking>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add booking'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: date,
                  decoration: const InputDecoration(labelText: 'Date'),
                ),
                TextField(
                  controller: time,
                  decoration: const InputDecoration(labelText: 'Time'),
                ),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(labelText: 'Reference'),
                ),
                TextField(
                  controller: cost,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cost'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                Booking(
                  title.text.trim().isEmpty ? 'New booking' : title.text.trim(),
                  date.text.trim(),
                  time.text.trim(),
                  reference.text.trim(),
                  int.tryParse(cost.text.replaceAll(RegExp(r'\D'), '')) ?? 0,
                  Icons.confirmation_number_rounded,
                ),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      if (booking == null) return;
      onSave(trip.copyWith(bookings: [...trip.bookings, booking]));
    } finally {
      title.dispose();
      date.dispose();
      time.dispose();
      reference.dispose();
      cost.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        PrimaryButton(
          label: 'Add booking',
          icon: Icons.add_rounded,
          onPressed: () => _addBooking(context),
        ),
        const SizedBox(height: 16),
        for (final booking in trip.bookings)
          Dismissible(
            key: ValueKey('${booking.title}-${booking.reference}'),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: 10),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.delete_rounded, color: Colors.red),
            ),
            onDismissed: (_) => onSave(
              trip.copyWith(
                bookings: trip.bookings
                    .where((candidate) => candidate != booking)
                    .toList(),
              ),
            ),
            child: BookingTile(booking: booking),
          ),
      ],
    );
  }
}

class TripChatTab extends StatelessWidget {
  const TripChatTab({required this.trip, required this.onOpenChat, super.key});
  final Trip trip;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        GlassPanel(
          child: Column(
            children: [
              const IconBadge(icon: Icons.chat_bubble_rounded, size: 54),
              const SizedBox(height: 12),
              Text(
                '${trip.destination} AI',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ask for route changes, cheaper options, packing help, or booking reminders.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Open chat',
                icon: Icons.arrow_forward_rounded,
                onPressed: onOpenChat,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StepperControl extends StatelessWidget {
  const StepperControl({
    required this.label,
    required this.onMinus,
    required this.onPlus,
    super.key,
  });
  final String label;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_rounded)),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(onPressed: onPlus, icon: const Icon(Icons.add_rounded)),
      ],
    );
  }
}

class BudgetCategoryEditor extends StatelessWidget {
  const BudgetCategoryEditor({
    required this.category,
    required this.currency,
    required this.onChanged,
    super.key,
  });
  final BudgetCategory category;
  final String currency;
  final ValueChanged<BudgetCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final planned = TextEditingController(text: category.planned.toString());
    final actual = TextEditingController(text: category.actual.toString());
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.category,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: planned,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Planned $currency'),
                  onSubmitted: (_) => onChanged(
                    category.copyWith(
                      planned:
                          int.tryParse(
                            planned.text.replaceAll(RegExp(r'\D'), ''),
                          ) ??
                          category.planned,
                      actual:
                          int.tryParse(
                            actual.text.replaceAll(RegExp(r'\D'), ''),
                          ) ??
                          category.actual,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: actual,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Actual $currency'),
                  onSubmitted: (_) => onChanged(
                    category.copyWith(
                      planned:
                          int.tryParse(
                            planned.text.replaceAll(RegExp(r'\D'), ''),
                          ) ??
                          category.planned,
                      actual:
                          int.tryParse(
                            actual.text.replaceAll(RegExp(r'\D'), ''),
                          ) ??
                          category.actual,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TripsScreen extends StatelessWidget {
  const TripsScreen({
    required this.trips,
    required this.onBack,
    required this.onCreate,
    required this.onOpenTrip,
    required this.onStartTrip,
    super.key,
  });
  final List<Trip> trips;
  final VoidCallback onBack;
  final VoidCallback onCreate;
  final ValueChanged<Trip> onOpenTrip;
  final ValueChanged<Trip> onStartTrip;

  @override
  Widget build(BuildContext context) {
    final items = trips.isEmpty ? [mockKyotoTrip] : trips;
    return ScreenScaffold(
      bottomPadding: 92,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 112),
        children: [
          TopBar(
            title: 'Trips',
            onBack: onBack,
            action: Icons.add_rounded,
            onAction: onCreate,
          ),
          const SizedBox(height: 18),
          for (final trip in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TripListCard(
                trip: trip,
                onTap: () => onOpenTrip(trip),
                onStart: () => onStartTrip(trip),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({required this.trips, required this.onOpen, super.key});
  final List<Trip> trips;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      bottomPadding: 92,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 112),
        children: [
          Text(
            'Chat',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          ChatPreview(
            icon: Icons.auto_awesome_rounded,
            title: 'AI Travel Agent',
            text: 'Ask for routes, food, bookings, packing, or swaps.',
            onTap: () => onOpen('What should I do next in Kyoto?'),
          ),
          ChatPreview(
            icon: Icons.groups_rounded,
            title: 'Kyoto Group',
            text: 'Vote on lunch and share plan changes with friends.',
            onTap: () => onOpen('Start a group vote for lunch.'),
          ),
        ],
      ),
    );
  }
}

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    required this.initialQuery,
    required this.onBack,
    super.key,
  });
  final String initialQuery;
  final VoidCallback onBack;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  late final List<ChatMessageModel> _messages;
  final _assistant = TravelAssistantService();
  final _input = TextEditingController();
  var _isSending = false;

  @override
  void initState() {
    super.initState();
    _messages = [
      const ChatMessageModel(
        false,
        "AI Agent active. I can optimize routes, compare ideas, and turn chat into itinerary changes.",
      ),
      if (widget.initialQuery.isNotEmpty)
        ChatMessageModel(true, widget.initialQuery),
    ];
    if (widget.initialQuery.isNotEmpty) {
      unawaited(_sendToAssistant(widget.initialQuery, addUserMessage: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
            child: TopBar(title: 'AI Travel Agent', onBack: widget.onBack),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  MessageBubble(message: _messages[index]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: const InputDecoration(
                      hintText: 'Ask about Kyoto, budgets, packing...',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(54, 54),
                  ),
                  onPressed: _isSending
                      ? null
                      : () {
                          final text = _input.text.trim();
                          if (text.isEmpty) return;
                          _input.clear();
                          unawaited(_sendToAssistant(text));
                        },
                  icon: _isSending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendToAssistant(
    String text, {
    bool addUserMessage = true,
  }) async {
    setState(() {
      if (addUserMessage) _messages.add(ChatMessageModel(true, text));
      _isSending = true;
    });

    try {
      final reply = await _assistant.sendMessage(text);
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessageModel(
            false,
            reply.isEmpty
                ? 'I could not generate a travel suggestion right now.'
                : reply,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const ChatMessageModel(
            false,
            'AI chat is unavailable right now. Please try again in a moment.',
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

class ChatMessageModel {
  const ChatMessageModel(this.fromUser, this.text);
  final bool fromUser;
  final String text;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.account,
    required this.user,
    required this.onSave,
    required this.onSignOut,
    required this.onDeleteAccount,
    super.key,
  });

  final AuthenticatedAccount account;
  final UserProfile user;
  final ValueChanged<UserProfile> onSave;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onDeleteAccount;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.user.name,
  );

  var _isSigningOut = false;
  var _isDeleting = false;
  late final Set<String> _interests = {...widget.user.interests};
  late var _language = widget.user.language;
  late var _notificationsEnabled = widget.user.notificationsEnabled;
  late var _themeMode = widget.user.themeMode;
  final _customInterest = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _customInterest.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    await widget.onSignOut();
  }

  UserProfile _draftProfile() => UserProfile(
    name: _name.text,
    email: widget.account.email ?? widget.user.email,
    interests: _interests.toList(),
    language: _language,
    notificationsEnabled: _notificationsEnabled,
    themeMode: _themeMode,
  );

  void _saveDraft() => widget.onSave(_draftProfile());

  Future<void> _editInterests() async {
    final draft = {..._interests};
    String? interestError;
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Travel interests',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in const [
                      'Culture',
                      'Food',
                      'Nature',
                      'Shopping',
                      'Museums',
                      'Hidden Gems',
                    ])
                      ChoiceChip(
                        label: Text(tag),
                        selected: draft.contains(tag),
                        selectedColor: _accent,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                        onSelected: (_) => setSheetState(
                          () => draft.contains(tag)
                              ? draft.remove(tag)
                              : draft.add(tag),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customInterest,
                        decoration: InputDecoration(
                          labelText: _profileText(_language, 'customInterest'),
                          errorText: interestError,
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addCustomInterest(
                          draft,
                          setSheetState,
                          (message) => interestError = message,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: _profileText(_language, 'customInterest'),
                      onPressed: () => _addCustomInterest(
                        draft,
                        setSheetState,
                        (message) => interestError = message,
                      ),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: _profileText(_language, 'saveInterests'),
                  icon: Icons.check_rounded,
                  onPressed: () => Navigator.of(context).pop(draft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _interests
          ..clear()
          ..addAll(selected);
      });
      _saveDraft();
    }
  }

  void _addCustomInterest(
    Set<String> draft,
    void Function(void Function()) setSheetState,
    ValueChanged<String?> setError,
  ) {
    final interest = _cleanInterest(_customInterest.text);
    setSheetState(() {
      if (interest == null || _isBlockedInterest(interest)) {
        setError(_profileText(_language, 'interestBlocked'));
        return;
      }
      setError(null);
      draft.add(interest);
      _customInterest.clear();
    });
  }

  void _pickLanguage() {
    _showSettingPicker<String>(
      title: _profileText(_language, 'language'),
      value: _language,
      options: const [
        'en',
        'id',
        'zh',
        'ja',
        'ko',
        'es',
        'fr',
        'de',
        'it',
        'pt',
        'th',
        'vi',
        'ar',
      ],
      labelFor: _languageLabel,
      onSelected: (value) {
        setState(() => _language = value);
        _saveDraft();
      },
    );
  }

  void _pickTheme() {
    _showSettingPicker<String>(
      title: _profileText(_language, 'theme'),
      value: _themeMode,
      options: const ['Light', 'Dark'],
      labelFor: (value) => value,
      onSelected: (value) {
        setState(() => _themeMode = value);
        _saveDraft();
      },
    );
  }

  Future<void> _showSettingPicker<T>({
    required String title,
    required T value,
    required List<T> options,
    required String Function(T value) labelFor,
    required ValueChanged<T> onSelected,
  }) async {
    final selected = await showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final option in options)
              ListTile(
                onTap: () => Navigator.of(context).pop(option),
                title: Text(labelFor(option)),
                trailing: option == value
                    ? const Icon(Icons.check_rounded, color: _primary)
                    : null,
              ),
          ],
        ),
      ),
    );
    if (selected != null) onSelected(selected);
  }

  Future<void> _confirmDeleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_profileText(_language, 'deleteQuestion')),
        content: Text(_profileText(_language, 'deleteMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_profileText(_language, 'cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_profileText(_language, 'delete')),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    setState(() => _isDeleting = true);
    try {
      await widget.onDeleteAccount();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().contains('requires-recent-login')
          ? 'Please sign out, sign in again, then delete the account.'
          : 'Could not delete account. $error';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      bottomPadding: 92,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 112),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: _accent.withValues(alpha: .35),
              child: const Icon(
                Icons.person_rounded,
                size: 48,
                color: _primary,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Text(
              widget.account.contactLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 18),
          SettingsTile(
            icon: Icons.language_rounded,
            title: _profileText(_language, 'language'),
            value: _languageLabel(_language),
            onTap: _pickLanguage,
          ),
          SettingsTile(
            icon: Icons.notifications_none_rounded,
            title: _profileText(_language, 'notifications'),
            value: _notificationsEnabled
                ? _localizedSettingValue(_language, 'on')
                : _localizedSettingValue(_language, 'off'),
            onTap: () {
              setState(() => _notificationsEnabled = !_notificationsEnabled);
              _saveDraft();
            },
          ),
          SettingsTile(
            icon: Icons.palette_outlined,
            title: _profileText(_language, 'theme'),
            value: _themeMode,
            onTap: _pickTheme,
          ),
          SettingsTile(
            icon: Icons.explore_outlined,
            title: _profileText(_language, 'interests'),
            value: _interests.isEmpty ? 'None' : '${_interests.length}',
            onTap: _editInterests,
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: _profileText(_language, 'saveProfile'),
            icon: Icons.check_rounded,
            onPressed: _saveDraft,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSigningOut ? null : _signOut,
            icon: _isSigningOut
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            label: Text(_profileText(_language, 'signOut').toUpperCase()),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
            ),
            onPressed: _isDeleting ? null : _confirmDeleteAccount,
            icon: _isDeleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded),
            label: Text(_profileText(_language, 'deleteAccount').toUpperCase()),
          ),
        ],
      ),
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({required this.trip, required this.onBack, super.key});
  final Trip trip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        children: [
          TopBar(title: 'Map', onBack: onBack),
          const SizedBox(height: 18),
          Container(
            height: 360,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: _primary,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _MapPainter())),
                for (final stop in const [
                  Offset(.32, .24),
                  Offset(.58, .42),
                  Offset(.48, .66),
                  Offset(.72, .76),
                ])
                  Positioned(
                    left: stop.dx * 330,
                    top: stop.dy * 330,
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: _accent,
                      size: 34,
                    ),
                  ),
                Positioned(
                  left: 18,
                  bottom: 18,
                  right: 18,
                  child: GlassPanel(
                    child: Text(
                      '${trip.destination} route / ${trip.items.length} stops',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (final item in trip.items.take(4)) ItineraryTile(item: item),
        ],
      ),
    );
  }
}

class InfoScreen extends StatelessWidget {
  const InfoScreen({required this.onBack, super.key});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SimpleToolScreen(
      title: 'Travel Info',
      onBack: onBack,
      children: const [
        InfoCard(
          icon: Icons.cloudy_snowing,
          title: 'Weather',
          text: 'Rain expected after 2 PM. Move outdoor shrines earlier.',
        ),
        InfoCard(
          icon: Icons.train_rounded,
          title: 'Transport',
          text: 'IC cards work across trains and buses around central Kyoto.',
        ),
        InfoCard(
          icon: Icons.payments_rounded,
          title: 'Local costs',
          text: 'Temples are often low-cost; cash is still useful for markets.',
        ),
      ],
    );
  }
}

class TranslateScreen extends StatelessWidget {
  const TranslateScreen({required this.onBack, super.key});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SimpleToolScreen(
      title: 'Translate',
      onBack: onBack,
      children: const [
        InfoCard(
          icon: Icons.record_voice_over_rounded,
          title: 'Where is Kyoto Station?',
          text: '京都駅はどこですか？',
        ),
        InfoCard(
          icon: Icons.restaurant_rounded,
          title: 'No pork, please.',
          text: '豚肉なしでお願いします。',
        ),
        InfoCard(
          icon: Icons.confirmation_number_rounded,
          title: 'I have a reservation.',
          text: '予約があります。',
        ),
      ],
    );
  }
}

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({required this.trip, required this.onBack, super.key});
  final Trip trip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final categories = [
      ('Transport', 1000, 850, _primary),
      ('Stay', 900, 420, _secondary),
      ('Food', 650, 45, _accent),
      ('Activities', 550, 15, Colors.blueGrey.shade200),
    ];
    return SimpleToolScreen(
      title: 'Budget',
      onBack: onBack,
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelText('Spent'),
              Text(
                '\$${trip.spent} of \$${trip.budget}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: trip.spent / trip.budget,
                  minHeight: 10,
                  backgroundColor: _primary.withValues(alpha: .12),
                  color: _accent,
                ),
              ),
            ],
          ),
        ),
        for (final item in categories)
          BudgetBar(
            name: item.$1,
            planned: item.$2,
            actual: item.$3,
            color: item.$4,
          ),
      ],
    );
  }
}

class PackingScreen extends StatelessWidget {
  const PackingScreen({required this.trip, required this.onBack, super.key});
  final Trip trip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SimpleToolScreen(
      title: 'AI Packing List',
      onBack: onBack,
      children: [
        for (final group in trip.checklist)
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.category,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                for (final item in group.items)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: item == group.items.first,
                    onChanged: (_) {},
                    activeColor: _primary,
                    title: Text(
                      item,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class SimpleToolScreen extends StatelessWidget {
  const SimpleToolScreen({
    required this.title,
    required this.onBack,
    required this.children,
    super.key,
  });
  final String title;
  final VoidCallback onBack;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        children: [
          TopBar(title: title, onBack: onBack),
          const SizedBox(height: 18),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.tab, required this.onSelect});
  final _NavTab tab;
  final ValueChanged<_NavTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEFF3F6))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              active: tab == _NavTab.home,
              onTap: () => onSelect(_NavTab.home),
            ),
            NavItem(
              icon: Icons.work_rounded,
              label: 'Trips',
              active: tab == _NavTab.trips,
              onTap: () => onSelect(_NavTab.trips),
            ),
            Transform.translate(
              offset: const Offset(0, -18),
              child: FloatingActionButton(
                heroTag: 'add-trip',
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.white, width: 4),
                ),
                onPressed: () => onSelect(_NavTab.add),
                child: const Icon(Icons.add_rounded, size: 34),
              ),
            ),
            NavItem(
              icon: Icons.chat_bubble_rounded,
              label: 'Chat',
              active: tab == _NavTab.chat,
              onTap: () => onSelect(_NavTab.chat),
            ),
            NavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              active: tab == _NavTab.profile,
              onTap: () => onSelect(_NavTab.profile),
            ),
          ],
        ),
      ),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      child: Center(child: CircularProgressIndicator(color: _primary)),
    );
  }
}

class SyncBanner extends StatelessWidget {
  const SyncBanner({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFED7AA)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFFB45309)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FormNotice extends StatelessWidget {
  const FormNotice({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB91C1C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    required this.child,
    this.bottomPadding = 0,
    super.key,
  });
  final Widget child;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: child,
      ),
    );
  }
}

class CurrentTripCard extends StatelessWidget {
  const CurrentTripCard({required this.trip, required this.onTap, super.key});
  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: ImageHero(
              image: trip.images.first,
              height: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'UP NEXT',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Kyoto City Zoo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: .95,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '10:30 AM / Day 1 route',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Booking',
                  value: trip.bookings.first.title,
                  detail: '${trip.bookings.first.date} / confirmed',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  title: 'Budget',
                  value: '\$${trip.spent}',
                  detail: 'of \$${trip.budget}',
                  trailing: Icons.add_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HeroTripCard extends StatelessWidget {
  const HeroTripCard({required this.trip, super.key});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return ImageHero(
      image: trip.images.first,
      height: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            trip.groupType.toUpperCase(),
            style: const TextStyle(
              color: _accent,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            trip.destination,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${trip.startDate} / ${trip.endDate}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .8),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class ImageHero extends StatelessWidget {
  const ImageHero({
    required this.image,
    required this.child,
    this.height = 140,
    super.key,
  });
  final String image;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: _primary,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            image,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: _primary),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primary.withValues(alpha: .95),
                  _primary.withValues(alpha: .65),
                  _primary.withValues(alpha: .1),
                ],
              ),
            ),
          ),
          Positioned.fill(left: 18, right: 18, bottom: 18, child: child),
        ],
      ),
    );
  }
}

class DestinationCard extends StatelessWidget {
  const DestinationCard({
    required this.destination,
    required this.onTap,
    super.key,
  });
  final Destination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        child: GlassPanel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Image.network(destination.image, fit: BoxFit.cover),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  destination.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaceSuggestionList extends StatelessWidget {
  const PlaceSuggestionList({
    required this.suggestions,
    required this.onSelect,
    super.key,
  });
  final List<PlaceSuggestion> suggestions;
  final ValueChanged<PlaceSuggestion> onSelect;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final suggestion in suggestions)
            InkWell(
              onTap: () => onSelect(suggestion),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place_rounded, color: _secondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            suggestion.formatted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SelectedPlaceCard extends StatelessWidget {
  const SelectedPlaceCard({required this.place, super.key});
  final PlaceSuggestion place;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        children: [
          const IconBadge(icon: Icons.check_rounded, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  place.formatted,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TripListCard extends StatelessWidget {
  const TripListCard({
    required this.trip,
    required this.onTap,
    required this.onStart,
    super.key,
  });
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              trip.images.first,
              width: 94,
              height: 94,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.destination,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${trip.startDate} / ${trip.groupType}',
                  style: const TextStyle(
                    color: _secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SmallPill(label: trip.status.name),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onStart,
                      child: const SmallPill(label: 'Start'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }
}

class ItineraryTile extends StatelessWidget {
  const ItineraryTile({required this.item, super.key});
  final ItineraryItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        child: Row(
          children: [
            IconBadge(icon: item.type, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _secondary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    item.activity,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            Text(
              item.cost == 0 ? 'Free' : '\$${item.cost}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class BookingTile extends StatelessWidget {
  const BookingTile({required this.booking, super.key});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        child: Row(
          children: [
            IconBadge(icon: booking.icon, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${booking.date} / ${booking.reference}',
                    style: const TextStyle(
                      color: _secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SmallPill(label: 'Confirmed'),
          ],
        ),
      ),
    );
  }
}

class SearchBox extends StatelessWidget {
  const SearchBox({
    required this.controller,
    required this.hint,
    required this.onSubmit,
    super.key,
  });
  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        prefixIcon: IconButton(
          icon: const Icon(Icons.auto_awesome_rounded, color: _accent),
          onPressed: onSubmit,
        ),
        hintText: hint,
      ),
    );
  }
}

class AlertRail extends StatelessWidget {
  const AlertRail({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = [
      (
        'Gate changed',
        'Flight JAL 402 now boards at Gate A7.',
        Icons.flight_rounded,
      ),
      ('Rain window', 'Kyoto rain expected after 2 PM.', Icons.cloud_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .36),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelText('Important updates'),
          const SizedBox(height: 8),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) => SizedBox(
                width: 188,
                child: GlassPanel(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      IconBadge(icon: alerts[index].$3, size: 38),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              alerts[index].$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              alerts[index].$2,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _secondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedGlobe extends StatefulWidget {
  const AnimatedGlobe({super.key});

  @override
  State<AnimatedGlobe> createState() => _AnimatedGlobeState();
}

class _AnimatedGlobeState extends State<AnimatedGlobe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: _GlobePainter(_controller.value),
          child: const Center(
            child: Icon(Icons.public_rounded, size: 76, color: _primary),
          ),
        ),
      ),
    );
  }
}

class PlanningIdeaStrip extends StatelessWidget {
  const PlanningIdeaStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabelText('AI planning cards'),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: InfoCard(
                icon: Icons.restaurant_rounded,
                title: 'Food',
                text: 'Market lunch',
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: InfoCard(
                icon: Icons.directions_walk_rounded,
                title: 'Route',
                text: 'Less walking',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DateRangeCard extends StatelessWidget {
  const DateRangeCard({
    required this.startDate,
    required this.endDate,
    required this.onPickStart,
    required this.onPickEnd,
    super.key,
  });

  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        children: [
          const IconBadge(icon: Icons.calendar_month_rounded, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trip dates',
                  style: TextStyle(
                    color: _secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_dateKey(startDate)} / ${_dateKey(endDate)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Start date',
            onPressed: onPickStart,
            icon: const Icon(Icons.today_rounded),
          ),
          IconButton(
            tooltip: 'End date',
            onPressed: onPickEnd,
            icon: const Icon(Icons.event_available_rounded),
          ),
        ],
      ),
    );
  }
}

class GeneratingTripPanel extends StatelessWidget {
  const GeneratingTripPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const GlassPanel(
      child: Row(
        children: [
          SizedBox.square(
            dimension: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generating itinerary...',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'AI is shaping the route, bookings, budget, and packing list.',
                  style: TextStyle(
                    color: _secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, super.key});
  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: message.fromUser ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: message.fromUser
              ? null
              : Border.all(color: const Color(0xFFEFF3F6)),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.fromUser ? Colors.white : _primary,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class ChatPreview extends StatelessWidget {
  const ChatPreview({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: GlassPanel(
          child: Row(
            children: [
              IconBadge(icon: icon, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
    super.key,
  });
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: GlassPanel(
            child: Row(
              children: [
                IconBadge(icon: icon, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: _secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: _secondary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BudgetBar extends StatelessWidget {
  const BudgetBar({
    required this.name,
    required this.planned,
    required this.actual,
    required this.color,
    super.key,
  });
  final String name;
  final int planned;
  final int actual;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '\$$actual / \$$planned',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: actual / planned,
              minHeight: 9,
              backgroundColor: color.withValues(alpha: .18),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class QuickAction extends StatelessWidget {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: _primary, size: 28),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: _secondary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class MiniAction extends StatelessWidget {
  const MiniAction({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        child: Column(
          children: [
            Icon(icon, color: _primary),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    required this.title,
    required this.value,
    required this.detail,
    this.trailing,
    super.key,
  });
  final String title;
  final String value;
  final String detail;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: title == 'Booking'
            ? _accent.withValues(alpha: .16)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    color: _secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) IconBadge(icon: trailing!, size: 32),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    required this.icon,
    required this.title,
    required this.text,
    super.key,
  });
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, size: 42),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              color: _secondary,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({
    required this.title,
    required this.onBack,
    this.action,
    this.onAction,
    super.key,
  });
  final String title;
  final VoidCallback onBack;
  final IconData? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _primary,
          ),
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (action != null)
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _primary,
            ),
            onPressed: onAction,
            icon: Icon(action),
          ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.action,
    this.onTap,
    super.key,
  });
  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -.2,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onTap,
            child: Text(
              action!,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: _secondary,
              ),
            ),
          ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(
        label.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEFF3F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge({required this.icon, this.size = 44, super.key});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Icon(icon, color: _primary, size: size * .5),
    );
  }
}

class IconSquare extends StatelessWidget {
  const IconSquare({required this.icon, super.key});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: _primary),
    );
  }
}

class LabelText extends StatelessWidget {
  const LabelText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: _secondary,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.8,
      ),
    );
  }
}

class SmallPill extends StatelessWidget {
  const SmallPill({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: .25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class NavItem extends StatelessWidget {
  const NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active ? _primary : _secondary.withValues(alpha: .65),
            size: active ? 28 : 24,
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: active ? _primary : _secondary.withValues(alpha: .65),
            ),
          ),
        ],
      ),
    );
  }
}

class Dot extends StatelessWidget {
  const Dot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: _accent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

class _GlobePainter extends CustomPainter {
  const _GlobePainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .42;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _secondary.withValues(alpha: .35);
    canvas.drawCircle(center, radius, paint);
    for (var i = 0; i < 4; i++) {
      final angle = progress * math.pi * 2 + i * math.pi / 2;
      final point =
          center +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius * .55);
      canvas.drawCircle(
        point,
        5,
        Paint()..color = i.isEven ? _accent : _primary,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white.withValues(alpha: .22)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final thin = Paint()
      ..color = _accent.withValues(alpha: .5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final y = size.height * (i + 1) / 7;
      canvas.drawLine(
        Offset(-20, y),
        Offset(size.width + 20, y + math.sin(i) * 40),
        road,
      );
      canvas.drawLine(
        Offset(-20, y),
        Offset(size.width + 20, y + math.sin(i) * 40),
        thin,
      );
    }
    for (var i = 0; i < 5; i++) {
      final x = size.width * (i + 1) / 6;
      canvas.drawLine(
        Offset(x, -20),
        Offset(x + math.cos(i) * 50, size.height + 20),
        road,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
