import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/geocoder.dart';
import '../core/l10n.dart';
import '../core/theme.dart';

/// Картадан жерди тандоо: метка ортодо турат, картаны жылдырып так жерге коёсуз.
/// Дарек өзү жазылат. Жыйынтык: (координата, дарек).
class MapPickerScreen extends StatefulWidget {
  final LatLng? initial;
  final String title;
  const MapPickerScreen({super.key, this.initial, required this.title});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const _bishkek = LatLng(42.8746, 74.5698);
  final _map = MapController();
  final _search = TextEditingController();
  late LatLng _center = widget.initial ?? _bishkek;
  String _address = '';
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onMove(LatLng c) {
    _center = c;
    _debounce?.cancel();
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 600), _resolve);
  }

  Future<void> _resolve() async {
    final at = _center;
    final a = await reverseGeocode(at);
    if (!mounted || at != _center) return;
    setState(() {
      _address = a ?? '${at.latitude.toStringAsFixed(5)}, ${at.longitude.toStringAsFixed(5)}';
      _loading = false;
    });
  }

  Future<void> _find() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    final p = await geocode(q);
    if (!mounted) return;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('err_geo', {'place': q}))));
      return;
    }
    _map.move(p, 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initial == null ? 12 : 16,
              onPositionChanged: (cam, hasGesture) {
                if (hasGesture) _onMove(cam.center);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'kg.gruz.app',
              ),
              const SimpleAttributionWidget(source: Text('© OpenStreetMap contributors')),
            ],
          ),
        ),
        // Ортодогу метка (учу картанын борборун көрсөтөт)
        const IgnorePointer(
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 44),
              child: Icon(Icons.location_on, size: 48, color: Colors.red),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(14),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _find(),
              decoration: InputDecoration(
                hintText: context.tr('search_addr'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _find),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const Icon(Icons.place_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _loading || _address.isEmpty ? context.tr('addr_loading') : _address,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: kYellow, foregroundColor: Colors.black),
                    onPressed: _loading || _address.isEmpty
                        ? null
                        : () => Navigator.pop(context, (_center, _address)),
                    child: Text(context.tr('choose_here')),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
