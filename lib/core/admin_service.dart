import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';

import 'models.dart';
import 'tracking_service.dart';

enum AdminCheck { ok, wrong, denied, notSetup }

/// Админ панелдеги заказдын кыскача сабы.
class AdminOrder {
  final String id, product, fromName, toName, driverName, driverUid;
  final OrderStatus status;
  final int declinedCount;
  const AdminOrder({
    required this.id,
    required this.product,
    required this.fromName,
    required this.toName,
    required this.driverName,
    required this.status,
    this.driverUid = '',
    this.declinedCount = 0,
  });

  factory AdminOrder.fromMap(String id, Map<String, dynamic> m) {
    final st = m['status'] as String?;
    return AdminOrder(
      id: id,
      product: m['product'] as String? ?? '',
      fromName: m['fromName'] as String? ?? '',
      toName: m['toName'] as String? ?? '',
      driverName: ((m['driver'] as Map?)?['name'] as String?) ?? '',
      driverUid: m['driverUid'] as String? ?? '',
      declinedCount: (m['declinedBy'] as List?)?.length ?? 0,
      status: OrderStatus.values.firstWhere((e) => e.name == st, orElse: () => OrderStatus.waiting),
    );
  }

  factory AdminOrder.fromOrder(Order o) => AdminOrder(
        id: o.id,
        product: o.product,
        fromName: o.fromName,
        toName: o.toName,
        driverName: o.driver.name,
        status: o.status,
      );
}

/// Админ панелдеги ташуучу (drivers/{uid}).
class AdminDriver {
  final String id, name, phone, model, plate, colorName, email, photo;
  final String status; // pending | approved | rejected
  final bool blocked;
  const AdminDriver({
    required this.id,
    required this.name,
    required this.phone,
    required this.model,
    required this.plate,
    required this.colorName,
    required this.email,
    required this.photo,
    required this.blocked,
    this.status = 'pending',
  });

  factory AdminDriver.fromMap(String id, Map<String, dynamic> m) => AdminDriver(
        id: id,
        name: m['name']?.toString() ?? '',
        phone: m['phone']?.toString() ?? '',
        model: m['model']?.toString() ?? '',
        plate: m['plate']?.toString() ?? '',
        colorName: m['colorName']?.toString() ?? '',
        email: m['email']?.toString() ?? '',
        photo: m['photo']?.toString() ?? '',
        blocked: m['blocked'] == true,
        status: m['status']?.toString() ?? 'pending',
      );
}

class AppUser {
  final String id, name, email, photo;
  const AppUser(this.id, this.name, this.email, this.photo);
}

/// Админ панелдин маалыматы.
///
/// Коопсуздук: паролду туура киргизген аккаунт гана (Firestore эрежелери текшерет)
/// бардык заказдарды жана колдонуучуларды окуй алат.
class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  static const demoPassword = '1234';

  bool get _live => TrackingService.instance.live;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Паролду текшерет. Пароль телефондо сакталбайт жана тиркемеде жок:
  /// аны Firestore эрежелери `config/admin` менен салыштырат. Туура болсо
  /// `admins/{uid}` документи түзүлөт (админ укугу), болбосо permission-denied.
  Future<AdminCheck> check(String password) async {
    if (!_live) {
      return password == demoPassword ? AdminCheck.ok : AdminCheck.wrong;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return AdminCheck.denied;
    try {
      await _db.collection('admins').doc(uid).set({'password': password});
      return AdminCheck.ok;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return AdminCheck.wrong;
      rethrow;
    }
  }

  /// Жаңы пароль коюу. Эски пароль менен киргендердин укугу автоматтык түрдө жоголот.
  Future<void> changePassword(String password) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('config').doc('admin').set({'password': password});
    await _db.collection('admins').doc(uid).set({'password': password});
  }

  List<AdminOrder> demoRows() =>
      [for (final o in TrackingService.instance.demoOrders) AdminOrder.fromOrder(o)];

  Stream<List<AdminOrder>> orders() {
    if (!_live) {
      return Stream.periodic(const Duration(seconds: 1), (_) => demoRows());
    }
    return _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((q) => [for (final d in q.docs) AdminOrder.fromMap(d.id, d.data())]);
  }

  Stream<List<AppUser>> users() {
    if (!_live) return Stream.value(const <AppUser>[]);
    return _db
        .collection('users')
        .orderBy('lastLogin', descending: true)
        .limit(200)
        .snapshots()
        .map((q) => [
              for (final d in q.docs)
                AppUser(
                  d.id,
                  d.data()['name']?.toString() ?? '',
                  d.data()['email']?.toString() ?? '',
                  d.data()['photo']?.toString() ?? '',
                )
            ]);
  }

  Stream<List<AdminDriver>> drivers() {
    if (!_live) return Stream.value(const <AdminDriver>[]);
    return _db.collection('drivers').snapshots().map((q) {
      final list = [for (final d in q.docs) AdminDriver.fromMap(d.id, d.data())];
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  /// Заявканы кабыл алуу ('approved') же четке кагуу ('rejected').
  Future<void> setStatus(String uid, String status) =>
      _db.collection('drivers').doc(uid).update({'status': status});

  Future<void> setBlocked(String uid, bool blocked) =>
      _db.collection('drivers').doc(uid).update({'blocked': blocked});

  /// Ачык заказды түз эле ташуучуга дайындайт.
  Future<void> assignOrder(String orderId, AdminDriver d) =>
      _db.collection('orders').doc(orderId).update({
        'status': OrderStatus.waiting.name,
        'driverUid': d.id,
        'driver': {'name': d.name, 'phone': d.phone},
        'vehicle': {'model': d.model, 'plate': d.plate, 'colorName': d.colorName},
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Дайындалган (али жолго чыкпаган) заказды кайра ачык кылат.
  Future<void> releaseOrder(String orderId) =>
      _db.collection('orders').doc(orderId).update({
        'status': OrderStatus.open.name,
        'driverUid': '',
        'driver': FieldValue.delete(),
        'vehicle': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteOrder(String id) async {
    await _db.collection('orders').doc(id).delete();
    TrackingService.instance.forget(id);
  }
}
