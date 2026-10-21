import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'models.dart';

/// Заказдарды жана айдоочунун жайгашуусун башкарат.
///
/// [live] == true  → Firebase Firestore + айдоочунун чыныгы GPS'и.
/// [live] == false → демо режим: Firebase'сиз, айдоочунун жылышы симуляцияланат.
class TrackingService {
  static const _dist = Distance();

  TrackingService._();
  static final TrackingService instance = TrackingService._();

  /// main.dart ичинде Firebase ийгиликтүү туташса true болот.
  bool live = false;

  final Map<String, Order> _orders = {};
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>> _subs = {};
  final Map<String, Timer> _timers = {}; // демо симуляция

  StreamSubscription<Position>? _gps;
  Order? _tripOrder;
  LatLng? _lastPoint;
  double _lastHeading = 0;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('orders');

  // ---------- демо ----------

  List<Order>? _demo;
  List<Order> get demoOrders => _demo ??= _buildDemo();

  List<Order> _buildDemo() {
    final list = _demoOrders();
    for (final o in list) {
      o.loadRoad();
    }
    return list;
  }

  // ---------- заказды ачуу / түзүү ----------

  /// Firestore документинен Order түзүп, жандуу угуп баштайт (кэштелет).
  Order _adopt(String code, Map<String, dynamic> data) {
    final cached = _orders[code];
    if (cached != null) {
      cached.applyRemote(data);
      return cached;
    }
    final o = Order.fromMap(code, data);
    _orders[code] = o;
    o.loadRoad();
    o.applyRemote(data);
    _subs[code] = _col.doc(code).snapshots().listen((s) {
      final d = s.data();
      if (d != null) o.applyRemote(d);
    }, onError: (_) {});
    return o;
  }

  /// Код боюнча заказды табат жана жандуу угат. Табылбаса — null.
  Future<Order?> open(String raw) async {
    final code = raw.trim().toUpperCase();
    if (code.isEmpty) return null;

    if (!live) {
      for (final o in demoOrders) {
        if (o.id == code) return o;
      }
      return null;
    }

    final cached = _orders[code];
    if (cached != null) return cached;

    final snap = await _col.doc(code).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return _adopt(code, data);
  }

  /// Азыркы аккаунт түзгөн заказдар (жаңысы башында).
  Future<List<Order>> myOrders() async {
    if (!live) return demoOrders;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final q = await _col.where('driverUid', isEqualTo: uid).get();
    final docs = q.docs.toList()
      ..sort((a, b) {
        final x = a.data()['createdAt'], y = b.data()['createdAt'];
        return (x is Timestamp && y is Timestamp) ? y.compareTo(x) : 0;
      });
    return [for (final d in docs) _adopt(d.id, d.data())];
  }

