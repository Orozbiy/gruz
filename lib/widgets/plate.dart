import 'package:flutter/material.dart';

import '../core/models.dart';

/// Мамлекеттик номер белгиси сымал виджет.
class PlateWidget extends StatelessWidget {
  final String plate;
  const PlateWidget(this.plate, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        plate,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

/// Машина, гос номер, түсү жана айдоочу тууралуу карточка.
class VehicleCard extends StatelessWidget {
  final Order order;
  const VehicleCard(this.order, {super.key});

  @override
  Widget build(BuildContext context) {
    final v = order.vehicle;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PlateWidget(v.plate),
            const Spacer(),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: v.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black54),
              ),
            ),
            const SizedBox(width: 6),
            Text('${v.model}, ${v.colorName} түстө',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.person, size: 20),
            const SizedBox(width: 6),
            Text('Айдоочу: ${order.driver.name}'),
            const Spacer(),
            const Icon(Icons.phone, size: 18),
            const SizedBox(width: 4),
            SelectableText(order.driver.phone),
          ],
        ),
      ],
      ),
    );
  }
}
