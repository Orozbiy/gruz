import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, FirebaseAuthException;
import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../core/tracking_service.dart';
import 'driver_screen.dart';

/// "Айдоочу" баскычынын артындагы дарбаза:
/// каттала элек → Кирүү / Каттоо; заявка каралууда → күтүү; кабыл алынды → пароль → иш экраны.
class DriverGate extends StatefulWidget {
  const DriverGate({super.key});

  @override
  State<DriverGate> createState() => _DriverGateState();
}

class _DriverGateState extends State<DriverGate> {
  final _auth = AuthService.instance;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _stream;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _auth.loadDriverUnlocked().whenComplete(() {
      if (mounted) setState(() => _loaded = true);
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _stream = FirebaseFirestore.instance.collection('drivers').doc(uid).snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!TrackingService.instance.live) return const DriverScreen();
    if (!_loaded) return _shell(context, const Center(child: CircularProgressIndicator()));
    final stream = _stream;
    if (stream == null) return _shell(context, const SizedBox.shrink());
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _shell(
              context,
              _Message(
                icon: Icons.error_outline,
                title: context.tr('err_network'),
                text: '${snap.error}',
              ));
        }
        if (!snap.hasData) {
          return _shell(context, const Center(child: CircularProgressIndicator()));
        }
        final doc = snap.data!;
        final d = doc.data();
        if (!doc.exists || d == null) {
          return const _Choice();
        }
        final status = d['status'] as String? ?? 'pending';
        if (status == 'rejected') {
          return Scaffold(
            appBar: AppBar(title: Text(context.tr('rejected_title'))),
            body: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(context.tr('rejected_text'),
                    style: const TextStyle(color: Colors.black54)),
              ),
              Expanded(child: _RegisterForm(initial: d, resubmit: true, onDone: () {})),
            ]),
          );
        }
        if (status != 'approved') {
          return _shell(
              context,
              _Message(
                icon: Icons.hourglass_top,
                title: context.tr('pending_title'),
                text: context.tr('pending_text'),
              ));
        }
        if (d['blocked'] == true) {
          return _shell(
              context,
              _Message(
                icon: Icons.block,
                title: context.tr('blocked_title'),
                text: context.tr('blocked_text'),
              ));
        }
        if (!_auth.driverUnlocked) {
          return _shell(context, _PhoneLogin(initialPhone: d['phone']?.toString() ?? ''));
        }
        _syncPrefs(d);
        return const DriverScreen();
      },
    );
  }

  /// Башка телефондон кирсе да профиль даяр болушу үчүн Firestore'дон алып коёт.
  Future<void> _syncPrefs(Map<String, dynamic> d) async {
    final p = await Prefs.profile();
    if (p.length >= 5 && p.take(4).every((s) => s.trim().isNotEmpty)) return;
    final color = d['colorName']?.toString() ?? 'Ак';
    await Prefs.saveProfile([
      d['name']?.toString() ?? '',
      d['phone']?.toString() ?? '',
      d['model']?.toString() ?? '',
      d['plate']?.toString() ?? '',
      kVehicleColors.containsKey(color) ? color : 'Ак',
    ]);
  }

  Widget _shell(BuildContext context, Widget body) => Scaffold(
        appBar: AppBar(title: Text(context.tr('driver'))),
        body: body,
      );
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const _Message({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Colors.black54),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          ]),
        ),
      );
}

/// Айдоочу баскычын басканда: эки баскыч — Кирүү / Каттоо.
class _Choice extends StatelessWidget {
  const _Choice();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('driver'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.local_shipping_outlined, size: 64, color: Colors.black54),
              const SizedBox(height: 16),
              Text(context.tr('drv_choice_hint'),
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  icon: const Icon(Icons.login),
                  label: Text(context.tr('drv_login'), style: const TextStyle(fontSize: 18)),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(context.tr('drv_login'))),
                      body: const _PhoneLogin(initialPhone: ''),
                    ),
                  )),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(context.tr('drv_register'), style: const TextStyle(fontSize: 18)),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (ctx) => Scaffold(
                      appBar: AppBar(title: Text(context.tr('drv_register'))),
                      body: _RegisterForm(
                        initial: const {},
                        resubmit: false,
                        onDone: () => Navigator.of(ctx).maybePop(),
                      ),
                    ),
                  )),
                ),
              ),
            ]),
          ),
        ),
      );
}

/// Кирүү: телефон номери + пароль.
class _PhoneLogin extends StatefulWidget {
  final String initialPhone;
  const _PhoneLogin({required this.initialPhone});

