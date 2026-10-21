import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/models.dart';

const kNavBlue = Color(0xFF3D9BFF);

/// Карта: чыныгы жол маршруту, чекиттер жана багытка бурулган машина.
/// [nav] = true болсо: көк маршрут (өтпөгөн бөлүгү), карта машинанын
/// багыты боюнча бурулат жана [follow] күйүк болсо машинанын артынан жүрөт.
class OrderMap extends StatefulWidget {
  final Order order;
  final MapController controller;
  final bool nav;
  final bool follow;
  final VoidCallback? onUserMove; // колдонуучу картаны өзү жылдырганда

  const OrderMap({
    super.key,
    required this.order,
    required this.controller,
    this.nav = false,
    this.follow = true,
    this.onUserMove,
  });

  @override
  State<OrderMap> createState() => _OrderMapState();
}

class _OrderMapState extends State<OrderMap> {
  bool _ready = false;
  int _routeLen = 0;

  Order get o => widget.order;
  MapController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    o.addListener(_onUpdate);
  }

  @override
  void dispose() {
    o.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  void didUpdateWidget(OrderMap old) {
    super.didUpdateWidget(old);
    if (widget.nav != old.nav && _ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.nav) {
          c.moveAndRotate(o.position, 16.5, -o.heading);
        } else {
          c.rotate(0);
          _fit();
        }
      });
    }
  }

  void _fit() {
    _routeLen = o.route.length;
    final h = (context.size?.height ?? 800);
    try {
      c.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(o.route),
        padding: EdgeInsets.fromLTRB(40, h * 0.15, 40, h * 0.45),
        maxZoom: 16,
      ));
    } catch (_) {
      c.move(o.position, 11); // көрүнүш эсептелбесе да карта көрүнүп тура берсин
    }
  }

  void _onUpdate() {
    if (!_ready) return;
    if (!widget.nav && o.route.length != _routeLen) {
      _fit(); // чыныгы жол жүктөлдү — бүт маршрутту көрсөт
    } else if (widget.follow && o.status.moving) {
      if (widget.nav) {
        c.moveAndRotate(o.position, c.camera.zoom, -o.heading);
      } else {
        c.move(o.position, c.camera.zoom);
      }
    }
  }

  Marker _pin(LatLng p, IconData icon, Color color) => Marker(
        point: p,
        width: 40,
        height: 40,
        rotate: true, // карта бурулганда да түз турат
        child: Icon(icon, color: color, size: 36),
      );

  @override
  Widget build(BuildContext context) {
    final nav = widget.nav;
    return ListenableBuilder(
      listenable: o,
      builder: (context, _) => FlutterMap(
        mapController: c,
        options: MapOptions(
          initialCenter: o.position,
          initialZoom: 10,
          onMapReady: () {
            _ready = true;
            nav ? c.moveAndRotate(o.position, 16.5, -o.heading) : _fit();
          },
          onPositionChanged: (_, hasGesture) {
            if (hasGesture) widget.onUserMove?.call();
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'kg.gruz.app',
          ),
          const SimpleAttributionWidget(source: Text('© OpenStreetMap contributors')),
          PolylineLayer(polylines: [
            Polyline(
              points: nav ? o.remainingRoute : o.route,
              strokeWidth: nav ? 9 : 6,
              color: nav ? kNavBlue : Colors.black87,
              borderStrokeWidth: 2,
              borderColor: Colors.white,
            ),
          ]),
          MarkerLayer(markers: [
            _pin(o.from, Icons.store, Colors.indigo),
            _pin(o.to, Icons.flag, Colors.red),
            Marker(
              point: o.position,
              width: 56,
              height: 56,
              child: nav
                  ? Transform.rotate(
                      angle: o.heading * math.pi / 180,
                      child: const Icon(Icons.navigation, color: kNavBlue, size: 52, shadows: [
                        Shadow(blurRadius: 8, color: Colors.black54),
                      ]),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: o.vehicle.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38)],
                      ),
                      child: Transform.rotate(
                        angle: o.heading * math.pi / 180,
                        child: const Icon(Icons.navigation, color: Colors.black87, size: 30),
                      ),
                    ),
            ),
          ]),
        ],
      ),
    );
  }
}
