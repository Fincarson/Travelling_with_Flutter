import 'dart:math' as math;

import 'package:flutter/material.dart';

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
}

class TravelAgentApp extends StatefulWidget {
  const TravelAgentApp({super.key});

  @override
  State<TravelAgentApp> createState() => _TravelAgentAppState();
}

class _TravelAgentAppState extends State<TravelAgentApp> {
  var _showOnboarding = true;
  var _tab = _NavTab.home;
  var _screen = _Screen.dashboard;
  var _user = const UserProfile(name: '', email: '', interests: []);
  final List<Trip> _trips = [];
  Trip? _selectedTrip;
  Trip? _activeTrip;
  String _initialChat = '';

  void _openTrip(Trip trip) {
    setState(() {
      _selectedTrip = trip;
      _screen = _Screen.itinerary;
      _tab = _NavTab.trips;
    });
  }

  void _createTrip(Trip trip) {
    setState(() {
      _trips.insert(0, trip);
      _selectedTrip = trip;
      _screen = _Screen.itinerary;
      _tab = _NavTab.trips;
    });
  }

  void _startTrip(Trip trip) {
    setState(() {
      final started = trip.copyWith(status: TripStatus.ongoing);
      final index = _trips.indexWhere((item) => item.id == trip.id);
      if (index >= 0) _trips[index] = started;
      _activeTrip = started;
      _selectedTrip = started;
      _screen = _Screen.dashboard;
      _tab = _NavTab.home;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE5E7EB),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ClipRect(
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: SafeArea(
                bottom: false,
                child: _showOnboarding
                    ? OnboardingScreen(
                        onComplete: (profile) {
                          setState(() {
                            _user = profile;
                            _showOnboarding = false;
                          });
                        },
                      )
                    : Stack(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _buildScreen(),
                          ),
                          if (_screen != _Screen.create)
                            _BottomNav(tab: _tab, onSelect: _selectTab),
                        ],
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
          user: _user,
          onSave: (profile) => setState(() => _user = profile),
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
  });
  final String name;
  final String email;
  final List<String> interests;
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

  Trip copyWith({TripStatus? status}) => Trip(
    id: id,
    destination: destination,
    startDate: startDate,
    endDate: endDate,
    budget: budget,
    spent: spent,
    groupType: groupType,
    status: status ?? this.status,
    images: images,
    items: items,
    bookings: bookings,
    checklist: checklist,
  );
}

class ItineraryItem {
  const ItineraryItem(this.day, this.time, this.activity, this.type, this.cost);
  final int day;
  final String time;
  final String activity;
  final IconData type;
  final int cost;
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
}

class ChecklistCategory {
  const ChecklistCategory(this.category, this.items);
  final String category;
  final List<String> items;
}

const destinations = [
  Destination(
    'Kyoto, Japan',
    'Bustling city meets serene temples and gardens.',
    'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=900',
    ['Culture', 'Zen'],
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
);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onComplete, super.key});
  final ValueChanged<UserProfile> onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
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
            'Plan smarter adventures',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tell the AI agent who you are so every route, packing list, and budget starts with your style.',
            style: TextStyle(
              color: _secondary,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
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
                name: _name.text.trim().isEmpty
                    ? 'Explorer'
                    : _name.text.trim(),
                email: _email.text.trim(),
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
                    const LabelText('Welcome Back'),
                    Text(
                      '${widget.user.name.isEmpty ? 'Explorer' : widget.user.name}!',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const Stack(
                children: [
                  IconSquare(icon: Icons.notifications_none_rounded),
                  Positioned(right: 10, top: 10, child: Dot()),
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
          const AlertRail(),
          const SizedBox(height: 28),
          const LabelText('Current trip'),
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
  final _destination = TextEditingController(text: 'Kyoto, Japan');
  final _budget = TextEditingController(text: '3500');
  var _group = 'Friends';
  var _mode = 0;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        children: [
          TopBar(title: 'Create Trip', onBack: widget.onBack),
          const SizedBox(height: 18),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('AI Flow'),
                icon: Icon(Icons.auto_awesome_rounded),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Manual'),
                icon: Icon(Icons.edit_note_rounded),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (value) => setState(() => _mode = value.first),
          ),
          const SizedBox(height: 18),
          if (_mode == 0) const AnimatedGlobe(),
          const SizedBox(height: 18),
          TextField(
            controller: _destination,
            decoration: const InputDecoration(labelText: 'Destination'),
          ),
          const SizedBox(height: 12),
          const DateRangeCard(),
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
          const SizedBox(height: 22),
          const PlanningIdeaStrip(),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Generate itinerary',
            icon: Icons.arrow_forward_rounded,
            onPressed: () {
              widget.onGenerate(
                Trip(
                  id: 't-${DateTime.now().millisecondsSinceEpoch}',
                  destination: _destination.text.trim().isEmpty
                      ? 'Kyoto, Japan'
                      : _destination.text.trim(),
                  startDate: '2026-04-16',
                  endDate: '2026-04-27',
                  budget:
                      int.tryParse(
                        _budget.text.replaceAll(RegExp(r'\D'), ''),
                      ) ??
                      3500,
                  spent: 0,
                  groupType: _group,
                  status: TripStatus.upcoming,
                  images: mockKyotoTrip.images,
                  items: mockKyotoTrip.items,
                  bookings: mockKyotoTrip.bookings,
                  checklist: mockKyotoTrip.checklist,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ItineraryScreen extends StatelessWidget {
  const ItineraryScreen({
    required this.trip,
    required this.onBack,
    required this.onOpenChat,
    required this.onOpenBudget,
    required this.onOpenPacking,
    required this.onOpenMap,
    super.key,
  });
  final Trip trip;
  final VoidCallback onBack;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenBudget;
  final VoidCallback onOpenPacking;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<ItineraryItem>>{};
    for (final item in trip.items) {
      grouped.putIfAbsent(item.day, () => []).add(item);
    }
    return ScreenScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        children: [
          TopBar(
            title: trip.destination,
            onBack: onBack,
            action: Icons.more_horiz_rounded,
          ),
          const SizedBox(height: 16),
          HeroTripCard(trip: trip),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: MiniAction(
                  label: 'Packing',
                  icon: Icons.check_circle_outline_rounded,
                  onTap: onOpenPacking,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MiniAction(
                  label: 'Budget',
                  icon: Icons.payments_rounded,
                  onTap: onOpenBudget,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MiniAction(
                  label: 'Map',
                  icon: Icons.map_rounded,
                  onTap: onOpenMap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Bookings', action: 'Chat', onTap: onOpenChat),
          const SizedBox(height: 10),
          for (final booking in trip.bookings) BookingTile(booking: booking),
          const SizedBox(height: 16),
          for (final day in grouped.keys) ...[
            LabelText('Day $day'),
            const SizedBox(height: 10),
            for (final item in grouped[day]!) ItineraryTile(item: item),
            const SizedBox(height: 12),
          ],
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
  final _input = TextEditingController();

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
      if (widget.initialQuery.isNotEmpty)
        ChatMessageModel(false, _aiReply(widget.initialQuery)),
    ];
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
                  onPressed: () {
                    final text = _input.text.trim();
                    if (text.isEmpty) return;
                    setState(() {
                      _messages.add(ChatMessageModel(true, text));
                      _messages.add(ChatMessageModel(false, _aiReply(text)));
                      _input.clear();
                    });
                  },
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _aiReply(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('ramen') || lower.contains('food')) {
    return 'Try Nishiki Market first, then save room for a late ramen stop near Gion. I would keep the food walk before the rain window.';
  }
  if (lower.contains('budget')) {
    return 'Your Kyoto plan is trending under budget. Transport and hotel are the main fixed costs; food has room for one splurge dinner.';
  }
  if (lower.contains('pack')) {
    return 'Pack passport, adapter, power bank, walking shoes, and a light rain jacket. Kyoto rain is expected after 2 PM.';
  }
  return 'I suggest moving outdoor stops earlier, keeping Nishiki Market for the wet window, and using train transfers from Kyoto Station.';
}

class ChatMessageModel {
  const ChatMessageModel(this.fromUser, this.text);
  final bool fromUser;
  final String text;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.user, required this.onSave, super.key});
  final UserProfile user;
  final ValueChanged<UserProfile> onSave;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.user.name,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.user.email,
  );

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
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 18),
          const SettingsTile(
            icon: Icons.language_rounded,
            title: 'Language',
            value: 'English (US)',
          ),
          const SettingsTile(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            value: 'On',
          ),
          const SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Theme',
            value: 'Light',
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Save profile',
            icon: Icons.check_rounded,
            onPressed: () => widget.onSave(
              UserProfile(
                name: _name.text,
                email: _email.text,
                interests: widget.user.interests,
              ),
            ),
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
      color: _bg,
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
  const DateRangeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const GlassPanel(
      child: Row(
        children: [
          IconBadge(icon: Icons.calendar_month_rounded, size: 46),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Apr 16, 2026 / Apr 27, 2026',
              style: TextStyle(fontWeight: FontWeight.w900),
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
    super.key,
  });
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
          ],
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