  @override
  State<_PhoneLogin> createState() => _PhoneLoginState();
}

class _PhoneLoginState extends State<_PhoneLogin> {
  final _phone = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phone.text = widget.initialPhone;
  }

  @override
  void dispose() {
    _phone.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phone.text.trim().isEmpty || _pw.text.isEmpty) return;
    final wrong = context.tr('wrong_pw');
    final errTpl = context.tr('pw_err', {'e': '{e}'});
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await AuthService.instance.signInWithPhone(_phone.text, _pw.text);
      if (!mounted) return;
      if (ok) {
        await AuthService.instance.rememberDriver();
        if (!mounted) return;
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DriverGate()),
          (r) => r.isFirst,
        );
      } else {
        setState(() => _error = wrong);
      }
    } catch (e) {
      if (mounted) setState(() => _error = errTpl.replaceAll('{e}', '$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(context.tr('login_hint'), style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.tr('f_phone'),
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pw,
            obscureText: _hide,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: context.tr('drv_pw'),
              errorText: _error,
              prefixIcon: const Icon(Icons.lock),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              suffixIcon: IconButton(
                icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                : Text(context.tr('drv_login')),
          ),
        ],
      );
}

/// Каттоо: маалымат + пароль → заявка админге жөнөтүлөт.
class _RegisterForm extends StatefulWidget {
  final Map<String, dynamic> initial;
  final bool resubmit; // заявка четке кагылган, пароль мурун коюлган
  final VoidCallback onDone;
  const _RegisterForm({required this.initial, required this.resubmit, required this.onDone});

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _model = TextEditingController();
  final _plate = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  String _color = 'Ак';
  bool _busy = false, _hide = true;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _name.text = d['name']?.toString() ?? (AuthService.instance.user?.displayName ?? '');
    _phone.text = d['phone']?.toString() ?? '';
    _model.text = d['model']?.toString() ?? '';
    _plate.text = d['plate']?.toString() ?? '';
    final c = d['colorName']?.toString();
    if (c != null && kVehicleColors.containsKey(c)) _color = c;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _model, _plate, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _submit() async {
    final needPw = !widget.resubmit;
    if ([_name, _phone, _model, _plate].any((c) => c.text.trim().isEmpty)) {
      _msg(context.tr('err_fill_all'));
      return;
    }
    if (needPw) {
      if (_pw.text.length < 6) {
        _msg(context.tr('pw_min6'));
        return;
      }
      if (_pw.text != _pw2.text) {
        _msg(context.tr('pw_mismatch'));
        return;
      }
    }
    final provErr = context.tr('err_provider');
    final errTpl = context.tr('pw_err', {'e': '{e}'});
    setState(() => _busy = true);
    try {
      if (needPw) await AuthService.instance.setPassword(_phone.text, _pw.text);
      final v = [_name.text.trim(), _phone.text.trim(), _model.text.trim(), _plate.text.trim()];
      await TrackingService.instance.saveDriverProfile(
        name: v[0],
        phone: v[1],
        model: v[2],
        plate: v[3].toUpperCase(),
        colorName: _color,
        status: 'pending',
      );
      await Prefs.saveProfile([...v, _color]);
      await AuthService.instance.rememberDriver();
      widget.onDone();
      // Экран өзү "Заявка каралууда" болуп өзгөрөт (Firestore'дон угуп турат).
    } on FirebaseAuthException catch (e) {
      _msg(e.code == 'operation-not-allowed'
          ? provErr
          : e.code == 'email-already-in-use' || e.code == 'credential-already-in-use'
              ? context.tr('phone_taken')
              : errTpl.replaceAll('{e}', e.message ?? e.code));
    } catch (e) {
      _msg(errTpl.replaceAll('{e}', '$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _f(TextEditingController c, String label,
          {TextInputType? type,
          TextCapitalization caps = TextCapitalization.sentences,
          bool pw = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: type,
          textCapitalization: caps,
          obscureText: pw && _hide,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            suffixIcon: pw
                ? IconButton(
                    icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _hide = !_hide),
                  )
                : null,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(context.tr('drv_reg_hint'), style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 14),
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
          const SizedBox(height: 16),
          if (!widget.resubmit) ...[
            _f(_pw, context.tr('drv_pw'), pw: true),
            _f(_pw2, context.tr('drv_pw2'), pw: true),
          ],
          const SizedBox(height: 4),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                : Text(context.tr(widget.resubmit ? 'resend' : 'drv_apply')),
          ),
          const SizedBox(height: 12),
        ],
      );
}
