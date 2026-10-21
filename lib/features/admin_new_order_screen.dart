import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:latlong2/latlong.dart';

import '../core/geocoder.dart';
import '../core/l10n.dart';
import '../core/tracking_service.dart';
import '../widgets/share_sheet.dart';
import 'map_picker.dart';

/// АДМИН: жаңы (ачык) заказ түзүү. Ташуучуну ташуучулардын өзү тандайт (кабыл алат).
class AdminNewOrderScreen extends StatefulWidget {
  const AdminNewOrderScreen({super.key});

  @override
  State<AdminNewOrderScreen> createState() => _AdminNewOrderScreenState();
}

class _AdminNewOrderScreenState extends State<AdminNewOrderScreen> {
  final _product = TextEditingController();
  final _seller = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _fromCName = TextEditingController();
  final _fromCPhone = TextEditingController();
  final _toCName = TextEditingController();
  final _toCPhone = TextEditingController();
  LatLng? _fromPt, _toPt; // картадан тандалган чекиттер
  bool _busy = false;

  List<TextEditingController> get _all => [_product, _seller, _from, _fromCName, _fromCPhone, _to, _toCName, _toCPhone];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    if (_all.any((c) => c.text.trim().isEmpty)) {
      _msg(context.tr('err_fill_all'));
      return;
    }
    final geoErr = context.tr('err_geo', {'place': '{place}'});
    final createErr = context.tr('err_create', {'e': '{e}'});
    final title = context.tr('created_title');
    final hint = context.tr('admin_created_hint');
    final copyLabel = context.tr('copy');
    final shareLabel = context.tr('share');
    final closeLabel = context.tr('close');

    setState(() => _busy = true);
    try {
      final fromName = _from.text.trim(), toName = _to.text.trim();
      final a = _fromPt ?? await geocode(fromName);
      if (a == null) {
        _msg(geoErr.replaceAll('{place}', fromName));
        return;
      }
      final b = _toPt ?? await geocode(toName);
      if (b == null) {
        _msg(geoErr.replaceAll('{place}', toName));
        return;
      }
      final code = await TrackingService.instance.createOpenOrder(
        product: _product.text.trim(),
        seller: _seller.text.trim(),
        fromName: fromName,
        toName: toName,
        from: a,
        to: b,
        fromContactName: _fromCName.text.trim(),
        fromContactPhone: _fromCPhone.text.trim(),
        toContactName: _toCName.text.trim(),
        toContactPhone: _toCPhone.text.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(hint),
            const SizedBox(height: 12),
            SelectableText(code,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          ]),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              child: Text(copyLabel),
            ),
            TextButton(
              onPressed: () => showShareSheet(ctx, code),
              child: Text(shareLabel),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(closeLabel)),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _msg(createErr.replaceAll('{e}', '$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(bool from) async {
    final r = await Navigator.push<(LatLng, String)>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initial: from ? _fromPt : _toPt,
          title: context.tr(from ? 'sec_pickup' : 'sec_dropoff'),
        ),
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      if (from) {
        _fromPt = r.$1;
        _from.text = r.$2;
      } else {
        _toPt = r.$1;
        _to.text = r.$2;
      }
    });
  }

  Widget _section(String t, IconData icon) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Row(children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _field(TextEditingController c, String label,
          {VoidCallback? onMap,
          bool picked = false,
          ValueChanged<String>? onChanged,
          TextInputType? type}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          onChanged: onChanged,
          keyboardType: type,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            suffixIcon: onMap == null
                ? null
                : IconButton(
                    tooltip: context.tr('pick_on_map'),
                    icon: Icon(picked ? Icons.location_on : Icons.map_outlined,
                        color: picked ? Colors.red : null),
                    onPressed: onMap,
                  ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('new_order'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _field(_product, context.tr('f_product')),
          _section(context.tr('sec_pickup'), Icons.store),
          _field(_seller, context.tr('f_seller')),
          _field(_from, context.tr('f_addr'),
              onMap: () => _pick(true),
              picked: _fromPt != null,
              onChanged: (_) => setState(() => _fromPt = null)),
          _field(_fromCName, context.tr('f_pick_cname')),
          _field(_fromCPhone, context.tr('f_pick_cphone'), type: TextInputType.phone),
          _section(context.tr('sec_dropoff'), Icons.flag),
          _field(_to, context.tr('f_addr'),
              onMap: () => _pick(false),
              picked: _toPt != null,
              onChanged: (_) => setState(() => _toPt = null)),
          _field(_toCName, context.tr('f_recv_name')),
          _field(_toCPhone, context.tr('f_recv_phone'), type: TextInputType.phone),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                : Text(context.tr('create_btn')),
          ),
        ],
      ),
    );
  }
}
