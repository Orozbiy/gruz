import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';

/// Кыргызча / Русский которгуч.
class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'ky', label: Text('Кыргызча')),
        ButtonSegment(value: 'ru', label: Text('Русский')),
      ],
      selected: {code},
      showSelectedIcon: false,
      onSelectionChanged: (s) => LocaleController.instance.set(s.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: kYellow,
        selectedForegroundColor: Colors.black,
      ),
    );
  }
}
