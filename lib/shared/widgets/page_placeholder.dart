import 'package:flutter/material.dart';

import 'responsive_page.dart';

class PagePlaceholder extends StatelessWidget {
  const PagePlaceholder({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ResponsivePage(
      child: Center(
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium,
        ),
      ),
    );
  }
}
