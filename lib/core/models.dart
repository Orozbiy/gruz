import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// open — админ түзгөн, али ташуучу алган эмес; waiting — ташуучу алды, али баштаган жок;
/// toPickup — ташуучу товарды алганы баратат; onTheWay — товар алынды, кардарга баратат.
enum OrderStatus { open, waiting, toPickup, onTheWay, delivered }

extension OrderStatusX on OrderStatus {
  /// Ташуучу жолдо (товарды алганы баратат же товар менен баратат).
  bool get moving => this == OrderStatus.toPickup || this == OrderStatus.onTheWay;
}

/// Машинанын түсүн тандоо үчүн даяр тизме (Firestore'до түстүн аты сакталат).
const kVehicleColors = <String, Color>{
  'Ак': Colors.white,
  'Кара': Colors.black,
  'Көк': Colors.blue,
  'Кызыл': Colors.red,
  'Боз': Colors.grey,
  'Сары': Colors.yellow,
  'Жашыл': Colors.green,
};

class Vehicle {
  final String model, plate, colorName;
  final Color color;
  const Vehicle({
    required this.model,
    required this.plate,
    required this.colorName,
    required this.color,
  });

  factory Vehicle.named({
    required String model,
    required String plate,
    required String colorName,
  }) =>
      Vehicle(
        model: model,
        plate: plate,
        colorName: colorName,
        color: kVehicleColors[colorName] ?? Colors.grey,
      );
}

class Driver {
  final String name, phone;
  const Driver({required this.name, required this.phone});
}

/// Жолдогу бурулуш: маршруттун башынан канча метрде жана эмне кылуу керек.
class RouteStep {
  final double fromM;
  final String type; // OSRM maneuver type (turn, roundabout, arrive ...)
  final String modifier; // left, right, slight left ...
  const RouteStep(this.fromM, this.type, this.modifier);
}

/// Заказ. Позиция же статус өзгөргөндө бардык угуучуларга билдирет.
///
/// Чыныгы режимде позицияны айдоочунун GPS'и берет ([setLive] / [applyRemote]),
/// демо режимде — симуляция ([setProgress]).
class Order extends ChangeNotifier {
  static const _dist = Distance();

  final String id, product, seller, fromName, toName;
  Vehicle vehicle;
  Driver driver;
  final LatLng from, to;
  String? driverUid;
  final bool demo;
  String fromContactName = '', fromContactPhone = '', toContactName = '', toContactPhone = '';
  DateTime? startedAt, pickedAt, deliveredAt; // этаптардын убактысы
  String _leg = 'trip'; // 'pickup' = ташуучу → алуучу жер; 'trip' = алуучу жер → кардар

  List<LatLng> _route;
  List<double> _cum = [0];
  double _lenM = 0;
  double? _durationS;
  List<RouteStep> steps = [];
  OrderStatus _status = OrderStatus.waiting;
  double _progress = 0; // 0..1

  LatLng? _live; // айдоочунун чыныгы GPS орду
  double _liveHeading = 0;
  int _lastIdx = 0; // маршруттагы акыркы эң жакын чекит

  Order({
    required this.id,
    required this.product,
    required this.seller,
    required this.fromName,
    required this.toName,
    required List<LatLng> route, // башталма чекиттер; кийин чыныгы жол менен алмашат
    required this.vehicle,
    required this.driver,
    this.driverUid,
    this.demo = false,
  })  : _route = route,
        from = route.first,
        to = route.last {
    _index();
  }

  /// Firestore документинен.
  factory Order.fromMap(String id, Map<String, dynamic> m) {
    LatLng pt(String k) {
      final p = m[k] as Map;
      return LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());
    }

