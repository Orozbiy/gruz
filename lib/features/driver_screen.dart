import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../core/tracking_service.dart';
import 'order_screen.dart';

/// Айдоочунун башкы экраны: жаңы (ачык) заказдар — кабыл алуу/кайтаруу,
/// андан соң өзүнүн заказдары. Заказдар аккаунтка байланган.
class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final _svc = TrackingService.instance;
  late final Stream<List<Offer>> _offers = _svc.offers();
  List<Order>? _orders;
  bool _error = false;
  String? _busyOffer;

  @override
  void initState() {
    super.initState();
    _load();
    if (_svc.live) WidgetsBinding.instance.addPostFrameCallback((_) => _syncProfile());
  }

  Future<void> _load() async {
    try {
      final list = await _svc.myOrders();
      if (mounted) {
        setState(() {
          _orders = list;
          _error = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = true);
    }
  }

  bool _complete(List<String> p) =>
      p.length >= 5 && p.take(4).every((s) => s.trim().isNotEmpty);

  /// Профиль бар болсо Firestore'го жазат (админ тизмесинде көрүнүшү үчүн),
  /// жок болсо толтурууну суранат.
  Future<void> _syncProfile() async {
    final p = await Prefs.profile();
    if (_complete(p)) {
      try {
        await _svc.saveDriverProfile(
            name: p[0], phone: p[1], model: p[2], plate: p[3].toUpperCase(), colorName: p[4]);
      } catch (_) {}
    } else {
      await _ensureProfile();
    }
  }

  Future<bool> _ensureProfile() async {
    final p = await Prefs.profile();
    if (_complete(p)) return true;
    if (!mounted) return false;
    final saved = await showDialog<List<String>>(
      context: context,
      builder: (_) => _ProfileDialog(initial: p),
    );
    if (saved == null) return false;
    await Prefs.saveProfile(saved);
    try {
      await _svc.saveDriverProfile(
          name: saved[0],
          phone: saved[1],
          model: saved[2],
          plate: saved[3].toUpperCase(),
          colorName: saved[4]);
    } catch (_) {}
    return true;
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _accept(Offer o) async {
    if (_busyOffer != null) return;
    if (!await _ensureProfile()) return;
    final p = await Prefs.profile();
    if (!mounted) return;
    final denied = context.tr('accept_denied');
    final errTpl = context.tr('accept_err', {'e': '{e}'});
    setState(() => _busyOffer = o.id);
    try {
      final order = await _svc.acceptOffer(
        o.id,
        Vehicle.named(model: p[2], plate: p[3].trim().toUpperCase(), colorName: p[4]),
        Driver(name: p[0], phone: p[1]),
      );
      await _load();
      if (!mounted) return;
      if (order != null) _openOrder(order);
    } on StateError {
      _snack(denied);
    } on FirebaseException catch (e) {
      _snack(e.code == 'permission-denied' ? denied : errTpl.replaceAll('{e}', '${e.message}'));
    } catch (e) {
      _snack(errTpl.replaceAll('{e}', '$e'));
    } finally {
      if (mounted) setState(() => _busyOffer = null);
    }
  }

  Future<void> _decline(Offer o) async {
    final errTpl = context.tr('accept_err', {'e': '{e}'});
    try {
      await _svc.declineOffer(o.id);
    } catch (e) {
      _snack(errTpl.replaceAll('{e}', '$e'));
    }
  }

  void _openOrder(Order o) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => OrderScreen(order: o, isDriver: true)));

  Widget _offerCard(Offer o) {
    final busy = _busyOffer == o.id;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8DC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kYellow, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${o.id} · ${o.product}', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(o.seller, style: const TextStyle(color: Colors.black54)),
        Text('${o.fromName} → ${o.toName}', style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : () => _decline(o),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(context.tr('decline')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: busy ? null : () => _accept(o),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                  : Text(context.tr('accept')),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _heading(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('driver'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            StreamBuilder<List<Offer>>(
              stream: _offers,
              builder: (context, snap) {
                final list = snap.data ?? const <Offer>[];
                if (list.isEmpty) return const SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _heading('${context.tr('offers_title')} (${list.length})'),
                  for (final o in list)
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: _offerCard(o)),
                  const SizedBox(height: 8),
                ]);
              },
            ),
            _heading(context.tr('my_orders')),
            if (_error)
              Column(children: [
                Text(context.tr('orders_load_err'), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextButton(onPressed: _load, child: Text(context.tr('retry'))),
              ])
            else if (orders == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (orders.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.tr('no_orders'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54)),
              )
            else
              for (final o in orders)
                Padding(padding: const EdgeInsets.only(bottom: 10), child: _tile(o)),
          ],
        ),
      ),
    );
  }

  Widget _tile(Order o) => ListenableBuilder(
        listenable: o,
        builder: (context, __) => Material(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openOrder(o),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${o.id} · ${o.product}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${o.fromName} → ${o.toName}',
                        style: const TextStyle(color: Colors.black54)),
                  ]),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(context.statusText(o.status)),
                  backgroundColor: o.status.moving ? kYellow : Colors.white,
                ),
              ]),
            ),
          ),
        ),
      );
}

/// Ташуучунун профили: аты, телефону, машинасы. Заказ кабыл алууда ушул колдонулат.
class _ProfileDialog extends StatefulWidget {
  final List<String> initial;
  const _ProfileDialog({required this.initial});

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final _name = TextEditingController();
  late final _phone = TextEditingController();
  late final _model = TextEditingController();
  late final _plate = TextEditingController();
  String _color = 'Ак';

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name.text = p.isNotEmpty ? p[0] : (AuthService.instance.user?.displayName ?? '');
    if (p.length >= 5) {
      _phone.text = p[1];
      _model.text = p[2];
      _plate.text = p[3];
      if (kVehicleColors.containsKey(p[4])) _color = p[4];
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _model.dispose();
    _plate.dispose();
    super.dispose();
  }

  Widget _f(TextEditingController c, String label,
          {TextInputType? type, TextCapitalization caps = TextCapitalization.sentences}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: type,
          textCapitalization: caps,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  void _save() {
    final v = [_name.text.trim(), _phone.text.trim(), _model.text.trim(), _plate.text.trim()];
    if (v.any((s) => s.isEmpty)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('err_fill_all'))));
      return;
    }
    Navigator.pop(context, [...v, _color]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('reg_title')),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('reg_hint'), style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          _f(_name, context.tr('f_dname')),
          _f(_phone, context.tr('f_phone'), type: TextInputType.phone),
          _f(_model, context.tr('f_model')),
          _f(_plate, context.tr('f_plate'), caps: TextCapitalization.characters),
          Text(context.tr('f_color'), style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in kVehicleColors.entries)
              ChoiceChip(
                avatar: CircleAvatar(backgroundColor: e.value, radius: 9),
                label: Text(context.colorLabel(e.key)),
                selected: _color == e.key,
                selectedColor: kYellow,
                onSelected: (_) => setState(() => _color = e.key),
              ),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('cancel'))),
        TextButton(onPressed: _save, child: Text(context.tr('save'))),
      ],
    );
  }
}
