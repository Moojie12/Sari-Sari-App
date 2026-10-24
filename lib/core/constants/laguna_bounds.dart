import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Geographic boundary and address helpers strictly for Laguna Province, Philippines.
class LagunaBounds {
  LagunaBounds._();

  // Bounding box covering the entire province of Laguna, Philippines
  static const double minLat = 13.98;
  static const double maxLat = 14.55;
  static const double minLng = 121.01;
  static const double maxLng = 121.60;

  static const double defaultMinZoom = 10.0;
  static const double defaultMaxZoom = 18.0;

  static final LatLngBounds bounds = LatLngBounds(
    const LatLng(minLat, minLng),
    const LatLng(maxLat, maxLng),
  );

  /// Default center of Laguna (Santa Rosa default store location)
  static const LatLng defaultCenter = LatLng(14.3122, 121.1114);

  /// Check whether a given latitude/longitude coordinate falls within Laguna boundaries
  static bool contains(LatLng point) {
    return point.latitude >= minLat &&
        point.latitude <= maxLat &&
        point.longitude >= minLng &&
        point.longitude <= maxLng;
  }

  /// Clamps any coordinate to stay strictly within Laguna boundaries
  static LatLng clamp(LatLng point) {
    final lat = point.latitude.clamp(minLat, maxLat);
    final lng = point.longitude.clamp(minLng, maxLng);
    return LatLng(lat, lng);
  }

  /// Standard postal codes for all 30 cities and municipalities of Laguna
  static const Map<String, String> cityPostalCodes = {
    'alaminos': '4001',
    'bay': '4033',
    'binan': '4024',
    'biñan': '4024',
    'city of binan': '4024',
    'city of biñan': '4024',
    'cabuyao': '4025',
    'city of cabuyao': '4025',
    'calamba': '4027',
    'city of calamba': '4027',
    'calauan': '4012',
    'cavinti': '4013',
    'famy': '4021',
    'kalayaan': '4015',
    'liliw': '4004',
    'los banos': '4030',
    'los baños': '4030',
    'luisiana': '4032',
    'lumban': '4014',
    'mabitac': '4020',
    'magdalena': '4007',
    'majayjay': '4005',
    'nagcarlan': '4002',
    'paete': '4016',
    'pagsanjan': '4008',
    'pakil': '4017',
    'pangil': '4018',
    'pila': '4010',
    'rizal': '4003',
    'san pablo': '4000',
    'city of san pablo': '4000',
    'san pedro': '4023',
    'city of san pedro': '4023',
    'santa cruz': '4009',
    'sta cruz': '4009',
    'sta. cruz': '4009',
    'santa maria': '4022',
    'sta maria': '4022',
    'sta. maria': '4022',
    'santa rosa': '4026',
    'sta rosa': '4026',
    'sta. rosa': '4026',
    'city of santa rosa': '4026',
    'siniloan': '4019',
    'victoria': '4011',
  };

  static String? getPostalCode(String? cityName) {
    if (cityName == null || cityName.trim().isEmpty) return null;
    final clean = cityName.trim().toLowerCase();
    for (final entry in cityPostalCodes.entries) {
      if (clean == entry.key || clean.contains(entry.key) || entry.key.contains(clean)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Search OpenStreetMap Nominatim restricted strictly to Laguna Province
  static Future<List<LagunaGeocodedPlace>> searchLaguna(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final sanitizedQuery = query.toLowerCase().contains('laguna')
          ? query
          : '$query, Laguna, Philippines';

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=${Uri.encodeComponent(sanitizedQuery)}&'
        'format=json&'
        'addressdetails=1&'
        'countrycodes=ph&'
        'viewbox=$minLng,$maxLat,$maxLng,$minLat&'
        'bounded=1&'
        'limit=6',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': 'TindahanNiEca-LagunaPicker/1.0 (sarisari@laguna.app)',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List<LagunaGeocodedPlace> results = [];

        for (final item in decoded) {
          if (item is Map) {
            final lat = double.tryParse(item['lat']?.toString() ?? '');
            final lon = double.tryParse(item['lon']?.toString() ?? '');
            if (lat != null && lon != null) {
              final point = LatLng(lat, lon);
              // Strictly ensure the location is within Laguna boundaries
              if (contains(point)) {
                final place = LagunaGeocodedPlace.fromNominatim(Map<String, dynamic>.from(item), point);
                // Also verify that the address metadata indicates Laguna if present
                if (place.province.toLowerCase().contains('laguna') ||
                    place.displayName.toLowerCase().contains('laguna')) {
                  results.add(place);
                }
              }
            }
          }
        }
        return results;
      }
    } catch (e) {
      debugPrint('[LagunaBounds] search error: $e');
    }
    return [];
  }

  /// Reverse geocode a latitude & longitude into a structured Laguna address
  static Future<LagunaGeocodedPlace?> reverseGeocode(LatLng point) async {
    if (!contains(point)) return null;

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'lat=${point.latitude}&'
        'lon=${point.longitude}&'
        'format=json&'
        'addressdetails=1',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': 'TindahanNiEca-LagunaPicker/1.0 (sarisari@laguna.app)',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return LagunaGeocodedPlace.fromNominatim(data, point);
      }
    } catch (e) {
      debugPrint('[LagunaBounds] reverse geocode error: $e');
    }
    return null;
  }
}

/// Parsed address details from Nominatim OpenStreetMap
class LagunaGeocodedPlace {
  const LagunaGeocodedPlace({
    required this.displayName,
    required this.location,
    this.street,
    this.barangay,
    this.city,
    this.province = 'Laguna',
    this.region = 'Region IV-A (CALABARZON)',
    this.postalCode,
  });

  final String displayName;
  final LatLng location;
  final String? street;
  final String? barangay;
  final String? city;
  final String province;
  final String region;
  final String? postalCode;

  factory LagunaGeocodedPlace.fromNominatim(Map<String, dynamic> json, LatLng point) {
    final address = (json['address'] is Map)
        ? Map<String, dynamic>.from(json['address'] as Map)
        : <String, dynamic>{};

    final rawStreet = address['road']?.toString() ??
        address['pedestrian']?.toString() ??
        address['street']?.toString() ??
        address['house_number']?.toString();

    final rawBarangay = address['quarter']?.toString() ??
        address['suburb']?.toString() ??
        address['neighbourhood']?.toString() ??
        address['village']?.toString() ??
        address['residential']?.toString();

    final rawCity = address['city']?.toString() ??
        address['town']?.toString() ??
        address['municipality']?.toString();

    final rawProvince = address['province']?.toString() ??
        address['state']?.toString() ??
        'Laguna';

    final rawRegion = address['region']?.toString() ??
        address['state_district']?.toString() ??
        'Region IV-A (CALABARZON)';

    var rawPostcode = address['postcode']?.toString();
    if ((rawPostcode == null || rawPostcode.isEmpty) && rawCity != null) {
      rawPostcode = LagunaBounds.getPostalCode(rawCity);
    }

    return LagunaGeocodedPlace(
      displayName: json['display_name']?.toString() ?? '',
      location: point,
      street: rawStreet,
      barangay: rawBarangay,
      city: rawCity,
      province: rawProvince,
      region: rawRegion,
      postalCode: rawPostcode,
    );
  }
}
