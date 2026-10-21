import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/admin_service.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/tracking_service.dart';
import '../widgets/plate.dart';
import 'order_screen.dart';

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

enum _DrvState { pending, rejected, free, busy, onWay, blocked }

_DrvState _stateOf(AdminDriver d, List<AdminOrder> orders) {
  if (d.status == 'pending') return _DrvState.pending;
  if (d.status == 'rejected') return _DrvState.rejected;
  if (d.blocked) return _DrvState.blocked;
  final mine = orders.where((o) => o.driverUid == d.id);
  if (mine.any((o) => o.status.moving)) return _DrvState.onWay;
  if (mine.any((o) => o.status == OrderStatus.waiting)) return _DrvState.busy;
  return _DrvState.free;
}

String _stateLabel(BuildContext c, _DrvState s) => c.tr(switch (s) {
      _DrvState.pending => 'drv_pending',
      _DrvState.rejected => 'drv_rejected',
      _DrvState.free => 'drv_free',
      _DrvState.busy => 'drv_busy',
      _DrvState.onWay => 'drv_onway',
      _DrvState.blocked => 'drv_blocked',
    });

Color _stateColor(_DrvState s) => switch (s) {
      _DrvState.pending => const Color(0xFFD6E4FF),
      _DrvState.rejected => const Color(0xFFFFD6D6),
      _DrvState.free => const Color(0xFFDFF5E1),
      _DrvState.busy => const Color(0xFFFFF1C2),
      _DrvState.onWay => kYellow,
      _DrvState.blocked => const Color(0xFFFFD6D6),
    };

Widget _avatar(AdminDriver d, {double radius = 22}) => CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEAEAEA),
      backgroundImage: d.photo.isNotEmpty ? NetworkImage(d.photo) : null,
      child: d.photo.isEmpty
          ? Text(d.name.isNotEmpty ? d.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.black87))
          : null,
    );

/// Админ панелдеги "Ташуучулар" табы: тизме, статус, издөө.
class DriversTab extends StatefulWidget {
  const DriversTab({super.key});

  @override
  State<DriversTab> createState() => _DriversTabState();
}

class _DriversTabState extends State<DriversTab> {
  late final Stream<List<AdminDriver>> _drivers = AdminService.instance.drivers();
  late final Stream<List<AdminOrder>> _orders = AdminService.instance.orders();
  String _q = '';

  Widget _stat(String label, int n) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Text('$n', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminDriver>>(
      stream: _drivers,
      builder: (context, ds) {
        if (ds.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.tr('admin_load_err', {'e': '${ds.error}'}),
                  textAlign: TextAlign.center),
            ),
          );
        }
        final all = ds.data;
        if (all == null) return const Center(child: CircularProgressIndicator());
        if (all.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.tr('no_drivers'), textAlign: TextAlign.center),
            ),
          );
        }
        return StreamBuilder<List<AdminOrder>>(
          stream: _orders,
          builder: (context, os) {
            final orders = os.data ?? const <AdminOrder>[];
            final q = _q.trim().toLowerCase();
            final list = q.isEmpty
                ? all
                : all
                    .where((d) =>
                        d.name.toLowerCase().contains(q) ||
                        d.phone.toLowerCase().contains(q) ||
                        d.plate.toLowerCase().contains(q) ||
                        d.email.toLowerCase().contains(q))
                    .toList();
            int count(_DrvState s) => all.where((d) => _stateOf(d, orders) == s).length;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  _stat(context.tr('stat_total'), all.length),
                  const SizedBox(width: 8),
                  _stat(context.tr('drv_pending'), count(_DrvState.pending)),
                  const SizedBox(width: 8),
                  _stat(context.tr('drv_free'), count(_DrvState.free)),
                  const SizedBox(width: 8),
                  _stat(context.tr('drv_onway'), count(_DrvState.onWay)),
                  const SizedBox(width: 8),
                  _stat(context.tr('drv_blocked'), count(_DrvState.blocked)),
                ]),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: context.tr('search'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                for (final d in [
                  ...list.where((d) => d.status == 'pending'),
                  ...list.where((d) => d.status != 'pending'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _tile(context, d, _stateOf(d, orders)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _tile(BuildContext context, AdminDriver d, _DrvState st) => Material(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DriverDetailScreen(driverId: d.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _avatar(d),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.name.isEmpty ? '—' : d.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${d.plate} · ${d.model}',
                      style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  Text(d.phone, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ]),
              ),
              Chip(
                label: Text(_stateLabel(context, st)),
                backgroundColor: _stateColor(st),
              ),
            ]),
          ),
        ),
      );
}

/// Бир ташуучунун толук башкаруусу: маалымат, чалуу, бөгөттөө, заказ дайындоо, заказдары.
class DriverDetailScreen extends StatefulWidget {
  final String driverId;
  const DriverDetailScreen({super.key, required this.driverId});

  @override
  State<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  late final Stream<List<AdminDriver>> _drivers = AdminService.instance.drivers();
  late final Stream<List<AdminOrder>> _orders = AdminService.instance.orders();
  bool _busy = false;

