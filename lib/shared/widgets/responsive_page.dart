import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    required this.child,
    this.maxContentWidth = AppSpacing.maxContentWidth,
    super.key,
  });

  final Widget child;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = switch (constraints.maxWidth) {
            < 360 => 12.0,
            < AppBreakpoints.compact => AppSpacing.screenCompact,
            < AppBreakpoints.medium => AppSpacing.screenMedium,
            _ => AppSpacing.screenExpanded,
          };

          return Center(
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
          );
        },
      ),
    );
  }
}
