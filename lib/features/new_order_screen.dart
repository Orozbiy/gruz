import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/auth_service.dart';
import '../core/geocoder.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../core/tracking_service.dart';

/// Жаңы заказ түзүү: товар, чекиттер, машина жана айдоочу.
/// Түзүлгөндөн кийин кардарга берүүчү код чыгат.
class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _product = TextEditingController();
  final _seller = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _model = TextEditingController();
  final _plate = TextEditingController();
  String _color = 'Ак';
  bool _busy = false;

  List<TextEditingController> get _all =>
      [_product, _seller, _from, _to, _name, _phone, _model, _plate];

  @override
  void initState() {
    super.initState();
    // Мурунку жолу киргизилген айдоочу/машина маалыматын кайра толтуруу.
    Prefs.profile().then((p) {
      if (!mounted) return;
      setState(() {
        if (p.length >= 5) {
          _name.text = p[0];
          _phone.text = p[1];
          _model.text = p[2];
          _plate.text = p[3];
          if (kVehicleColors.containsKey(p[4])) _color = p[4];
        } else {
          _name.text = AuthService.instance.user?.displayName ?? '';
        }
      });
    });
  }

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
    // context.tr() await'тен мурун эсептелет.
    final geoErr = context.tr('err_geo', {'place': '{place}'});
    final createErr = context.tr('err_create', {'e': '{e}'});
    final createdTitle = context.tr('created_title');
    final createdHint = context.tr('created_hint');
    final copyLabel = context.tr('copy');
    final closeLabel = context.tr('close');

    setState(() => _busy = true);
    try {
      final fromName = _from.text.trim(), toName = _to.text.trim();
      final a = await geocode(fromName);
      if (a == null) {
        _msg(geoErr.replaceAll('{place}', fromName));
        return;
      }
      final b = await geocode(toName);
      if (b == null) {
        _msg(geoErr.replaceAll('{place}', toName));
        return;
      }

      final order = await TrackingService.instance.createOrder(
        product: _product.text.trim(),
        seller: _seller.text.trim(),
        fromName: fromName,
        toName: toName,
        from: a,
        to: b,
        vehicle: Vehicle.named(
          model: _model.text.trim(),
          plate: _plate.text.trim().toUpperCase(),
          colorName: _color,
        ),
        driver: Driver(name: _name.text.trim(), phone: _phone.text.trim()),
      );
      await Prefs.saveProfile(
          [_name.text.trim(), _phone.text.trim(), _model.text.trim(), _plate.text.trim(), _color]);
      try {
        await TrackingService.instance.saveDriverProfile(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          model: _model.text.trim(),
          plate: _plate.text.trim().toUpperCase(),
          colorName: _color,
        );
      } catch (_) {}

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(createdTitle),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(createdHint),
            const SizedBox(height: 12),
            SelectableText(order.id,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          ]),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: order.id)),
              child: Text(copyLabel),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(closeLabel)),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, order);
    } catch (e) {
      _msg(createErr.replaceAll('{e}', '$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label,
          {TextInputType? type, TextCapitalization caps = TextCapitalization.sentences}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
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

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('new_order'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _title(context.tr('sec_cargo')),
          _field(_product, context.tr('f_product')),
          _field(_seller, context.tr('f_seller')),
          _field(_from, context.tr('f_from')),
          _field(_to, context.tr('f_to')),
          _title(context.tr('sec_vehicle')),
          _field(_name, context.tr('f_dname')),
          _field(_phone, context.tr('f_phone'), type: TextInputType.phone),
          _field(_model, context.tr('f_model')),
          _field(_plate, context.tr('f_plate'), caps: TextCapitalization.characters),
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
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                : Text(context.tr('create_btn')),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
