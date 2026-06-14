part of travel_agent_app;

int _initialDay(Trip trip) {
  if (trip.items.isEmpty) return 1;
  final runtimeDay = _tripRuntimePlan(trip).currentDay;
  final days = trip.items.map((item) => item.day).toSet();
  if (days.contains(runtimeDay)) return runtimeDay;
  return days.reduce(math.min);
}

class _TripMapBottomPanel extends StatelessWidget {
  const _TripMapBottomPanel({
    required this.compact,
    required this.height,
    required this.minHeight,
    required this.halfHeight,
    required this.maxHeight,
    required this.stops,
    required this.selectedIndex,
    required this.selectedStop,
    required this.travelMode,
    required this.route,
    required this.message,
    required this.resolving,
    required this.routing,
    required this.aiController,
    required this.aiEnabled,
    required this.onSelectStop,
    required this.onSelectMode,
    required this.onOpenGoogleMaps,
    required this.onAskAi,
    required this.onDrag,
    required this.onDragEnd,
    required this.onToggle,
  });

  final bool compact;
  final double height;
  final double minHeight;
  final double halfHeight;
  final double maxHeight;
  final List<_TripMapStop> stops;
  final int selectedIndex;
  final _TripMapStop? selectedStop;
  final MapTravelMode travelMode;
  final _TripMapRoute? route;
  final String? message;
  final bool resolving;
  final bool routing;
  final TextEditingController aiController;
  final bool aiEnabled;
  final ValueChanged<int> onSelectStop;
  final ValueChanged<MapTravelMode> onSelectMode;
  final VoidCallback onOpenGoogleMaps;
  final VoidCallback onAskAi;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onDragEnd;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final showTransport = height >= minHeight + 54;
    final showItinerary = height >= minHeight + 130;
    final showAi = height >= halfHeight - 40;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Material(
            color: Colors.white.withValues(alpha: .985),
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              key: const ValueKey('map-bottom-panel'),
              height: height,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 18,
                  7,
                  compact ? 12 : 18,
                  12,
                ),
                child: Column(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Swipe up or down to resize map controls',
                      child: GestureDetector(
                        key: const ValueKey('map-panel-handle'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onToggle,
                        onVerticalDragUpdate: (details) =>
                            onDrag(details.delta.dy),
                        onVerticalDragEnd: (details) =>
                            onDragEnd(details.primaryVelocity ?? 0),
                        child: SizedBox(
                          height: 14,
                          width: 72,
                          child: Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFC4C7C5),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    _SelectedItineraryStop(
                      stop: selectedStop,
                      stopNumber: selectedIndex + 1,
                      onOpenGoogleMaps: onOpenGoogleMaps,
                    ),
                    if (showTransport) ...[
                      const SizedBox(height: 8),
                      _TransportModeBar(
                        selectedMode: travelMode,
                        route: route,
                        loading: routing,
                        onSelected: onSelectMode,
                      ),
                      if (message != null || resolving) ...[
                        const SizedBox(height: 6),
                        _MapInlineStatus(
                          message: resolving
                              ? 'Locating itinerary stops...'
                              : message!,
                          loading: resolving,
                        ),
                      ],
                    ],
                    if (showItinerary) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text(
                            "Today's itinerary",
                            style: TextStyle(
                              color: Color(0xFF202124),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${stops.length} ${stops.length == 1 ? 'stop' : 'stops'}',
                            style: const TextStyle(
                              color: Color(0xFF5F6368),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Expanded(
                        child: _ItineraryStopList(
                          stops: stops,
                          selectedIndex: selectedIndex,
                          onSelect: onSelectStop,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (showAi) ...[
                      const SizedBox(height: 8),
                      _MapAiBar(
                        controller: aiController,
                        enabled: aiEnabled,
                        onSubmit: onAskAi,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedItineraryStop extends StatelessWidget {
  const _SelectedItineraryStop({
    required this.stop,
    required this.stopNumber,
    required this.onOpenGoogleMaps,
  });

  final _TripMapStop? stop;
  final int stopNumber;
  final VoidCallback onOpenGoogleMaps;

  @override
  Widget build(BuildContext context) {
    final item = stop?.item;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFF1A73E8),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: item == null
              ? const Icon(Icons.route_rounded, color: Colors.white, size: 18)
              : Text(
                  '$stopNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item?.activity ?? 'No itinerary stops for this day',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF202124),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item == null
                    ? 'Add an itinerary item to see it here.'
                    : item.hasMapLocation
                    ? '${item.time} / ${item.formattedAddress ?? 'Itinerary stop'}'
                    : '${item.time} / Location will be added when available',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF5F6368),
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: item?.hasMapLocation == true ? onOpenGoogleMaps : null,
          icon: const Icon(Icons.directions_rounded, size: 17),
          label: const Text('Directions'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1A73E8),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TransportModeBar extends StatelessWidget {
  const _TransportModeBar({
    required this.selectedMode,
    required this.route,
    required this.loading,
    required this.onSelected,
  });

  final MapTravelMode selectedMode;
  final _TripMapRoute? route;
  final bool loading;
  final ValueChanged<MapTravelMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F4),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  for (final mode in MapTravelMode.values)
                    Expanded(
                      child: _TransportModeButton(
                        mode: mode,
                        selected: mode == selectedMode,
                        onTap: () => onSelected(mode),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (loading)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (route != null)
            Text(
              '${route!.durationLabel} / ${route!.distanceLabel}',
              style: const TextStyle(
                color: Color(0xFF5F6368),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _TransportModeButton extends StatelessWidget {
  const _TransportModeButton({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final MapTravelMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: mode.label,
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        elevation: selected ? 1 : 0,
        shadowColor: Colors.black.withValues(alpha: .08),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            height: 34,
            child: Icon(
              mode.icon,
              size: 18,
              color: selected
                  ? const Color(0xFF1A73E8)
                  : const Color(0xFF5F6368),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapInlineStatus extends StatelessWidget {
  const _MapInlineStatus({required this.message, required this.loading});

  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (loading)
          const SizedBox.square(
            dimension: 13,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          const Icon(Icons.info_outline_rounded, size: 15, color: _secondary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _secondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ItineraryStopList extends StatelessWidget {
  const _ItineraryStopList({
    required this.stops,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_TripMapStop> stops;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Itinerary stops will appear here.',
          style: TextStyle(
            color: Color(0xFF5F6368),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return ListView.separated(
      key: const ValueKey('map-itinerary-list'),
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: stops.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) => _ItineraryStopTile(
        stopNumber: index + 1,
        item: stops[index].item,
        selected: selectedIndex == index,
        onTap: () => onSelect(index),
      ),
    );
  }
}

class _ItineraryStopTile extends StatelessWidget {
  const _ItineraryStopTile({
    required this.stopNumber,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final int stopNumber;
  final ScheduleItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('map-itinerary-stop-$stopNumber'),
      color: selected ? const Color(0xFFE8F0FE) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? const Color(0xFFB8CDF8)
                  : const Color(0xFFE8EAED),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF1A73E8)
                      : const Color(0xFFF1F3F4),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$stopNumber',
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF5F6368),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.time,
                          style: TextStyle(
                            color: selected
                                ? const Color(0xFF185ABC)
                                : const Color(0xFF5F6368),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          item.type,
                          size: 14,
                          color: const Color(0xFF5F6368),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.activity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF202124),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((item.formattedAddress ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.formattedAddress!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF5F6368),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                selected
                    ? item.hasMapLocation
                          ? Icons.location_on_rounded
                          : Icons.radio_button_checked_rounded
                    : Icons.chevron_right_rounded,
                color: selected
                    ? const Color(0xFF1A73E8)
                    : const Color(0xFF9AA0A6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapAiBar extends StatelessWidget {
  const _MapAiBar({
    required this.controller,
    required this.enabled,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        enabled: enabled,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(
          hintText: enabled
              ? "Ask AI about today's route..."
              : 'Open a saved trip to ask AI',
          prefixIcon: const Icon(Icons.auto_awesome_rounded, size: 19),
          suffixIcon: IconButton(
            tooltip: 'Ask AI',
            onPressed: enabled ? onSubmit : null,
            icon: const Icon(Icons.arrow_upward_rounded, size: 19),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDADCE0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDADCE0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
          ),
        ),
      ),
    );
  }
}
