import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/l10n.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/tracking_service.dart';
import '../widgets/order_map.dart';
import '../widgets/plate.dart';
import '../widgets/share_sheet.dart';
import '../widgets/sheet.dart';

/// Кардар жана айдоочу үчүн бир экран.
/// Кардар: карта + жылма панель. Айдоочу: жолго чыкканга чейин ошондой,
/// жолго чыккандан кийин навигация режими (бурулуш баннери, мекен-жай баскычы, астында убакыт/км).
class OrderScreen extends StatefulWidget {
  final Order order;
  final bool isDriver;
  final bool showContacts; // админге да байланыш маалыматы көрүнөт
  const OrderScreen(
      {super.key, required this.order, required this.isDriver, this.showContacts = false});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _svc = TrackingService.instance;
  final _map = MapController();
  bool _follow = true; // карта машинанын артынан жүрөбү
  bool _busy = false;

  Order get _order => widget.order;
  bool get _contacts => widget.isDriver || widget.showContacts;
  bool get _nav => widget.isDriver && _order.status.moving;

  @override
  void initState() {
    super.initState();
    // Айдоочу тиркемени кайра ачса, жолдо турган заказдын GPS'ин улантабыз.
    if (widget.isDriver &&
        _order.status.moving &&
        !_svc.isTracking(_order)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
    _lastStatus = _order.status;
    _order.addListener(_onStatus);
    if (_contacts && (_order.status != OrderStatus.open || widget.showContacts)) {
      _svc.loadContacts(_order);
    }
  }

  OrderStatus? _lastStatus;

  /// Кардарга (жана админге) этап алмашканда кабарлайт.
  void _onStatus() {
    final s = _order.status;
    if (s == _lastStatus) return;
    _lastStatus = s;
    if (widget.isDriver || !mounted) return;
    final key = switch (s) {
      OrderStatus.toPickup => 'msg_topickup',
      OrderStatus.onTheWay => 'msg_picked',
      OrderStatus.delivered => 'delivered_done',
      _ => null,
    };
    if (key != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(key))));
    }
  }

  @override
  void dispose() {
    _order.removeListener(_onStatus);
    super.dispose();
  }

  String _eta(Duration d) => d.inHours > 0
      ? context.tr('eta_hm', {'h': '${d.inHours}', 'm': '${d.inMinutes % 60}'})
      : context.tr('eta_m', {'m': '${d.inMinutes}'});

  String _turnText(RouteStep s) {
    if (s.type == 'arrive') return context.tr('turn_arrive');
    if (s.type.contains('roundabout') || s.type == 'rotary') {
      return context.tr('turn_roundabout');
    }
    return context.tr(switch (s.modifier) {
      'left' => 'turn_left',
      'right' => 'turn_right',
      'slight left' => 'turn_slight_left',
      'slight right' => 'turn_slight_right',
      'sharp left' => 'turn_sharp_left',
      'sharp right' => 'turn_sharp_right',
      'uturn' => 'turn_uturn',
      _ => 'turn_straight',
    });
  }

  String _clock(Duration d) {
    final t = DateTime.now().add(d);
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _zoom(double d) => _map.move(_map.camera.center, _map.camera.zoom + d);

  void _myLocation() {
    setState(() => _follow = true);
    _map.moveAndRotate(_order.position, 16.5, -_order.heading);
  }

  IconData _turnIcon(String mod) => mod.contains('left')
      ? Icons.turn_left
      : mod.contains('right')
          ? Icons.turn_right
          : Icons.straight;

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    String? err;
    try {
      err = await _svc.startTrip(_order).timeout(const Duration(seconds: 40));
    } catch (e) {
      err = 'err_start';
      debugPrint('startTrip катасы: $e');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _follow = true;
    });
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(err))));
    }
  }

  // ---------- кардар / айдоочу (жолго чыкканга чейин) ----------

  Widget _topBar(Order o) => Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          RoundMapButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
          const Spacer(),
          if (o.status != OrderStatus.open && !o.demo) ...[
            RoundMapButton(icon: Icons.share, onTap: () => showShareSheet(context, o.id)),
            const SizedBox(width: 10),
          ],
          Material(
            color: Colors.white,
            elevation: 4,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(o.id, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      );

  Widget _action(Order o) {
    if (o.status == OrderStatus.delivered) {
      return Text(context.tr('delivered_done'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700));
    }
    if (o.status == OrderStatus.open) return const SizedBox.shrink();
    return FilledButton(
      onPressed: _busy ? null : _start,
      child: _busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
          : Text(context.tr('start_trip')),
    );
  }

  Future<void> _call(String phone) async {
    final p = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (p.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: p));
  }

  /// Байланыш адамы: аты, телефону жана чалуу баскычы.
  Widget _contact(String title, String name, String phone, {bool compact = false}) {
    if (name.isEmpty && phone.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.only(top: compact ? 0 : 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.black54, fontSize: 13)),
            Text(name.isEmpty ? phone : name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (name.isNotEmpty && phone.isNotEmpty)
              Text(phone, style: const TextStyle(color: Colors.black54)),
          ]),
        ),
        if (phone.isNotEmpty)
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: Colors.green),
            icon: const Icon(Icons.call, color: Colors.white),
            tooltip: context.tr('call'),
            onPressed: () => _call(phone),
          ),
      ]),
    );
  }

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  /// Этаптардын убактысы — кардар жана админ көрөт.
  Widget _timeline(Order o) {
    final rows = [
      ('tl_started', o.startedAt),
      ('tl_picked', o.pickedAt),
      ('tl_delivered', o.deliveredAt),
    ].where((r) => r.$2 != null).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            const Icon(Icons.check_circle, size: 18, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(child: Text(context.tr(r.$1))),
            Text(_hm(r.$2!), style: const TextStyle(color: Colors.black54)),
          ]),
        ),
    ]);
  }

  Widget _panel(Order o) {
    final onWay = o.status.moving;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(onWay ? _eta(o.eta) : context.statusText(o.status),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        ),
        if (onWay)
          Text('${o.remainingKm.toStringAsFixed(1)} ${context.tr('km')}',
              style: const TextStyle(fontSize: 16, color: Colors.black54)),
      ]),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: o.progress,
          minHeight: 6,
          color: kYellow,
          backgroundColor: const Color(0xFFEAEAEA),
        ),
      ),
      const SizedBox(height: 14),
      Text(o.product, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      Text('${o.seller}\n${o.fromName} → ${o.toName}',
          style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 14),
      if (o.status == OrderStatus.open)
        Text(context.tr('open_hint'), style: const TextStyle(color: Colors.black54))
      else
        VehicleCard(o),
      if (_contacts) ...[
        _contact(context.tr('contact_pickup'), o.fromContactName, o.fromContactPhone),
        _contact(context.tr('contact_receiver'), o.toContactName, o.toContactPhone),
      ],
      const SizedBox(height: 10),
      _timeline(o),
      if (widget.isDriver) ...[const SizedBox(height: 14), _action(o)],
    ]);
  }

  // ---------- навигация режими (айдоочу жолдо) ----------

  Widget _navTurn(Order o) {
    final n = o.nextStep;
    if (n == null) return const SizedBox.shrink();
    final (step, m) = n;
    final d = m >= 1000
        ? '${(m / 1000).toStringAsFixed(1)} ${context.tr('km')}'
        : '${(m / 10).round() * 10} ${context.tr('m')}';
    return Positioned(
      top: 0,
      left: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_turnIcon(step.modifier), size: 38, color: kNavBlue),
              const SizedBox(width: 8),
              Text(d, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            ]),
            Text(_turnText(step), style: const TextStyle(fontSize: 15, color: Colors.black54)),
          ]),
        ),
      ),
    );
  }

  Widget _sideButton(IconData icon, VoidCallback onTap, {bool active = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: active ? kYellow : Colors.white,
          elevation: 4,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(width: 50, height: 50, child: Icon(icon, color: Colors.black)),
          ),
        ),
      );

  Widget _navSide() => Positioned(
        right: 12,
        top: 0,
        bottom: 0,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sideButton(Icons.add, () => _zoom(1)),
            _sideButton(Icons.remove, () => _zoom(-1)),
            _sideButton(Icons.my_location, _myLocation, active: _follow),
          ]),
        ),
      );

  Widget _stat(String big, String small) => Column(children: [
        Text(big, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        Text(small, style: const TextStyle(color: Colors.black54)),
      ]);

  Widget _navBottom(Order o) => Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _stat('${o.eta.inMinutes}', context.tr('stat_min')),
                _stat(_clock(o.eta), context.tr('stat_arrive')),
                _stat(o.remainingKm.toStringAsFixed(1), context.tr('km')),
              ]),
              if (!o.demo && o.roadLoading) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 3, color: kYellow),
              ] else if (!o.demo && !o.roadOk)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(context.tr('road_retry'),
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
              const SizedBox(height: 12),
              if (o.status == OrderStatus.toPickup)
                _contact(context.tr('contact_pickup'), o.fromContactName, o.fromContactPhone,
                    compact: true)
              else
                _contact(context.tr('contact_receiver'), o.toContactName, o.toContactPhone,
                    compact: true),
              const SizedBox(height: 10),
              if (o.status == OrderStatus.toPickup) ...[
                Text('${context.tr('goto_pickup')} ${o.fromName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (o.demo || o.metersToPickup < 200)
                  FilledButton(
                      onPressed: () => _svc.pickedUp(o), child: Text(context.tr('picked_btn')))
                else
                  Text(context.tr('pickup_far'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54)),
              ] else
                FilledButton(
                    onPressed: () => _svc.finishTrip(o), child: Text(context.tr('finish_trip'))),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _order,
        builder: (context, _) {
          final o = _order;
          return Stack(children: [
            Positioned.fill(
              child: OrderMap(
                key: ValueKey(o.id),
                order: o,
                controller: _map,
                nav: _nav,
                follow: _follow,
                onUserMove: () {
                  if (_follow) setState(() => _follow = false);
                },
              ),
            ),
            if (_nav) ...[_navTurn(o), _navSide(), _navBottom(o)] else ...[
              SafeArea(child: _topBar(o)),
              DraggableScrollableSheet(
                initialChildSize: 0.45,
                minChildSize: 0.2,
                maxChildSize: 0.8,
                builder: (context, controller) =>
                    SheetShell(controller: controller, child: _panel(o)),
              ),
            ],
          ]);
        },
      ),
    );
  }
}
