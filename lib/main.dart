import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/role_screen.dart';

void main() => runApp(const GruzApp());

class GruzApp extends StatelessWidget {
  const GruzApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Жүгүм кайда?',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const RoleScreen(),
      );
}
