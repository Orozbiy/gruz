import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/l10n.dart';
import 'core/theme.dart';
import 'core/tracking_service.dart';
import 'features/login_screen.dart';
import 'features/role_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleController.instance.load();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    TrackingService.instance.live = true;
  } catch (e) {
    // Firebase туташпаса — демо режим (симуляция) менен иштей берет.
    debugPrint('Firebase жок, демо режим: $e');
  }
  runApp(const GruzApp());
}

class GruzApp extends StatelessWidget {
  const GruzApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: LocaleController.instance,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (c) => c.tr('app_name'),
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: LocaleController.instance.locale,
          supportedLocales: const [Locale('ky'), Locale('ru')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const AuthGate(),
        ),
      );
}

/// Аккаунт менен кирген болсо — башкы экран, болбосо — кирүү экраны.
/// Демо режимде (Firebase жок) кирүү талап кылынбайт.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!TrackingService.instance.live) return const RoleScreen();
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snap.data == null ? const LoginScreen() : const RoleScreen();
      },
    );
  }
}
