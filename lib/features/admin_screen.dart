import 'package:flutter/material.dart';

import '../core/admin_service.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/tracking_service.dart';
import 'admin_drivers.dart';
import 'admin_new_order_screen.dart';
import 'order_screen.dart';

void _snack(BuildContext c, String t) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t)));

/// Башкы экрандагы админ иконкасы басылганда: пароль сурайт, туура болсо панелди ачат.
Future<void> openAdminPanel(BuildContext context) async {
  final pw = await showDialog<String>(
    context: context,
    builder: (_) => const _PasswordDialog(),
  );
  if (pw == null || !context.mounted) return;
  try {
    final r = await AdminService.instance.check(pw);
    if (!context.mounted) return;
    switch (r) {
      case AdminCheck.ok:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
      case AdminCheck.wrong:
        _snack(context, context.tr('admin_wrong'));
      case AdminCheck.denied:
        _snack(context, context.tr('admin_denied'));
      case AdminCheck.notSetup:
        _snack(context, context.tr('admin_not_setup'));
    }
  } catch (e) {
    if (context.mounted) _snack(context, context.tr('err_network'));
  }
}

class _PasswordDialog extends StatefulWidget {
  final String titleKey, okKey;
  const _PasswordDialog({this.titleKey = 'admin_password', this.okKey = 'admin_enter'});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _c = TextEditingController();
  bool _hide = true;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr(widget.titleKey)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _c,
          obscureText: _hide,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            suffixIcon: IconButton(
              icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        if (!TrackingService.instance.live && widget.titleKey == 'admin_password')
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(context.tr('admin_demo'),
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('cancel'))),
        TextButton(
            onPressed: () => Navigator.pop(context, _c.text),
            child: Text(context.tr(widget.okKey))),
      ],
    );
  }
}

/// Админ панел: бардык заказдар жана колдонуучулар.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  Future<void> _changePassword(BuildContext context) async {
    final pw = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(titleKey: 'new_pw', okKey: 'save'),
    );
    if (pw == null || !context.mounted) return;
    if (pw.length < 4) {
      _snack(context, context.tr('pw_short'));
      return;
    }
    try {
      await AdminService.instance.changePassword(pw);
      if (context.mounted) _snack(context, context.tr('pw_saved'));
    } catch (e) {
      if (context.mounted) _snack(context, context.tr('admin_load_err', {'e': '$e'}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = TrackingService.instance.live;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('admin_title')),
          actions: [
            if (live)
              IconButton(
                tooltip: context.tr('new_order'),
                icon: const Icon(Icons.add_box_outlined),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminNewOrderScreen())),
              ),
            if (live)
              IconButton(
                tooltip: context.tr('change_pw'),
                icon: const Icon(Icons.key),
                onPressed: () => _changePassword(context),
              ),
          ],
          bottom: TabBar(
            indicatorColor: kYellow,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            tabs: [
              Tab(text: context.tr('tab_orders')),
              Tab(text: context.tr('tab_drivers')),
              Tab(text: context.tr('tab_users')),
            ],
          ),
        ),
        body: const TabBarView(children: [_OrdersTab(), DriversTab(), _UsersTab()]),
      ),
    );
  }
}

// ---------- заказдар ----------

class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  late final Stream<List<AdminOrder>> _stream = AdminService.instance.orders();
  final bool _live = TrackingService.instance.live;

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

  Future<void> _delete(AdminOrder r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('delete_order')),
        content: Text(ctx.tr('delete_confirm', {'id': r.id})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdminService.instance.deleteOrder(r.id);
    } catch (e) {
      if (mounted) _snack(context, context.tr('admin_load_err', {'e': '$e'}));
    }
  }

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

  Widget _tile(AdminOrder r) => Material(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openMap(r),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r.id} · ${r.product}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${r.fromName} → ${r.toName}',
                      style: const TextStyle(color: Colors.black54)),
                  Text(
                      r.status == OrderStatus.open
                          ? context.tr('declined_n', {'n': '${r.declinedCount}'})
                          : '${context.tr('driver')}: ${r.driverName}',
                      style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ]),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(context.statusText(r.status)),
                backgroundColor: r.status.moving ? kYellow : Colors.white,
              ),
              if (_live)
                IconButton(
                  tooltip: context.tr('delete_order'),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _delete(r),
                ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminOrder>>(
      stream: _stream,
      initialData: _live ? null : AdminService.instance.demoRows(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.tr('admin_load_err', {'e': '${snap.error}'}),
                  textAlign: TextAlign.center),
            ),
          );
        }
        final rows = snap.data;
        if (rows == null) return const Center(child: CircularProgressIndicator());
        if (rows.isEmpty) return Center(child: Text(context.tr('no_orders_admin')));
        int count(OrderStatus s) => rows.where((r) => r.status == s).length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              _stat(context.tr('stat_total'), rows.length),
              const SizedBox(width: 8),
              _stat(context.tr('stat_open'), count(OrderStatus.open)),
              const SizedBox(width: 8),
              _stat(context.tr('stat_wait'), count(OrderStatus.waiting)),
              const SizedBox(width: 8),
              _stat(context.tr('stat_onway'), rows.where((r) => r.status.moving).length),
              const SizedBox(width: 8),
              _stat(context.tr('stat_done'), count(OrderStatus.delivered)),
            ]),
            const SizedBox(height: 14),
            for (final r in rows)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: _tile(r)),
          ],
        );
      },
    );
  }
}

// ---------- колдонуучулар ----------

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  late final Stream<List<AppUser>> _stream = AdminService.instance.users();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.tr('admin_load_err', {'e': '${snap.error}'}),
                  textAlign: TextAlign.center),
            ),
          );
        }
        final users = snap.data;
        if (users == null) return const Center(child: CircularProgressIndicator());
        if (users.isEmpty) return Center(child: Text(context.tr('no_users')));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final u = users[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFEAEAEA),
                backgroundImage: u.photo.isNotEmpty ? NetworkImage(u.photo) : null,
                child: u.photo.isEmpty
                    ? Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.black87))
                    : null,
              ),
              title: Text(u.name.isEmpty ? '—' : u.name),
              subtitle: Text(u.email),
            );
          },
        );
      },
    );
  }
}
