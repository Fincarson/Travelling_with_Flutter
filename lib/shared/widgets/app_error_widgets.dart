import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_error.dart';
import '../../core/localization/app_text.dart';

class PageErrorFallback extends StatelessWidget {
  const PageErrorFallback({required this.error, super.key});

  final AppErrorData error;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_occupiesMostOfPage(context, constraints)) {
          return const SizedBox.shrink();
        }
        return UnexpectedErrorView(error: error);
      },
    );
  }

  bool _occupiesMostOfPage(BuildContext context, BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      return false;
    }

    final viewport = MediaQuery.maybeSizeOf(context);
    if (viewport == null || viewport.isEmpty) {
      return constraints.maxWidth >= 280 && constraints.maxHeight >= 320;
    }

    return constraints.maxWidth >= viewport.width * .72 &&
        constraints.maxHeight >= viewport.height * .55;
  }
}

class UnexpectedErrorView extends StatelessWidget {
  const UnexpectedErrorView({
    required this.error,
    this.compact = false,
    this.showBackButton = true,
    super.key,
  });

  final AppErrorData error;
  final bool compact;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = _UnexpectedErrorPanel(error: error, compact: compact);
    if (compact) return content;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    showBackButton ? 72 : 24,
                    24,
                    24,
                  ),
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
            if (showBackButton)
              Positioned(
                left: 8,
                top: 8,
                child: IconButton(
                  tooltip: appText(context, 'Back'),
                  onPressed: () => _returnWithRouter(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
          ],
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
        if (_showDetails)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(14),
            constraints: BoxConstraints(maxHeight: widget.compact ? 180 : 300),
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
      ],
    );
  }
}

void _returnWithRouter(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  AppErrorController.clear();
  if (router == null) return;

  if (router.canPop()) {
    router.pop();
    return;
  }

  final fallback = _routerFallbackLocation(
    router.routerDelegate.currentConfiguration.uri,
  );
  if (fallback != null) router.go(fallback);
}

String? _routerFallbackLocation(Uri currentUri) {
  final path = currentUri.path;
  if (path == '/') return null;
  if (path == '/notifications' || path.startsWith('/tools/')) return '/';
  if (path.startsWith('/chat/')) return '/chat';
  if (path == '/profile/settings/linked-accounts') {
    return '/profile/settings';
  }
  if (path == '/profile/settings') return '/profile';
  if (path == '/profile/performance' || path == '/profile/archived') {
    return '/profile/settings';
  }
  return '/';
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
