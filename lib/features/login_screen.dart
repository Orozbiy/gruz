import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../widgets/language_switch.dart';

/// Google (Gmail) аккаунту менен кирүү.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await AuthService.instance.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('login_err'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(alignment: Alignment.centerRight, child: LanguageSwitch()),
              const Spacer(),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(color: kYellow, shape: BoxShape.circle),
                  child: const Icon(Icons.local_shipping, size: 56),
                ),
              ),
              const SizedBox(height: 20),
              Text(context.tr('login_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(context.tr('login_sub'),
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
              const Spacer(),
              FilledButton.icon(
                onPressed: _busy ? null : _signIn,
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                    : const Icon(Icons.account_circle),
                label: Text(context.tr('login_google')),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
