import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../core/tracking_service.dart';
import '../widgets/order_map.dart';
import '../widgets/plate.dart';
import '../widgets/sheet.dart';

/// Кардар жана айдоочу үчүн бир экран.
/// Кардар: карта + жылма панель. Айдоочу: жолго чыкканга чейин ошондой,
/// жолго чыккандан кийин навигация режими (бурулуш баннери, мекен-жай баскычы, астында убакыт/км).
class OrderScreen extends StatefulWidget {
  final bool isDriver;
  const OrderScreen({super.key, required this.isDriver});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _svc = TrackingService.instance;
  late Order _order = _svc.orders.first;
  var _map = MapController();
  bool _online = false;
  bool _follow = true; // карта машинанын артынан жүрөбү

  bool get _nav => widget.isDriver && _order.status == OrderStatus.onTheWay;

  String _eta(Duration d) =>
      d.inHours > 0 ? '${d.inHours} саат ${d.inMinutes % 60} мүн' : '${d.inMinutes} мүн';

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

  // ---------- кардар / айдоочу (жолго чыкканга чейин) ----------

  Widget _topBar() => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            RoundMapButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
            const Spacer(),
            if (widget.isDriver)
              Material(
                color: Colors.white,
                elevation: 4,
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(children: [
                    Text(_online ? 'Линияда' : 'Эс алуудамын',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Switch(
                      value: _online,
                      activeColor: Colors.black,
                      activeTrackColor: kYellow,
                      onChanged: (v) => setState(() => _online = v),
                    ),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final o in _svc.orders)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(o.id),
                    selected: o == _order,
                    selectedColor: kYellow,
                    backgroundColor: Colors.white,
                    onSelected: (_) => setState(() {
                      _order = o;
                      _map = MapController();
                    }),
                  ),
                ),
            ]),
          ),
        ]),
      );

  Widget _action(Order o) {
    if (o.status == OrderStatus.delivered) {
      return const Text('Жүк жеткирилди ✔',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700));
    }
    if (!_online) {
      return const FilledButton(onPressed: null, child: Text('Алгач линияга чыгыңыз'));
    }
    return FilledButton(
      onPressed: () {
        setState(() => _follow = true);
        _svc.startTrip(o);
      },
      child: const Text('Жолго чыктым'),
    );
  }

  Widget _panel(Order o) {
    final onWay = o.status == OrderStatus.onTheWay;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(onWay ? _eta(o.eta) : o.status.title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        ),
        if (onWay)
          Text('${o.remainingKm.toStringAsFixed(1)} км',
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
      VehicleCard(o),
      if (widget.isDriver) ...[const SizedBox(height: 14), _action(o)],
    ]);
  }

  // ---------- навигация режими (айдоочу жолдо) ----------

  Widget _navTurn(Order o) {
    final n = o.nextStep;
    if (n == null) return const SizedBox.shrink();
    final (step, m) = n;
    final d = m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} км' : '${(m / 10).round() * 10} м';
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
            Text(step.text, style: const TextStyle(fontSize: 15, color: Colors.black54)),
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
                _stat('${o.eta.inMinutes}', 'мүн'),
                _stat(_clock(o.eta), 'келүү'),
                _stat(o.remainingKm.toStringAsFixed(1), 'км'),
              ]),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => _svc.finishTrip(o), child: const Text('Жеткирдим')),
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
              SafeArea(child: _topBar()),
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
