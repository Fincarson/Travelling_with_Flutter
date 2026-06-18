part of travel_agent_app;

class TripSettingsScreen extends StatefulWidget {
  const TripSettingsScreen({
    required this.trip,
    required this.accountId,
    required this.onBack,
    required this.onSave,
    super.key,
  });

  final Trip trip;
  final String accountId;
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
  late String _currencyCode;
  late int _travelers;
  late String? _selectedImage;
  late String _savedDraftSignature;
  final _bannerUploader = _TripBannerImageService();
  var _searchedImages = <String>[];
  var _isSaving = false;
  var _isUploadingBanner = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.trip.title);
    _destination = TextEditingController(text: widget.trip.destination);
    _startDate = TextEditingController(text: widget.trip.startDate);
    _endDate = TextEditingController(text: widget.trip.endDate);
    _budget = TextEditingController(text: widget.trip.budget.toString());
    _currencyCode = _normalizedCurrencyCode(widget.trip.currency);
    _travelers = widget.trip.numOfTravelers;
    _selectedImage = widget.trip.images.isEmpty
        ? null
        : widget.trip.images.first;
    _searchedImages = _mergedTripSettingsImages(
      destination: widget.trip.destination,
      selectedImage: _selectedImage,
      existingImages: widget.trip.images,
      searchedImages: const [],
    );
    _savedDraftSignature = _draftSignature();
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
    _currencyCode = _normalizedCurrencyCode(widget.trip.currency);
    _travelers = widget.trip.numOfTravelers;
    _selectedImage = widget.trip.images.isEmpty
        ? null
        : widget.trip.images.first;
    _searchedImages = _mergedTripSettingsImages(
      destination: widget.trip.destination,
      selectedImage: _selectedImage,
      existingImages: widget.trip.images,
      searchedImages: const [],
    );
    _savedDraftSignature = _draftSignature();
  }

  @override
  void dispose() {
    _title.dispose();
    _destination.dispose();
    _startDate.dispose();
    _endDate.dispose();
    _budget.dispose();
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

  String _draftSignature() {
    return [
      _title.text.trim(),
      _destination.text.trim(),
      _startDate.text.trim(),
      _endDate.text.trim(),
      _budget.text.replaceAll(RegExp(r'\D'), ''),
      _currencyCode,
      _travelers,
      _selectedImage ?? '',
    ].join('\u001F');
  }

  bool get _hasUnsavedChanges => _draftSignature() != _savedDraftSignature;

  Trip _draftTrip() {
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

    return widget.trip.copyWith(
      title: title,
      destination: destination,
      startDate: _startDate.text.trim(),
      endDate: _endDate.text.trim(),
      budget: int.tryParse(_budget.text.replaceAll(RegExp(r'\D'), '')) ?? 0,
      currency: _currencyCode,
      numOfTravelers: _travelers,
      images: images.isEmpty ? _imagesForDestination(destination) : images,
      clearDestinationPlace: destination != widget.trip.destination,
    );
  }

  void _save({bool showNotice = true}) {
    setState(() => _isSaving = true);
    widget.onSave(_draftTrip());
    _savedDraftSignature = _draftSignature();
    if (showNotice) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(appText(context, 'Trip settings saved')),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _handleBack() async {
    if (!_hasUnsavedChanges) {
      widget.onBack();
      return;
    }
    final action = await showDialog<_UnsavedTripSettingsAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(appText(dialogContext, 'Save changes?')),
        content: Text(
          appText(
            dialogContext,
            'You have unsaved trip settings. Save them before leaving?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(appText(dialogContext, 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(_UnsavedTripSettingsAction.discard),
            child: Text(appText(dialogContext, 'Discard')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(_UnsavedTripSettingsAction.save),
            child: Text(appText(dialogContext, 'Save')),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == _UnsavedTripSettingsAction.save) {
      _save(showNotice: false);
    }
    widget.onBack();
  }

  Future<void> _showBannerSourceSheet() async {
    final action = await _showTravelFormSheet<_BannerImageSourceAction>(
      context: context,
      requireSafeDismissal: false,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            appText(sheetContext, 'Change banner image'),
            style: Theme.of(
              sheetContext,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          _BannerSourceButton(
            icon: Icons.travel_explore_rounded,
            title: 'Search for a banner image',
            subtitle: 'Find travel photos based on this trip destination.',
            onTap: () =>
                Navigator.of(sheetContext).pop(_BannerImageSourceAction.search),
          ),
          const SizedBox(height: 10),
          _BannerSourceButton(
            icon: Icons.upload_rounded,
            title: 'Upload your own image',
            subtitle: 'Choose an image from this device.',
            onTap: () =>
                Navigator.of(sheetContext).pop(_BannerImageSourceAction.upload),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _BannerImageSourceAction.search:
        await _openBannerImageSearch();
      case _BannerImageSourceAction.upload:
        await _uploadBannerImage();
    }
  }

  Future<void> _openBannerImageSearch() async {
    final destination = _destination.text.trim().isEmpty
        ? widget.trip.destination
        : _destination.text.trim();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => _BannerImageSearchSheet(
        initialQuery: destination,
        selectedImage: _selectedImage,
        existingImages: widget.trip.images,
      ),
    );
    if (selected == null || !mounted) return;
    final merged = _mergedTripSettingsImages(
      destination: destination,
      selectedImage: selected,
      existingImages: widget.trip.images,
      searchedImages: _searchedImages,
    );
    setState(() {
      _selectedImage = selected;
      _searchedImages = merged;
    });
  }

  Future<void> _uploadBannerImage() async {
    if (_isUploadingBanner) return;
    setState(() => _isUploadingBanner = true);
    try {
      final uploaded = await _bannerUploader.pickAndUpload(
        accountId: widget.accountId,
        tripId: widget.trip.id,
        imageQuality: PerformanceScope.settingsOf(context).imageQuality,
      );
      if (uploaded == null || !mounted) return;
      setState(() {
        _selectedImage = uploaded;
        _searchedImages = _mergedTripSettingsImages(
          destination: _destination.text.trim().isEmpty
              ? widget.trip.destination
              : _destination.text.trim(),
          selectedImage: uploaded,
          existingImages: widget.trip.images,
          searchedImages: _searchedImages,
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              appText(context, 'Could not update banner image: $error'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _isUploadingBanner = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterQuality = PerformanceScope.maybeSettingsOf(
      context,
    ).filterQuality;
    final currencyScope = CurrencyScope.maybeOf(context);
    final currencyOptions = _tripSettingsCurrencyCodes(
      currencyScope?.currencies ?? CurrencyExchangeData.fallback.currencies,
      _currencyCode,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handleBack());
      },
      child: ScreenScaffold(
        child: ListView(
          padding: _responsivePagePadding(context, top: 18, bottom: 140),
          children: [
            TopBar(
              title: 'Trip settings',
              onBack: () => unawaited(_handleBack()),
            ),
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
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: appText(context, 'Destination'),
                      prefixIcon: const Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          controller: _startDate,
                          label: 'Start date',
                          onTap: () => _pickDate(_startDate),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateField(
                          controller: _endDate,
                          label: 'End date',
                          onTap: () => _pickDate(_endDate),
                        ),
                      ),
                    ],
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
                        DropdownButtonFormField<String>(
                          initialValue: currencyOptions.contains(_currencyCode)
                              ? _currencyCode
                              : currencyOptions.first,
                          isExpanded: true,
                          menuMaxHeight: 320,
                          decoration: InputDecoration(
                            labelText: appText(context, 'Currency'),
                            prefixIcon: const Icon(Icons.payments_outlined),
                          ),
                          items: [
                            for (final code in currencyOptions)
                              DropdownMenuItem(
                                value: code,
                                child: Text(
                                  code,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _currencyCode = value);
                          },
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_selectedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          _selectedImage!,
                          fit: BoxFit.cover,
                          filterQuality: filterQuality,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: const Color(0xFFF4F8FA),
                                child: const Icon(
                                  Icons.image_not_supported_rounded,
                                  color: Color(0xFFACCBE0),
                                ),
                              ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: _isUploadingBanner
                        ? 'Uploading banner image'
                        : 'Change banner image',
                    icon: _isUploadingBanner
                        ? Icons.hourglass_top_rounded
                        : Icons.add_photo_alternate_rounded,
                    onPressed: _isUploadingBanner
                        ? null
                        : _showBannerSourceSheet,
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

class _BannerSourceButton extends StatelessWidget {
  const _BannerSourceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconBadge(icon: icon, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appText(context, title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      appText(context, subtitle),
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
              const Icon(Icons.chevron_right_rounded, color: _primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerImageSearchSheet extends StatefulWidget {
  const _BannerImageSearchSheet({
    required this.initialQuery,
    required this.selectedImage,
    required this.existingImages,
  });

  final String initialQuery;
  final String? selectedImage;
  final List<String> existingImages;

  @override
  State<_BannerImageSearchSheet> createState() =>
      _BannerImageSearchSheetState();
}

class _BannerImageSearchSheetState extends State<_BannerImageSearchSheet> {
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery,
  );
  late List<String> _images = _mergedTripSettingsImages(
    destination: widget.initialQuery,
    selectedImage: widget.selectedImage,
    existingImages: widget.existingImages,
    searchedImages: const [],
  );
  var _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_isSearching) return;
    final query = _query.text.trim().isEmpty
        ? widget.initialQuery
        : _query.text.trim();
    setState(() => _isSearching = true);
    final images = await _searchTripBannerImages(
      destination: query,
      selectedImage: widget.selectedImage,
      existingImages: widget.existingImages,
    );
    if (!mounted) return;
    setState(() {
      _images = images;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filterQuality = PerformanceScope.maybeSettingsOf(
      context,
    ).filterQuality;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .86,
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _responsiveHorizontalPadding(context),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => unawaited(_search()),
                    decoration: InputDecoration(
                      hintText: appText(context, 'Search banner images'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              tooltip: appText(context, 'Search'),
                              onPressed: () => unawaited(_search()),
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: appText(context, 'Close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(
                _responsiveHorizontalPadding(context),
                0,
                _responsiveHorizontalPadding(context),
                24,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.sizeOf(context).width >= 720
                    ? 4
                    : MediaQuery.sizeOf(context).width >= 420
                    ? 3
                    : 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: .86,
              ),
              itemCount: _images.length,
              itemBuilder: (context, index) {
                final image = _images[index];
                return _TripSettingsImageTile(
                  image: image,
                  selected: image == widget.selectedImage,
                  filterQuality: filterQuality,
                  onTap: () => Navigator.of(context).pop(image),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TripBannerImageService {
  _TripBannerImageService({ImagePicker? picker, FirebaseStorage? storage})
    : _picker = picker ?? ImagePicker(),
      _storage = storage ?? FirebaseStorage.instance;

  static const _maximumUploadBytes = 8 * 1024 * 1024;

  final ImagePicker _picker;
  final FirebaseStorage _storage;

  Future<String?> pickAndUpload({
    required String accountId,
    required String tripId,
    required ImageQualityPreference imageQuality,
  }) async {
    final settings = switch (imageQuality) {
      ImageQualityPreference.high => (quality: 90, maximumDimension: 2200.0),
      ImageQualityPreference.balanced => (
        quality: 76,
        maximumDimension: 1600.0,
      ),
      ImageQualityPreference.low => (quality: 58, maximumDimension: 1000.0),
    };
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: settings.quality,
      maxWidth: settings.maximumDimension,
      maxHeight: settings.maximumDimension,
      requestFullMetadata: false,
    );
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    if (bytes.length > _maximumUploadBytes) {
      throw StateError('The selected image must be smaller than 8 MB.');
    }

    final contentType =
        image.mimeType ?? _tripBannerContentTypeForName(image.name);
    final reference = _storage.ref('trip_banners/$accountId/$tripId/banner');
    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        cacheControl: 'public,max-age=3600',
      ),
    );
    final url = await reference.getDownloadURL();
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=${DateTime.now().millisecondsSinceEpoch}';
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

List<String> _tripSettingsCurrencyCodes(
  List<CurrencyInfo> currencies,
  String selected,
) {
  final seen = <String>{};
  return [
        selected,
        AppCurrency.fallbackCurrencyCode,
        ...currencies.map((currency) => currency.code),
      ]
      .map(_normalizedCurrencyCode)
      .where((code) => code.isNotEmpty && seen.add(code))
      .toList();
}

String _normalizedCurrencyCode(String value) {
  final code = value.trim().toUpperCase();
  return code.isEmpty ? AppCurrency.fallbackCurrencyCode : code;
}

String _tripBannerContentTypeForName(String name) {
  final normalized = name.toLowerCase();
  if (normalized.endsWith('.png')) return 'image/png';
  if (normalized.endsWith('.webp')) return 'image/webp';
  if (normalized.endsWith('.heic') || normalized.endsWith('.heif')) {
    return 'image/heic';
  }
  return 'image/jpeg';
}

enum _BannerImageSourceAction { search, upload }

enum _UnsavedTripSettingsAction { save, discard }

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
  bool requireSafeDismissal = true,
}) async {
  final result = await showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: !requireSafeDismissal,
    enableDrag: !requireSafeDismissal,
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
  await WidgetsBinding.instance.endOfFrame;
  return result;
}

Future<void> _closeTravelFormSheet<T>(BuildContext context, [T? result]) async {
  final navigator = Navigator.of(context);
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await Future<void>.delayed(const Duration(milliseconds: 140));
  if (!navigator.mounted) return;
  navigator.pop<T>(result);
}

Future<String?> _pickSheetDate(
  BuildContext context, {
  required String initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  final parsed = _parseTripDate(initialDate) ?? firstDate;
  final initial = _clampDate(parsed, firstDate, lastDate);
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: firstDate,
    lastDate: lastDate,
  );
  if (picked == null) return null;
  await WidgetsBinding.instance.endOfFrame;
  return _dateKey(picked);
}

Future<int?> _showWheelTimePicker(
  BuildContext context, {
  required int initialMinutes,
}) async {
  var selectedMinutes = initialMinutes.clamp(0, 23 * 60 + 59).toInt();
  final initialDateTime = DateTime(
    2000,
    1,
    1,
  ).add(Duration(minutes: selectedMinutes));
  final result = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            margin: EdgeInsets.fromLTRB(
              _responsiveHorizontalPadding(sheetContext),
              8,
              _responsiveHorizontalPadding(sheetContext),
              18,
            ),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(appText(sheetContext, 'Cancel')),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(selectedMinutes),
                      child: Text(appText(sheetContext, 'Done')),
                    ),
                  ],
                ),
                SizedBox(
                  height: 216,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: initialDateTime,
                    minuteInterval: 1,
                    use24hFormat: false,
                    onDateTimeChanged: (value) {
                      selectedMinutes = value.hour * 60 + value.minute;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  return result;
}

class _SheetPickerField extends StatelessWidget {
  const _SheetPickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: appText(context, label),
          suffixIcon: Icon(icon),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

DateTime _clampDate(DateTime value, DateTime firstDate, DateTime lastDate) {
  if (value.isBefore(firstDate)) return firstDate;
  if (value.isAfter(lastDate)) return lastDate;
  return value;
}

String _minutesToPickerTimeLabel(int minutes) {
  final normalized = minutes.clamp(0, 23 * 60 + 59).toInt();
  var hour = (normalized ~/ 60) % 24;
  final minute = normalized % 60;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour == 0
      ? 12
      : hour > 12
      ? hour - 12
      : hour;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
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