  /// Жаңы заказ түзөт (Firestore'го жазат). Заказдын коду кардарга берилет.
  Future<Order> createOrder({
    required String product,
    required String seller,
    required String fromName,
    required String toName,
    required LatLng from,
    required LatLng to,
    required Vehicle vehicle,
    required Driver driver,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Аккаунт менен кирүү керек');

    final rnd = math.Random.secure();
    String code;
    do {
      code = 'KG-${100000 + rnd.nextInt(900000)}';
    } while ((await _col.doc(code).get()).exists);

    final order = Order(
      id: code,
      product: product,
      seller: seller,
      fromName: fromName,
      toName: toName,
      route: [from, to],
      vehicle: vehicle,
      driver: driver,
      driverUid: user.uid,
    );
    await _col.doc(code).set({
      ...order.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return (await open(code))!;
  }

  String _newCodeSeed() => 'KG-${100000 + math.Random.secure().nextInt(900000)}';

  Future<String> _freeCode() async {
    String code;
    do {
      code = _newCodeSeed();
    } while ((await _col.doc(code).get()).exists);
    return code;
  }

  /// АДМИН: ачык заказ түзөт. Аны бардык ташуучулар көрүп, кабыл алат же кайтарат.
  Future<String> createOpenOrder({
    required String product,
    required String seller,
    required String fromName,
    required String toName,
    required LatLng from,
    required LatLng to,
    String fromContactName = '',
    String fromContactPhone = '',
    String toContactName = '',
    String toContactPhone = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Аккаунт менен кирүү керек');
    final code = await _freeCode();
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    // Байланыш номерлери өзүнчө документте: аны админ жана заказды алган ташуучу гана окуйт.
    batch.set(db.collection('orderContacts').doc(code), {
      'fromContact': {'name': fromContactName, 'phone': fromContactPhone},
      'toContact': {'name': toContactName, 'phone': toContactPhone},
    });
    batch.set(_col.doc(code), {
      'product': product,
      'seller': seller,
      'fromName': fromName,
      'toName': toName,
      'from': {'lat': from.latitude, 'lng': from.longitude},
      'to': {'lat': to.latitude, 'lng': to.longitude},
      'status': OrderStatus.open.name,
      'driverUid': '',
      'declinedBy': <String>[],
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return code;
  }

  /// Заказдын байланыш адамдарын жүктөйт (админ жана заказдын ташуучусу үчүн).
  Future<void> loadContacts(Order o) async {
    if (!live || o.demo) return;
    try {
      final d = (await FirebaseFirestore.instance.collection('orderContacts').doc(o.id).get())
          .data();
      if (d == null) return;
      final f = (d['fromContact'] as Map?) ?? const {};
      final t = (d['toContact'] as Map?) ?? const {};
      o.setContacts(
        f['name']?.toString() ?? '',
        f['phone']?.toString() ?? '',
        t['name']?.toString() ?? '',
        t['phone']?.toString() ?? '',
      );
    } catch (_) {}
  }

  /// Ташуучуга көрүнгөн ачык заказдар (өзү кайтарып салгандары жашырылат).
  Stream<List<Offer>> offers() {
    if (!live) return Stream.value(const <Offer>[]);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return _col.where('status', isEqualTo: OrderStatus.open.name).snapshots().map((q) {
      final list = <Offer>[];
      for (final d in q.docs) {
        final m = d.data();
        final declined = (m['declinedBy'] as List?)?.whereType<String>() ?? const <String>[];
        if (uid != null && declined.contains(uid)) continue;
        list.add(Offer.fromMap(d.id, m));
      }
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  /// Заказды кабыл алуу. Биринчи кабыл алган ээлейт: башкасы алып койсо [StateError] ыргытат.
  Future<Order?> acceptOffer(String id, Vehicle vehicle, Driver driver) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Аккаунт менен кирүү керек');
    final ref = _col.doc(id);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || data['status'] != OrderStatus.open.name) {
        throw StateError('taken');
      }
      tx.update(ref, {
        'status': OrderStatus.waiting.name,
        'driverUid': uid,
        'driver': {'name': driver.name, 'phone': driver.phone},
        'vehicle': {
          'model': vehicle.model,
          'plate': vehicle.plate,
          'colorName': vehicle.colorName,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return open(id);
  }

  /// Заказды кайтаруу: ушул ташуучуга гана жашырылат, башкаларда калат.
  Future<void> declineOffer(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _col.doc(id).update({
      'declinedBy': FieldValue.arrayUnion([uid]),
    });
  }

  /// Ташуучунун профилин Firestore'го жазат (админ панелдеги тизме үчүн).
  Future<void> saveDriverProfile({
    required String name,
    required String phone,
    required String model,
    required String plate,
    required String colorName,
    String? status, // 'pending' — каттоодо/кайра жөнөтүүдө гана
  }) async {
    if (!live) return;
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    await FirebaseFirestore.instance.collection('drivers').doc(u.uid).set({
      if (status != null) 'status': status,
      'name': name,
      'phone': phone,
      'model': model,
      'plate': plate,
      'colorName': colorName,
      'email': u.email ?? '',
      'photo': u.photoURL ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Заказ өчүрүлгөндө (админ) жергиликтүү кэшти тазалайт.
  void forget(String code) {
    _subs.remove(code)?.cancel();
    _orders.remove(code);
  }

  /// Аккаунттан чыкканда: бардык угуучуларды жана GPS'ти токтотуп, кэшти тазалайт.
  Future<void> reset() async {
    await _gps?.cancel();
    _gps = null;
    _tripOrder = null;
    for (final s in _subs.values) {
      await s.cancel();
    }
    _subs.clear();
    _orders.clear();
  }

  // ---------- жол ----------

  bool isTracking(Order o) =>
      o.demo ? _timers.containsKey(o.id) : (_tripOrder == o && _gps != null);

  /// Жолго чыгуу. Ката болсо — котормонун ачкычын кайтарат (context.tr менен которулат).
  Future<String?> startTrip(Order o) async {
    if (o.status == OrderStatus.delivered) return null;

    if (o.demo) {
      o.setStatus(OrderStatus.onTheWay);
      _timers[o.id]?.cancel();
      _timers[o.id] = Timer.periodic(const Duration(milliseconds: 250), (t) {
        if (o.progress >= 1) {
          finishTrip(o);
          return;
        }
        o.setProgress(o.progress + 0.005); // ~50 секундда жетет (демо)
      });
      return null;
    }

    // Жайгашууну суроо: өчүк болсо жөндөөнү ачабыз, уруксат жок болсо сурайбыз.
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return 'err_gps_off';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return 'err_loc_denied';
    }

    final resume = o.status.moving; // тиркеме кайра ачылды — этап өзгөрбөйт
    await _gps?.cancel();
    _tripOrder = o;
    _lastPoint = null;

    Position? first;
    try {
      first = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      try {
        first = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }
    if (first != null) o.setLive(LatLng(first.latitude, first.longitude), _lastHeading);

    if (!resume) {
      o.startedAt = DateTime.now();
      o.setStatus(OrderStatus.toPickup);
      _push(o, {
        'status': OrderStatus.toPickup.name,
        'startedAt': FieldValue.serverTimestamp(),
        if (first != null) 'lat': first.latitude,
        if (first != null) 'lng': first.longitude,
        'heading': _lastHeading,
      });
    }

    _gps = Geolocator.getPositionStream(locationSettings: _gpsSettings())
        .listen(_onPosition, onError: (_) {});
    return null;
  }

  /// Ташуучу товарды алды: кардарга "товар алынды, жолго чыкты" деп көрүнөт.
  Future<void> pickedUp(Order o) async {
    o.pickedAt = DateTime.now();
    o.setStatus(OrderStatus.onTheWay);
    if (o.demo) return;
    await _push(o, {
      'status': OrderStatus.onTheWay.name,
      'pickedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Жүк тапшырылды.
  Future<void> finishTrip(Order o) async {
    o.deliveredAt = DateTime.now();
    if (o.demo) {
      _timers.remove(o.id)?.cancel();
      o.setProgress(1);
      o.setStatus(OrderStatus.delivered);
      return;
    }
    if (_tripOrder == o) {
      await _gps?.cancel();
      _gps = null;
      _tripOrder = null;
    }
    o.setStatus(OrderStatus.delivered);
    await _push(o, {
      'status': OrderStatus.delivered.name,
      'deliveredAt': FieldValue.serverTimestamp(),
    });
  }

  void _onPosition(Position p) {
    final o = _tripOrder;
    if (o == null) return;
    final pt = LatLng(p.latitude, p.longitude);

    if (p.speed > 1 && p.heading >= 0) {
      _lastHeading = p.heading;
    } else if (_lastPoint != null && _dist(_lastPoint!, pt) > 5) {
      _lastHeading = (_dist.bearing(_lastPoint!, pt) + 360) % 360;
    }
    _lastPoint = pt;

    o.setLive(pt, _lastHeading);
    _push(o, {'lat': pt.latitude, 'lng': pt.longitude, 'heading': _lastHeading});
  }

  Future<void> _push(Order o, Map<String, dynamic> data) async {
    try {
      await _col.doc(o.id).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('Firestore жазуу катасы: $e');
    }
  }

  LocationSettings _gpsSettings() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          intervalDuration: const Duration(seconds: 3),
          // Фондо да иштеши үчүн — "алдыңкы сервис" билдирмеси.
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Жүгүм кайда?',
            notificationText: 'Жеткирүү жүрүп жатат, жайгашуу жөнөтүлүүдө',
            enableWakeLock: true,
          ),
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: LocationAccuracy.high,
          activityType: ActivityType.automotiveNavigation,
          distanceFilter: 10,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      default:
        return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    }
  }
}

/// Ташуучуга сунушталган ачык заказ.
class Offer {
  final String id, product, seller, fromName, toName;
  final DateTime? createdAt;
  const Offer(this.id, this.product, this.seller, this.fromName, this.toName, this.createdAt);

  factory Offer.fromMap(String id, Map<String, dynamic> m) {
    final t = m['createdAt'];
    return Offer(
      id,
      m['product'] as String? ?? '',
      m['seller'] as String? ?? '',
      m['fromName'] as String? ?? '',
      m['toName'] as String? ?? '',
      t is Timestamp ? t.toDate() : null,
    );
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
        demo: true,
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
        demo: true,
      ),
    ];