    final v = (m['vehicle'] as Map?) ?? const {};
    final d = (m['driver'] as Map?) ?? const {};
    final fc = (m['fromContact'] as Map?) ?? const {};
    final tc = (m['toContact'] as Map?) ?? const {};
    final o = Order(
      id: id,
      product: m['product'] as String? ?? '',
      seller: m['seller'] as String? ?? '',
      fromName: m['fromName'] as String? ?? '',
      toName: m['toName'] as String? ?? '',
      route: [pt('from'), pt('to')],
      vehicle: Vehicle.named(
        model: v['model'] as String? ?? '',
        plate: v['plate'] as String? ?? '',
        colorName: v['colorName'] as String? ?? '',
      ),
      driver: Driver(
        name: d['name'] as String? ?? '',
        phone: d['phone'] as String? ?? '',
      ),
      driverUid: m['driverUid'] as String?,
    );
    o.fromContactName = fc['name']?.toString() ?? '';
    o.fromContactPhone = fc['phone']?.toString() ?? '';
    o.toContactName = tc['name']?.toString() ?? '';
    o.toContactPhone = tc['phone']?.toString() ?? '';
    return o;
  }

  /// Firestore'го жаңы заказды жазуу үчүн.
  Map<String, dynamic> toMap() => {
        'product': product,
        'seller': seller,
        'fromName': fromName,
        'toName': toName,
        'from': {'lat': from.latitude, 'lng': from.longitude},
        'to': {'lat': to.latitude, 'lng': to.longitude},
        'vehicle': {
          'model': vehicle.model,
          'plate': vehicle.plate,
          'colorName': vehicle.colorName,
        },
        'driver': {'name': driver.name, 'phone': driver.phone},
        'driverUid': driverUid,
        'status': OrderStatus.waiting.name,
      };

  List<LatLng> get route => _route;
  OrderStatus get status => _status;
  double get progress => _progress;
  double get totalKm => _lenM / 1000;
  double get remainingKm => totalKm * (1 - _progress);

  void setContacts(String fn, String fp, String tn, String tp) {
    fromContactName = fn;
    fromContactPhone = fp;
    toContactName = tn;
    toContactPhone = tp;
    notifyListeners();
  }

  /// Азыркы орундан товар алынчу жерге чейин (метр).
  double get metersToPickup => _dist(position, from);

  /// Маршрутту этапка жараша алмаштырат (алганы бара жатат / кардарга бара жатат).
  void _ensureLeg() {
    if (_status == OrderStatus.toPickup && _leg != 'pickup' && _live != null) {
      _leg = 'pickup';
      _resetRoute([_live!, from]);
      prefetchTrip();
    } else if (_status == OrderStatus.onTheWay && _leg != 'trip') {
      _leg = 'trip';
      _resetRoute([from, to]);
    }
  }

  void _resetRoute(List<LatLng> pts) {
    _route = pts;
    steps = [];
    _durationS = null;
    _progress = 0;
    _lastIdx = 0;
    _index();
    _project();
    loadRoad();
  }

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

  /// Чыныгы GPS ордун маршрутка проекциялап, өтүлгөн жолду (progress) эсептейт.
  void _project() {
    final p = _live;
    if (p == null || _route.length < 2 || _lenM <= 0) return;
    var best = _lastIdx;
    var bestD = double.infinity;
    for (var i = math.max(0, _lastIdx - 30); i < _route.length; i++) {
      final d = _dist(p, _route[i]);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    _lastIdx = best;
    _progress = (_cum[best] / _lenM).clamp(0.0, 1.0);
  }

  /// Машинанын азыркы орду.
  LatLng get position => _status == OrderStatus.delivered
      ? _route.last
      : (_live ?? _pointAtM(_progress * _lenM));

  /// Өтпөй калган маршрут (навигация режиминде көрсөтүлөт).
  List<LatLng> get remainingRoute {
    final m = _progress * _lenM;
    final i = _cum.indexWhere((c) => c > m);
    return i < 0 ? [_route.last] : [position, ..._route.sublist(i)];
  }

  /// Машинанын багыты (градус, түндүк = 0) — жебе ушул боюнча бурулат.
  double get heading {
    if (_live != null) return _liveHeading;
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

  // ---------- демо ----------

  void setProgress(double p) {
    _progress = p.clamp(0.0, 1.0);
    notifyListeners();
  }

  // ---------- чыныгы режим ----------

  /// Айдоочунун телефонунан келген жаңы GPS орду.
  void setLive(LatLng p, double heading) {
    _live = p;
    _liveHeading = heading;
    _ensureLeg();
    _project();
    // Маршрут жүктөлө элек болсо кайра аракет (10 секунд сайын).
    if (_status.moving &&
        !roadOk &&
        !roadLoading &&
        _lastRoadTry != null &&
        DateTime.now().difference(_lastRoadTry!) > const Duration(seconds: 10)) {
      loadRoad();
    }
    notifyListeners();
  }

  /// Firestore'дон келген жаңыртуу (статус + айдоочунун орду).
  void applyRemote(Map<String, dynamic> m) {
    final st = m['status'] as String?;
    _status = OrderStatus.values.firstWhere((e) => e.name == st, orElse: () => _status);
    final v = m['vehicle'];
    if (v is Map) {
      vehicle = Vehicle.named(
        model: v['model'] as String? ?? '',
        plate: v['plate'] as String? ?? '',
        colorName: v['colorName'] as String? ?? '',
      );
    }
    final d = m['driver'];
    if (d is Map) {
      driver = Driver(name: d['name'] as String? ?? '', phone: d['phone'] as String? ?? '');
    }
    final du = m['driverUid'];
    if (du is String && du.isNotEmpty) driverUid = du;
    final lat = (m['lat'] as num?)?.toDouble();
    final lng = (m['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      _live = LatLng(lat, lng);
      _liveHeading = (m['heading'] as num?)?.toDouble() ?? _liveHeading;
      _ensureLeg();
      _project();
    }
    _ensureLeg();
    DateTime? t(String k) {
      final v = m[k];
      if (v == null) return null;
      try {
        return (v as dynamic).toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    startedAt = t('startedAt') ?? startedAt;
    pickedAt = t('pickedAt') ?? pickedAt;
    deliveredAt = t('deliveredAt') ?? deliveredAt;
    if (_status == OrderStatus.delivered) {
      _live = null;
      _progress = 1;
    }
    notifyListeners();
  }

  void setStatus(OrderStatus s) {
    _status = s;
    _ensureLeg();
    if (s == OrderStatus.delivered) {
      _live = null;
      _progress = 1;
    }
    notifyListeners();
  }

  static const _osrmHosts = [
    'router.project-osrm.org/route/v1/driving',
    'routing.openstreetmap.de/routed-car/route/v1/driving',
  ];

  Map? _tripRoad; // алдын ала жүктөлгөн "товар алуучу жер → кардар" маршруту
  bool roadLoading = false, roadOk = false;
  DateTime? _lastRoadTry;

  /// Эки OSRM сервери менен 4 жолу аракет кылат (бири жооп бербесе экинчиси).
  Future<Map?> _fetchRoad(List<LatLng> pts) async {
    final c = pts.map((p) => '${p.longitude},${p.latitude}').join(';');
    for (var i = 0; i < 4; i++) {
      try {
        final uri = Uri.parse('https://${_osrmHosts[i % 2]}/$c'
            '?overview=full&geometries=geojson&steps=true');
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final rs = (jsonDecode(res.body) as Map)['routes'] as List?;
          if (rs != null && rs.isNotEmpty) return rs.first as Map;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Товар алганга чейин эле кардарга чейинки жолду даярдап коёт (тез алмашуу үчүн).
  Future<void> prefetchTrip() async {
    if (_tripRoad != null) return;
    _tripRoad = await _fetchRoad([from, to]);
  }

  /// OSRM'ден чыныгы жол маршрутун жана бурулуштарды алат (интернет керек).
  /// Ката болсо — түз сызык менен калат, бирок кийин өзү кайра аракет кылат.
  Future<void> loadRoad() async {
    final mine = _route;
    roadLoading = true;
    roadOk = false;
    _lastRoadTry = DateTime.now();
    notifyListeners();
    final isTrip = mine.length == 2 && mine.first == from && mine.last == to;
    final r = (isTrip && _tripRoad != null) ? _tripRoad : await _fetchRoad(mine);
    if (!identical(_route, mine)) return; // ортодо маршрут алмашты — эски жооп керек эмес
    roadLoading = false;
    if (r == null) {
      notifyListeners();
      return;
    }
    try {
      if (isTrip) _tripRoad = r;
      _applyRoad(r);
      roadOk = true;
    } catch (_) {}
    notifyListeners();
  }

  void _applyRoad(Map r) {
    _route = [
      for (final p in r['geometry']['coordinates'] as List)
        LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble())
    ];
    _durationS = (r['duration'] as num).toDouble();
    _index();
    _lastIdx = 0;
    _project();
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
          steps.add(RouteStep(from * scale, type, mod));
        }
        from += (s['distance'] as num).toDouble();
      }
    }
  }
}
