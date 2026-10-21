import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/l10n.dart';

/// Заказдын шилтемесин бөлүшүү: WhatsApp, Telegram, SMS же көчүрүү.
/// Кардар шилтемени басып, сайттан айдоочуну картадан жандуу көрөт.
Future<void> showShareSheet(BuildContext context, String code) async {
  final url = '$kSiteUrl/?id=$code';
  final text = context.tr('share_text', {'code': code, 'url': url});
  final copied = context.tr('copied');
  final messenger = ScaffoldMessenger.of(context);
  final enc = Uri.encodeComponent;

  Future<void> open(BuildContext ctx, Uri u) async {
    Navigator.pop(ctx);
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(context.tr('share_title'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        ListTile(
          leading: const Icon(Icons.chat, color: Colors.green),
          title: const Text('WhatsApp'),
          onTap: () => open(ctx, Uri.parse('https://wa.me/?text=${enc(text)}')),
        ),
        ListTile(
          leading: const Icon(Icons.send, color: Colors.blue),
          title: const Text('Telegram'),
          onTap: () =>
              open(ctx, Uri.parse('https://t.me/share/url?url=${enc(url)}&text=${enc(text)}')),
        ),
        ListTile(
          leading: const Icon(Icons.sms_outlined),
          title: const Text('SMS'),
          onTap: () => open(ctx, Uri.parse('sms:?body=${enc(text)}')),
        ),
        ListTile(
          leading: const Icon(Icons.copy),
          title: Text(context.tr('copy_link')),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (ctx.mounted) Navigator.pop(ctx);
            messenger.showSnackBar(SnackBar(content: Text(copied)));
          },
        ),
      ]),
    ),
  );
}
