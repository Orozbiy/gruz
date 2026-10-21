import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../core/tracking_service.dart';
import 'admin_screen.dart';
import 'customer_screen.dart';
import 'driver_gate.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Башкы экран: кардар же айдоочу. Сол жогорку бурчта — админ иконкасы,
/// ылдыйда — Профиль жана Жөндөөлөр.
class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  void _open(BuildContext c, Widget screen) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => screen));

  Widget _adminButton(BuildContext context) => Tooltip(
        message: context.tr('admin'),
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => openAdminPanel(context),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(Icons.admin_panel_settings, size: 30),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _smallButton(BuildContext context, IconData icon, String label, Widget screen) =>
      Expanded(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: Colors.black,
            side: const BorderSide(color: Colors.black26),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () => _open(context, screen),
          icon: Icon(icon),
          label: Text(label),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final live = TrackingService.instance.live;
    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(color: kYellow, shape: BoxShape.circle),
                  child: const Icon(Icons.local_shipping, size: 56),
                ),
                const SizedBox(height: 20),
                Text(context.tr('app_name'),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(context.tr('tagline'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54)),
                if (!live) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(context.tr('demo_banner'), textAlign: TextAlign.center),
                  ),
                ],
                const Spacer(),
                FilledButton(
                    onPressed: () => _open(context, const CustomerScreen()),
                    child: Text(context.tr('customer'))),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.black, foregroundColor: Colors.white),
                  onPressed: () => _open(context, const DriverGate()),
                  child: Text(context.tr('driver')),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  _smallButton(context, Icons.person, context.tr('profile'), const ProfileScreen()),
                  const SizedBox(width: 12),
                  _smallButton(
                      context, Icons.settings, context.tr('settings'), const SettingsScreen()),
                ]),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Positioned(top: 12, left: 12, child: _adminButton(context)),
        ]),
      ),
    );
  }
}
