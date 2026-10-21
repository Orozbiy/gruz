import 'package:flutter/material.dart';

/// Картанын үстүндөгү тегерек баскыч (артка ж.б.).
class RoundMapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const RoundMapButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.black),
        ),
      ),
    );
  }
}

/// Астынан чыккан ак панель (Яндекс Go сыяктуу).
class SheetShell extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  const SheetShell({super.key, required this.child, this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(blurRadius: 16, color: Colors.black26)],
      ),
      child: ListView(
        controller: controller,
        shrinkWrap: controller == null,
        padding: EdgeInsets.fromLTRB(
            16, 10, 16, 16 + MediaQuery.of(context).padding.bottom),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
