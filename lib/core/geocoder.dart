import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Шаардын/дарктын атынан координата (OpenStreetMap Nominatim, ачкыч керек эмес).
/// Табылбаса же интернет жок болсо — null.
Future<LatLng?> geocode(String query) async {
  try {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
      'countrycodes': 'kg',
    });
    final res = await http
        .get(uri, headers: {'User-Agent': 'kg.gruz.app'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final list = jsonDecode(res.body) as List;
    if (list.isEmpty) return null;
    final m = list.first as Map;
    return LatLng(double.parse(m['lat'].toString()), double.parse(m['lon'].toString()));
  } catch (_) {
    return null;
  }
}

/// Координатадан дарек (карта менен тандаганда). Табылбаса — null.
Future<String?> reverseGeocode(LatLng p) async {
  try {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': '${p.latitude}',
      'lon': '${p.longitude}',
      'format': 'json',
      'zoom': '18',
      'addressdetails': '1',
    });
    final res = await http
        .get(uri, headers: {'User-Agent': 'kg.gruz.app'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final m = jsonDecode(res.body) as Map;
    final a = (m['address'] as Map?) ?? const {};
    String? g(String k) => a[k]?.toString();
    final street = [g('road'), g('house_number')].whereType<String>().join(' ');
    final area = g('suburb') ?? g('neighbourhood') ?? g('quarter');
    final city = g('city') ?? g('town') ?? g('village') ?? g('county');
    final parts = [
      if (g('amenity') != null || g('shop') != null || g('building') != null)
        g('amenity') ?? g('shop'),
      if (street.isNotEmpty) street,
      if (area != null) area,
      if (city != null) city,
    ].whereType<String>().toList();
    if (parts.isNotEmpty) return parts.join(', ');
    return m['display_name']?.toString();
  } catch (_) {
    return null;
  }
}