  Future<void> _run(Future<void> Function() job, String okMsg) async {
    setState(() => _busy = true);
    try {
      await job();
      if (mounted) _snack(context, okMsg);
    } catch (e) {
      if (mounted) _snack(context, context.tr('admin_load_err', {'e': '$e'}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBlock(AdminDriver d) async {
    if (!d.blocked) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('drv_block')),
          content: Text(ctx.tr('drv_block_confirm', {'name': d.name})),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('cancel'))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('drv_block'), style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    await _run(() => AdminService.instance.setBlocked(d.id, !d.blocked),
        d.blocked ? context.tr('drv_unblock') : context.tr('drv_blocked'));
  }

  Future<void> _assign(AdminDriver d, List<AdminOrder> orders) async {
    final open = orders.where((o) => o.status == OrderStatus.open).toList();
    final picked = await showDialog<AdminOrder>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.tr('drv_assign_pick')),
        children: open.isEmpty
            ? [Padding(padding: const EdgeInsets.all(20), child: Text(ctx.tr('no_open_orders')))]
            : [
                for (final o in open)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, o),
                    child: Text('${o.id} · ${o.product}\n${o.fromName} → ${o.toName}'),
                  ),
              ],
      ),
    );
    if (picked == null || !mounted) return;
    await _run(() => AdminService.instance.assignOrder(picked.id, d), context.tr('drv_assigned'));
  }

  Future<void> _openMap(AdminOrder r) async {
    try {
      final o = await TrackingService.instance.open(r.id);
      if (o == null || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderScreen(order: o, isDriver: false, showContacts: true)),
      );
    } catch (e) {
      if (mounted) _snack(context, context.tr('err_network'));
    }
  }

  Future<void> _call(String phone) async {
    final p = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (p.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: p));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('driver'))),
      body: StreamBuilder<List<AdminDriver>>(
        stream: _drivers,
        builder: (context, ds) {
          AdminDriver? d;
          for (final x in ds.data ?? const <AdminDriver>[]) {
            if (x.id == widget.driverId) d = x;
          }
          if (d == null) return const Center(child: CircularProgressIndicator());
          final drv = d;
          return StreamBuilder<List<AdminOrder>>(
            stream: _orders,
            builder: (context, os) {
              final all = os.data ?? const <AdminOrder>[];
              final mine = all.where((o) => o.driverUid == drv.id).toList();
              final active = mine
                  .where((o) => o.status == OrderStatus.waiting || o.status.moving)
                  .length;
              final done = mine.where((o) => o.status == OrderStatus.delivered).length;
              final st = _stateOf(drv, all);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(children: [
                    _avatar(drv, radius: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(drv.name.isEmpty ? '—' : drv.name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        Text(drv.email, style: const TextStyle(color: Colors.black54)),
                      ]),
                    ),
                    Chip(label: Text(_stateLabel(context, st)), backgroundColor: _stateColor(st)),
                  ]),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        PlateWidget(drv.plate),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('${drv.model} · ${context.colorLabel(drv.colorName)}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.phone, size: 20),
                        const SizedBox(width: 6),
                        Expanded(child: Text(drv.phone)),
                        IconButton(
                          onPressed: () => _call(drv.phone),
                          tooltip: context.tr('call'),
                          icon: const Icon(Icons.call),
                          style: IconButton.styleFrom(
                              backgroundColor: kYellow, foregroundColor: Colors.black),
                        ),
                      ]),
                      Text(context.tr('drv_stats', {'a': '$active', 'd': '$done'}),
                          style: const TextStyle(color: Colors.black54)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  if (drv.status != 'approved')
                    Row(children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() => AdminService.instance.setStatus(drv.id, 'approved'),
                                  context.tr('drv_approved_msg')),
                          child: Text(context.tr('accept')),
                        ),
                      ),
                      if (drv.status == 'pending') ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _run(
                                    () => AdminService.instance.setStatus(drv.id, 'rejected'),
                                    context.tr('drv_rejected_msg')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: Text(context.tr('drv_reject')),
                          ),
                        ),
                      ],
                    ])
                  else
                  Row(children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy || drv.blocked ? null : () => _assign(drv, all),
                        child: Text(context.tr('drv_assign')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _toggleBlock(drv),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: drv.blocked ? Colors.black : Colors.red,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: Text(context.tr(drv.blocked ? 'drv_unblock' : 'drv_block')),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Text(context.tr('drv_orders'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (mine.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(context.tr('drv_no_orders'),
                          style: const TextStyle(color: Colors.black54)),
                    ),
                  for (final o in mine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openMap(o),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${o.id} · ${o.product}',
                                          style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text('${o.fromName} → ${o.toName}',
                                          style: const TextStyle(color: Colors.black54)),
                                    ]),
                              ),
                              Chip(
                                label: Text(context.statusText(o.status)),
                                backgroundColor:
                                    o.status.moving ? kYellow : Colors.white,
                              ),
                              if (o.status == OrderStatus.waiting)
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () => AdminService.instance.releaseOrder(o.id),
                                          context.tr('drv_released')),
                                  child: Text(context.tr('drv_release')),
                                ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
