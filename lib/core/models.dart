import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

enum OrderStatus { waiting, onTheWay, delivered }

extension OrderStatusText on OrderStatus {
  String get title => switch (this) {
        OrderStatus.waiting => 'Жөнөтүүгө даярдалууда',
        OrderStatus.onTheWay => 'Жолдо',
        OrderStatus.delivered => 'Жеткирилди',
      };
}

class Vehicle {
  final String model, plate, colorName;
  final Color color;
  const Vehicle({
    required this.model,
    required this.plate,
    required this.colorName,
    required this.color,
  });
}

class Driver {
  final String name, phone;
  const Driver({required this.name, required this.phone});
}

/// Жолдогу бурулуш: маршруттун башынан канча метрде жана эмне кылуу керек.
class RouteStep {
  final double fromM;
  final String text;
  final String modifier;
  const RouteStep(this.fromM, this.text, this.modifier);
}

/// Заказ. Позиция же статус өзгөргөндө бардык угуучуларга билдирет.
class Order extends ChangeNotifier {
  static const _dist = Distance();

  final String id, product, seller, fromName, toName;
  final Vehicle vehicle;
  final Driver driver;

  List<LatLng> _route;
  List<double> _cum = [0];
  double _lenM = 0;
  double? _durationS;
  List<RouteStep> steps = [];
  OrderStatus _status = OrderStatus.waiting;
  double _progress = 0; // 0..1

  Order({
    required this.id,
    required this.product,
    required this.seller,
    required this.fromName,
    required this.toName,
    required List<LatLng> route, // башталма чекиттер; кийин чыныгы жол менен алмашат
    required this.vehicle,
    required this.driver,
  }) : _route = route {
    _index();
  }

  List<LatLng> get route => _route;
  OrderStatus get status => _status;
  double get progress => _progress;
  double get totalKm => _lenM / 1000;
  double get remainingKm => totalKm * (1 - _progress);

  Duration get eta => Duration(
      seconds: _durationS != null
          ? (_durationS! * (1 - _progress)).round()
          : (remainingKm / 50 * 3600).round());

  void _index() {
    _cum = [0];
    for (var i = 0; i < _route.length - 1; i++) {
      _cum.add(_cum.last + _dist(_route[i], _route[i + 1]));
    }
    _lenM = _cum.last;
  }

  LatLng _pointAtM(double m) {
    if (_route.length < 2 || m <= 0) return _route.first;
    if (m >= _lenM) return _route.last;
    for (var i = 1; i < _cum.length; i++) {
      if (m <= _cum[i]) {
        final seg = _cum[i] - _cum[i - 1];
        final f = seg == 0 ? 0.0 : (m - _cum[i - 1]) / seg;
        final a = _route[i - 1], b = _route[i];
        return LatLng(a.latitude + (b.latitude - a.latitude) * f,
            a.longitude + (b.longitude - a.longitude) * f);
      }
    }
    return _route.last;
  }

  /// Машинанын азыркы орду.
  LatLng get position => _pointAtM(_progress * _lenM);

  /// Өтпөй калган маршрут (навигация режиминде көрсөтүлөт).
  List<LatLng> get remainingRoute {
    final m = _progress * _lenM;
    final i = _cum.indexWhere((c) => c > m);
    return i < 0 ? [_route.last] : [position, ..._route.sublist(i)];
  }

  /// Машинанын багыты (градус, түндүк = 0) — жебе ушул боюнча бурулат.
  double get heading {
    final m = _progress * _lenM;
    final a = _pointAtM(math.max(0, m - 15));
    final b = _pointAtM(math.min(_lenM, m + 15));
    return a == b ? 0 : _dist.bearing(a, b);
  }

  /// Кийинки бурулуш жана ага чейинки аралык (метр).
  (RouteStep, double)? get nextStep {
    final m = _progress * _lenM;
    for (final s in steps) {
      if (s.fromM > m + 1) return (s, s.fromM - m);
    }
    return null;
  }

  void setProgress(double p) {
    _progress = p.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setStatus(OrderStatus s) {
    _status = s;
    notifyListeners();
  }

  /// OSRM'ден чыныгы жол маршрутун жана бурулуштарды алат (интернет керек).
  /// Ката болсо — түз сызык менен калат.
  Future<void> loadRoad() async {
    try {
      final c = _route.map((p) => '${p.longitude},${p.latitude}').join(';');
      final uri = Uri.parse('https://router.project-osrm.org/route/v1/driving/$c'
          '?overview=full&geometries=geojson&steps=true');
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final r = (jsonDecode(res.body)['routes'] as List).first as Map;
      _route = [
        for (final p in r['geometry']['coordinates'] as List)
          LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble())
      ];
      _durationS = (r['duration'] as num).toDouble();
      _index();
      final scale = _lenM / ((r['distance'] as num).toDouble());
      var from = 0.0;
      steps = [];
      for (final leg in r['legs'] as List) {
        for (final s in leg['steps'] as List) {
          final man = s['maneuver'] as Map;
          final type = man['type'] as String;
          final mod = (man['modifier'] as String?) ?? 'straight';
          if (type == 'arrive' ||
              type.contains('roundabout') ||
              type == 'rotary' ||
              (type != 'depart' && mod != 'straight')) {
            steps.add(RouteStep(from * scale, _turnText(type, mod), mod));
          }
          from += (s['distance'] as num).toDouble();
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  static String _turnText(String type, String mod) {
    if (type == 'arrive') return 'Жеткен жериңиз';
    if (type.contains('roundabout') || type == 'rotary') return 'Айлампадан чык';
    return switch (mod) {
      'left' => 'Солго бурул',
      'right' => 'Оңго бурул',
      'slight left' => 'Бир аз солго',
      'slight right' => 'Бир аз оңго',
      'sharp left' => 'Катуу солго бурул',
      'sharp right' => 'Катуу оңго бурул',
      'uturn' => 'Артка бурул',
      _ => 'Түз жүр',
    };
  }
}
