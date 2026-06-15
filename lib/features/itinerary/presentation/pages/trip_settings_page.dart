part of travel_agent_app;

class TripSettingsScreen extends StatefulWidget {
  const TripSettingsScreen({
    required this.trip,
    required this.onBack,
    required this.onSave,
    super.key,
  });

  final Trip trip;
  final VoidCallback onBack;
  final ValueChanged<Trip> onSave;

  @override
  State<TripSettingsScreen> createState() => _TripSettingsScreenState();
}

class _TripSettingsScreenState extends State<TripSettingsScreen> {
  late final TextEditingController _title;
  late final TextEditingController _destination;
  late final TextEditingController _startDate;
  late final TextEditingController _endDate;
  late final TextEditingController _budget;
  late final TextEditingController _currency;
  late int _travelers;
  late TripStatus _status;
  late String? _selectedImage;
  var _searchedImages = <String>[];
  var _isSearchingImages = false;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.trip.title);
    _destination = TextEditingController(text: widget.trip.destination);
    _startDate = TextEditingController(text: widget.trip.startDate);
    _endDate = TextEditingController(text: widget.trip.endDate);
    _budget = TextEditingController(text: widget.trip.budget.toString());
    _currency = TextEditingController(text: widget.trip.currency);
    _travelers = widget.trip.numOfTravelers;
    _status = widget.trip.status;
    _selectedImage = widget.trip.images.isEmpty
        ? null
        : widget.trip.images.first;
    _searchedImages = _mergedTripSettingsImages(
      destination: widget.trip.destination,
      selectedImage: _selectedImage,
      existingImages: widget.trip.images,
      searchedImages: const [],
    );
  }

  @override
  void didUpdateWidget(covariant TripSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip == widget.trip || _isSaving) return;
    _title.text = widget.trip.title;
    _destination.text = widget.trip.destination;
    _startDate.text = widget.trip.startDate;
    _endDate.text = widget.trip.endDate;
    _budget.text = widget.trip.budget.toString();
    _currency.text = widget.trip.currency;
    _travelers = widget.trip.numOfTravelers;
    _status = widget.trip.status;
    _selectedImage = widget.trip.images.isEmpty
        ? null
        : widget.trip.images.first;
    _searchedImages = _mergedTripSettingsImages(
      destination: widget.trip.destination,
      selectedImage: _selectedImage,
      existingImages: widget.trip.images,
      searchedImages: const [],
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _destination.dispose();
    _startDate.dispose();
    _endDate.dispose();
    _budget.dispose();
    _currency.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final parsed = _parseTripDate(controller.text) ?? _travelAgentNow();
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    controller.text = _dateKey(picked);
  }

  Future<void> _searchImages() async {
    if (_isSearchingImages) return;
    setState(() => _isSearchingImages = true);
    final destination = _destination.text.trim().isEmpty
        ? widget.trip.destination
        : _destination.text.trim();
    final images = await _searchTripBannerImages(
      destination: destination,
      selectedImage: _selectedImage,
      existingImages: widget.trip.images,
    );
    if (!mounted) return;
    setState(() {
      _searchedImages = images;
      _isSearchingImages = false;
      _selectedImage ??= images.isEmpty ? null : images.first;
    });
  }

  void _save() {
    final destination = _destination.text.trim().isEmpty
        ? widget.trip.destination
        : _destination.text.trim();
    final title = _title.text.trim().isEmpty ? destination : _title.text.trim();
    final selected = _selectedImage?.trim();
    final images = [
      if (selected != null && selected.isNotEmpty) selected,
      ...widget.trip.images.where((image) => image != selected),
      ..._searchedImages.where((image) => image != selected),
    ].where((image) => image.trim().isNotEmpty).toSet().toList();

    setState(() => _isSaving = true);
    widget.onSave(
      widget.trip.copyWith(
        title: title,
        destination: destination,
        startDate: _startDate.text.trim(),
        endDate: _endDate.text.trim(),
        budget: int.tryParse(_budget.text.replaceAll(RegExp(r'\D'), '')) ?? 0,
        currency: _currency.text.trim().isEmpty
            ? widget.trip.currency
            : _currency.text.trim().toUpperCase(),
        numOfTravelers: _travelers,
        status: _status,
        images: images.isEmpty ? _imagesForDestination(destination) : images,
        clearDestinationPlace: destination != widget.trip.destination,
      ),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(appText(context, 'Trip settings saved')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final filterQuality = PerformanceScope.maybeSettingsOf(
      context,
    ).filterQuality;

    return ScreenScaffold(
      child: ListView(
        padding: _responsivePagePadding(context, top: 18, bottom: 40),
        children: [
          TopBar(title: 'Trip settings', onBack: widget.onBack),
          const SizedBox(height: 18),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: appText(context, 'Trip title'),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _destination,
                  decoration: InputDecoration(
                    labelText: appText(context, 'Destination'),
                    prefixIcon: const Icon(Icons.place_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final fields = [
                      _DateField(
                        controller: _startDate,
                        label: 'Start date',
                        onTap: () => _pickDate(_startDate),
                      ),
                      _DateField(
                        controller: _endDate,
                        label: 'End date',
                        onTap: () => _pickDate(_endDate),
                      ),
                    ];
                    if (compact) {
                      return Column(
                        children: [
                          fields[0],
                          const SizedBox(height: 12),
                          fields[1],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: fields[0]),
                        const SizedBox(width: 12),
                        Expanded(child: fields[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _TravelerStepper(
                  travelers: _travelers,
                  onChanged: (value) => setState(() => _travelers = value),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final fields = [
                      TextField(
                        controller: _budget,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: appText(context, 'Budget'),
                          prefixIcon: const Icon(
                            Icons.account_balance_wallet_outlined,
                          ),
                        ),
                      ),
                      TextField(
                        controller: _currency,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: appText(context, 'Currency'),
                          prefixIcon: const Icon(Icons.payments_outlined),
                        ),
                      ),
                    ];
                    if (compact) {
                      return Column(
                        children: [
                          fields[0],
                          const SizedBox(height: 12),
                          fields[1],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: fields[0]),
                        const SizedBox(width: 12),
                        Expanded(child: fields[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TripStatus>(
                  initialValue: _status,
                  decoration: InputDecoration(
                    labelText: appText(context, 'Status'),
                    prefixIcon: const Icon(Icons.flag_outlined),
                  ),
                  items: [
                    for (final status in TripStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(appText(context, _tripStatusLabel(status))),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        appText(context, 'Banner image'),
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _isSearchingImages ? null : _searchImages,
                      icon: _isSearchingImages
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.travel_explore_rounded),
                      label: Text(
                        appText(
                          context,
                          _isSearchingImages ? 'Searching...' : 'Search',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _TripSettingsImageGrid(
                  images: _searchedImages,
                  selectedImage: _selectedImage,
                  filterQuality: filterQuality,
                  onSelect: (image) => setState(() => _selectedImage = image),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: _isSaving ? 'Saving' : 'Save changes',
            icon: Icons.save_rounded,
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.controller,
    required this.label,
    required this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: appText(context, label),
        prefixIcon: const Icon(Icons.event_outlined),
        suffixIcon: IconButton(
          tooltip: appText(context, 'Pick date'),
          onPressed: onTap,
          icon: const Icon(Icons.calendar_month_rounded),
        ),
      ),
    );
  }
}

class _TravelerStepper extends StatelessWidget {
  const _TravelerStepper({required this.travelers, required this.onChanged});

  final int travelers;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = travelers.clamp(1, 99).toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.group_outlined, color: _secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              appText(context, _travelerCountLabel(safeValue)),
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: appText(context, 'Remove traveler'),
            onPressed: safeValue <= 1 ? null : () => onChanged(safeValue - 1),
            icon: const Icon(Icons.remove_rounded),
          ),
          IconButton(
            tooltip: appText(context, 'Add traveler'),
            onPressed: safeValue >= 99 ? null : () => onChanged(safeValue + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _TripSettingsImageGrid extends StatelessWidget {
  const _TripSettingsImageGrid({
    required this.images,
    required this.selectedImage,
    required this.filterQuality,
    required this.onSelect,
  });

  final List<String> images;
  final String? selectedImage;
  final FilterQuality filterQuality;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 3
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final image in images)
              SizedBox(
                width: width,
                height: columns == 1 ? 170 : 132,
                child: _TripSettingsImageTile(
                  image: image,
                  selected: image == selectedImage,
                  filterQuality: filterQuality,
                  onTap: () => onSelect(image),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TripSettingsImageTile extends StatelessWidget {
  const _TripSettingsImageTile({
    required this.image,
    required this.selected,
    required this.filterQuality,
    required this.onTap,
  });

  final String image;
  final bool selected;
  final FilterQuality filterQuality;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                image,
                fit: BoxFit.cover,
                filterQuality: filterQuality,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFFF4F8FA),
                  child: const Icon(
                    Icons.image_not_supported_rounded,
                    color: Color(0xFFACCBE0),
                  ),
                ),
              ),
              if (selected)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: _accent, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.check_circle_rounded, color: _accent),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<List<String>> _searchTripBannerImages({
  required String destination,
  String? selectedImage,
  List<String> existingImages = const [],
}) async {
  final fallback = _mergedTripSettingsImages(
    destination: destination,
    selectedImage: selectedImage,
    existingImages: existingImages,
    searchedImages: const [],
  );
  try {
    final query = '$destination travel landmark';
    final url = Uri.https('commons.wikimedia.org', '/w/api.php', {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': query,
      'gsrnamespace': '6',
      'gsrlimit': '9',
      'prop': 'imageinfo',
      'iiprop': 'url',
      'iiurlwidth': '900',
      'format': 'json',
      'origin': '*',
    });
    final response = await http
        .get(
          url,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'TravellingWithFlutter/1.0 trip-settings-images',
          },
        )
        .timeout(const Duration(seconds: 4));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return fallback;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final pages = body['query'] is Map ? (body['query'] as Map)['pages'] : null;
    final searchedImages = <String>[];
    if (pages is Map) {
      for (final page in pages.values.whereType<Map>()) {
        final imageInfoList = (page['imageinfo'] as List<dynamic>?)
            ?.whereType<Map>()
            .toList();
        final imageInfo = imageInfoList == null || imageInfoList.isEmpty
            ? null
            : imageInfoList.first;
        final imageUrl =
            (imageInfo?['thumburl'] as String?) ??
            (imageInfo?['url'] as String?);
        if (_isTripSettingsImageUrl(imageUrl)) searchedImages.add(imageUrl!);
      }
    }
    return _mergedTripSettingsImages(
      destination: destination,
      selectedImage: selectedImage,
      existingImages: existingImages,
      searchedImages: searchedImages,
    );
  } catch (_) {
    return fallback;
  }
}

bool _isTripSettingsImageUrl(String? value) {
  if (value == null || value.trim().isEmpty) return false;
  final lower = value.toLowerCase();
  return lower.startsWith('https://') &&
      (lower.contains('.jpg') ||
          lower.contains('.jpeg') ||
          lower.contains('.png') ||
          lower.contains('.webp'));
}

List<String> _mergedTripSettingsImages({
  required String destination,
  required String? selectedImage,
  required List<String> existingImages,
  required List<String> searchedImages,
}) {
  final seen = <String>{};
  return [
    if (selectedImage != null && selectedImage.trim().isNotEmpty) selectedImage,
    ...searchedImages,
    ...existingImages,
    ..._imagesForDestination(destination),
  ].where((image) => seen.add(image)).take(9).toList();
}

Future<T?> _showTravelFormSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext sheetContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Container(
                margin: EdgeInsets.fromLTRB(
                  _responsiveHorizontalPadding(sheetContext),
                  8,
                  _responsiveHorizontalPadding(sheetContext),
                  18,
                ),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).colorScheme.surface,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .12),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: builder(sheetContext),
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showUndoSnackBar(
  BuildContext context, {
  required String message,
  required String undoLabel,
  required VoidCallback onUndo,
}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(appText(context, message)),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: appText(context, undoLabel),
          onPressed: onUndo,
        ),
      ),
    );
}

String _tripStatusLabel(TripStatus status) {
  return switch (status) {
    TripStatus.upcoming => 'Upcoming',
    TripStatus.ongoing => 'Ongoing',
    TripStatus.past => 'Past',
  };
}
