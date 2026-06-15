part of travel_agent_app;

class PerformanceSettingsScreen extends StatelessWidget {
  const PerformanceSettingsScreen({
    required this.onBack,
    required this.onSettingsChanged,
    super.key,
  });

  final VoidCallback onBack;
  final Future<void> Function(AppPerformanceSettings settings)
  onSettingsChanged;

  Future<void> _update(
    BuildContext context,
    AppPerformanceSettings settings,
  ) async {
    final controller = PerformanceScope.of(context);
    await controller.update(settings);
    await onSettingsChanged(settings);
  }

  @override
  Widget build(BuildContext context) {
    final controller = PerformanceScope.of(context);
    final settings = controller.settings;

    return ScreenScaffold(
      child: ListView(
        padding: _responsivePagePadding(context, top: 18),
        children: [
          TopBar(title: 'Performance', onBack: onBack),
          const SizedBox(height: 18),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LabelText('Preset'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in const [
                      PerformancePreset.high,
                      PerformancePreset.balanced,
                      PerformancePreset.batterySaver,
                    ])
                      ChoiceChip(
                        label: Text(appText(context, preset.label)),
                        selected: settings.preset == preset,
                        selectedColor: _accent,
                        labelStyle: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w900,
                        ),
                        onSelected: (_) => unawaited(
                          _update(
                            context,
                            AppPerformanceSettings.forPreset(preset),
                          ),
                        ),
                      ),
                    if (settings.preset == PerformancePreset.custom)
                      const SmallPill(label: 'Custom'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _PerformanceImpactCard(settings: settings),
          const SizedBox(height: 12),
          _AdvancedPerformancePanel(onSettingsChanged: _update),
        ],
      ),
    );
  }
}

class _PerformanceImpactCard extends StatelessWidget {
  const _PerformanceImpactCard({required this.settings});

  final AppPerformanceSettings settings;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelText('Current behavior'),
          const SizedBox(height: 12),
          ResponsiveSplit(
            breakpoint: 520,
            children: [
              StatCard(
                title: 'Power',
                value: settings.estimatedPowerUse,
                detail: 'Estimated impact',
                trailing: Icons.battery_charging_full_rounded,
              ),
              StatCard(
                title: 'Motion',
                value: settings.motionLevel.label,
                detail: settings.frameRatePreference.label,
                trailing: Icons.speed_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            appText(context, settings.framePolicy),
            style: const TextStyle(
              color: _secondary,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvancedPerformancePanel extends StatelessWidget {
  const _AdvancedPerformancePanel({required this.onSettingsChanged});

  final Future<void> Function(
    BuildContext context,
    AppPerformanceSettings settings,
  )
  onSettingsChanged;

  @override
  Widget build(BuildContext context) {
    final settings = PerformanceScope.of(context).settings;

    return GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Row(
              children: [
                const IconBadge(icon: Icons.tune_rounded, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    appText(context, 'Advanced'),
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _EnumDropdownTile<MotionLevel>(
            title: 'Animations',
            value: settings.motionLevel,
            values: MotionLevel.values,
            labelFor: (value) => value.label,
            onChanged: (value) => onSettingsChanged(
              context,
              settings.copyWith(
                preset: PerformancePreset.custom,
                motionLevel: value,
              ),
            ),
          ),
          _EnumDropdownTile<FrameRatePreference>(
            title: 'Frame pacing',
            value: settings.frameRatePreference,
            values: FrameRatePreference.values,
            labelFor: (value) => value.label,
            onChanged: (value) => onSettingsChanged(
              context,
              settings.copyWith(
                preset: PerformancePreset.custom,
                frameRatePreference: value,
              ),
            ),
          ),
          _EnumDropdownTile<ImageQualityPreference>(
            title: 'Image quality',
            value: settings.imageQuality,
            values: ImageQualityPreference.values,
            labelFor: (value) => value.label,
            onChanged: (value) => onSettingsChanged(
              context,
              settings.copyWith(
                preset: PerformancePreset.custom,
                imageQuality: value,
              ),
            ),
          ),
          _SwitchTile(
            title: 'Cache pages',
            subtitle: 'Keep tab pages alive instead of rebuilding from zero.',
            value: settings.cachePages,
            onChanged: (value) => onSettingsChanged(
              context,
              settings.copyWith(
                preset: PerformancePreset.custom,
                cachePages: value,
              ),
            ),
          ),
          _SwitchTile(
            title: 'Repaint isolation',
            subtitle: 'Wrap major pages in repaint boundaries.',
            value: settings.isolateRepaints,
            onChanged: (value) => onSettingsChanged(
              context,
              settings.copyWith(
                preset: PerformancePreset.custom,
                isolateRepaints: value,
              ),
            ),
          ),
          _SwitchTile(
            title: 'Heavy visual effects',
            subtitle: 'Allow decorative animated visuals when enabled.',
            value: settings.heavyVisualEffects,
            onChanged: (value) => onSettingsChanged(
              context,
              settings.copyWith(
                preset: PerformancePreset.custom,
                heavyVisualEffects: value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnumDropdownTile<T> extends StatelessWidget {
  const _EnumDropdownTile({
    required this.title,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final Future<void> Function(T value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(labelText: appText(context, title)),
        items: values
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(appText(context, labelFor(item))),
              ),
            )
            .toList(),
        onChanged: (next) {
          if (next != null) unawaited(onChanged(next));
        },
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Future<void> Function(bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: (next) => unawaited(onChanged(next)),
      title: Text(
        appText(context, title),
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        appText(context, subtitle),
        style: const TextStyle(
          color: _secondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      activeThumbColor: _primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    );
  }
}
