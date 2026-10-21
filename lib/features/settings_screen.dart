import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../widgets/language_switch.dart';

const kAppVersion = '0.3.0';

/// Жөндөөлөр: тил жана тиркеме тууралуу.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(context.tr('lang'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          const LanguageSwitch(),
          const SizedBox(height: 32),
          Text(context.tr('about'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(context.tr('app_name'), style: const TextStyle(fontSize: 16)),
          Text(context.tr('version', {'v': kAppVersion}),
              style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
