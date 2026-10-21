import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/prefs.dart';
import '../core/tracking_service.dart';
import 'order_screen.dart';

/// Кардар: заказдын кодун киргизет да, жүгүн картадан көрөт.
class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Prefs.lastCode().then((c) {
      if (c != null && mounted && _code.text.isEmpty) _code.text = c;
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// [key] — котормонун ачкычы.
  void _msg(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(key))));
  }

  Future<void> _find() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      _msg('err_enter_code');
      return;
    }
    setState(() => _busy = true);
    try {
      final order = await TrackingService.instance.open(code);
      if (order == null) {
        _msg('err_not_found');
        return;
      }
      await Prefs.setLastCode(order.id);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderScreen(order: order, isDriver: false)),
      );
    } catch (e) {
      _msg('err_network');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = TrackingService.instance.live;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('customer'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr('cust_head'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(context.tr('cust_sub'), style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 20),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _find(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1.5),
              decoration: InputDecoration(
                labelText: context.tr('code_label'),
                hintText: 'KG-123456',
                helperText: live ? null : context.tr('demo_helper'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _find,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                  : Text(context.tr('show_map')),
            ),
          ],
        ),
      ),
    );
  }
}
