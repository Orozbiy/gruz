import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'models.dart';

/// Демо үчүн: айдоочунун жылышын симуляциялайт.
///
/// Чыныгы тиркемеде бул класс серверге (Firebase Firestore, WebSocket ж.б.)
/// туташып, айдоочунун телефонунан GPS координаталарын алып турат.
/// Экран тарабы өзгөрбөйт — Order.position гана жаңыланат.
class TrackingService {
  TrackingService._() {
    for (final o in orders) {
      o.loadRoad();
    }
  }
  static final TrackingService instance = TrackingService._();

  final List<Order> orders = _demoOrders();
  final Map<String, Timer> _timers = {};

  void startTrip(Order o) {
    if (o.status == OrderStatus.delivered) return;
    o.setStatus(OrderStatus.onTheWay);
    _timers[o.id]?.cancel();
    _timers[o.id] = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (o.progress >= 1) {
        finishTrip(o);
        return;
      }
      o.setProgress(o.progress + 0.005); // ~50 секундда жетет (демо)
    });
  }

  void finishTrip(Order o) {
    _timers.remove(o.id)?.cancel();
    o.setProgress(1);
    o.setStatus(OrderStatus.delivered);
  }
}

List<Order> _demoOrders() => [
      Order(
        id: 'KG-100245',
        product: 'Муздаткыч Samsung, 2 даана',
        seller: 'Дордой Электроника',
        fromName: 'Бишкек, Дордой базары',
        toName: 'Токмок',
        route: const [LatLng(42.9250, 74.6420), LatLng(42.8420, 75.3010)],
        vehicle: const Vehicle(
          model: 'Isuzu',
          plate: '01 KG 482 ABC',
          colorName: 'Ак',
          color: Colors.white,
        ),
        driver: const Driver(name: 'Эрмек', phone: '+996 700 123 456'),
      ),
      Order(
        id: 'KG-100312',
        product: 'Курулуш материалдары, 9 т',
        seller: 'СтройМаркет',
        fromName: 'Бишкек',
        toName: 'Кара-Балта',
        route: const [LatLng(42.8746, 74.5698), LatLng(42.8130, 73.8480)],
        vehicle: const Vehicle(
          model: 'Камаз',
          plate: '01 KG 115 KBA',
          colorName: 'Көк',
          color: Colors.blue,
        ),
        driver: const Driver(name: 'Азамат', phone: '+996 555 987 654'),
      ),
    ];
