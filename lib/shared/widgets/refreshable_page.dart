import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class RefreshablePage extends StatelessWidget {
  const RefreshablePage({
    required this.child,
    required this.onRefresh,
    this.maxContentWidth = AppSpacing.maxContentWidth,
    super.key,
  });

  final Widget child;
  final Future<void> Function() onRefresh;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = switch (constraints.maxWidth) {
            < AppBreakpoints.compact => AppSpacing.screenCompact,
            < AppBreakpoints.medium => AppSpacing.screenMedium,
            _ => AppSpacing.screenExpanded,
          };

          return ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.stylus,
                PointerDeviceKind.invertedStylus,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.unknown,
              },
            ),
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: AppSpacing.pageVertical,
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
