import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/auth_service.dart';
import '../core/l10n.dart';

/// Колдонуучунун профили: сүрөтү, аты, email, ID жана чыгуу баскычы.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    // Ачык экрандарды жаап, андан соң чыгабыз — AuthGate кирүү экранын көрсөтөт.
    Navigator.of(context).popUntil((r) => r.isFirst);
    await AuthService.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final u = AuthService.instance.user;
    final photo = u?.photoURL;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 52,
              backgroundColor: const Color(0xFFEAEAEA),
              backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
              child: (photo == null || photo.isEmpty)
                  ? const Icon(Icons.person, size: 52, color: Colors.black54)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          if (u == null) ...[
            Center(
              child: Text(context.tr('demo_user'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(context.tr('demo_user_note'),
                  style: const TextStyle(color: Colors.black54)),
            ),
          ] else ...[
            _row(context.tr('p_name'), (u.displayName ?? '').isEmpty ? '—' : u.displayName!),
            _row(context.tr('p_email'), u.email ?? '—'),
            _uidRow(context, u.uid),
            const SizedBox(height: 28),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.black, foregroundColor: Colors.white),
              onPressed: () => _signOut(context),
              child: Text(context.tr('sign_out')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const Divider(height: 20),
        ]),
      );

  Widget _uidRow(BuildContext context, String uid) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('p_uid'), style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 2),
          Row(children: [
            Expanded(child: SelectableText(uid, style: const TextStyle(fontSize: 14))),
            IconButton(
              tooltip: context.tr('copy'),
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: uid));
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(context.tr('copied'))));
              },
            ),
          ]),
          Text(context.tr('p_uid_hint'),
              style: const TextStyle(fontSize: 12, color: Colors.black45)),
          const Divider(height: 20),
        ]),
      );
}
