import 'package:flutter/material.dart';

import '../../core/errors/app_error.dart';
import '../../core/localization/app_text.dart';
import '../../core/performance/app_performance.dart';

class UnexpectedErrorView extends StatelessWidget {
  const UnexpectedErrorView({
    required this.error,
    this.compact = false,
    super.key,
  });

  final AppErrorData error;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = _UnexpectedErrorPanel(error: error, compact: compact);
    if (compact) return content;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Material(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnexpectedErrorPanel extends StatefulWidget {
  const _UnexpectedErrorPanel({required this.error, required this.compact});

  final AppErrorData error;
  final bool compact;

  @override
  State<_UnexpectedErrorPanel> createState() => _UnexpectedErrorPanelState();
}

class _UnexpectedErrorPanelState extends State<_UnexpectedErrorPanel> {
  var _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final performance = PerformanceScope.maybeSettingsOf(context);
    final duration = performance.animationsEnabled
        ? performance.transitionDuration
        : Duration.zero;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.sentiment_dissatisfied_rounded,
          size: widget.compact ? 38 : 64,
          color: colors.error,
        ),
        SizedBox(height: widget.compact ? 10 : 18),
        Text(
          appText(
            context,
            'An unexpected error has occurred. Please try again later.',
          ),
          textAlign: widget.compact ? TextAlign.start : TextAlign.center,
          style:
              (widget.compact
                      ? Theme.of(context).textTheme.titleSmall
                      : Theme.of(context).textTheme.titleLarge)
                  ?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (widget.error.code.isNotEmpty) ...[
          const SizedBox(height: 10),
          SelectableText(
            '${appText(context, 'Error code')}: ${widget.error.code}',
            textAlign: widget.compact ? TextAlign.start : TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _showDetails = !_showDetails),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showDetails
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  appText(context, 'Details'),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: duration,
          curve: Curves.easeOut,
          child: !_showDetails
              ? const SizedBox.shrink()
              : Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(14),
                  constraints: BoxConstraints(
                    maxHeight: widget.compact ? 180 : 300,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      widget.error.details,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

Future<void> showUnexpectedErrorDialog(
  BuildContext context,
  Object error, [
  StackTrace? stackTrace,
  String? code,
]) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: UnexpectedErrorView(
            error: AppErrorData.from(error, stackTrace, code),
            compact: true,
          ),
        ),
      ),
    ),
  );
}
