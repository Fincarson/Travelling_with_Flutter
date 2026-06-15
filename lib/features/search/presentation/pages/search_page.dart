import 'package:flutter/material.dart';

import '../../../../core/localization/app_text.dart';
import '../../../../shared/widgets/page_placeholder.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PagePlaceholder(title: appText(context, 'Search page'));
  }
}
