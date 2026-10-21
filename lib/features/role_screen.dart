import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'order_screen.dart';

/// Башкы экран: кардар же айдоочу.
class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  void _open(BuildContext c, bool isDriver) => Navigator.push(
      c, MaterialPageRoute(builder: (_) => OrderScreen(isDriver: isDriver)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
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
              const Text('Жүгүм кайда?',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Жүгүңүздү картадан жандуу көрүңүз',
                  style: TextStyle(color: Colors.black54)),
              const Spacer(),
              FilledButton(onPressed: () => _open(context, false), child: const Text('Кардар')),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.black, foregroundColor: Colors.white),
                onPressed: () => _open(context, true),
                child: const Text('Айдоочу'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
