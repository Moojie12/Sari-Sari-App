import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LagunaCity {
  const LagunaCity({
    required this.code,
    required this.name,
    this.isCity = false,
  });

  final String code;
  final String name;
  final bool isCity;

  factory LagunaCity.fromJson(Map<String, dynamic> json) {
    return LagunaCity(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isCity: json['isCity'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'isCity': isCity,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LagunaCity && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => name;
}

class LagunaBarangay {
  const LagunaBarangay({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;

  factory LagunaBarangay.fromJson(Map<String, dynamic> json) {
    return LagunaBarangay(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LagunaBarangay && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => name;
}

class LagunaLocationService {
  LagunaLocationService._();
  static final LagunaLocationService instance = LagunaLocationService._();
  factory LagunaLocationService() => instance;

  static const String provinceName = 'Laguna';
  static const String provinceCode = '043400000';
  static const String regionName = 'Region IV-A (CALABARZON)';
  static const String countryName = 'Philippines';

  static const String _baseUrl = 'https://psgc.gitlab.io/api';

  List<LagunaCity>? _cachedCities;
  final Map<String, List<LagunaBarangay>> _cachedBarangays = {};

  /// Fallback list of all 30 Laguna cities & municipalities with standard PSGC codes
  static const List<Map<String, dynamic>> _fallbackCitiesData = [
    {"code": "043401000", "name": "Alaminos", "isCity": false},
    {"code": "043402000", "name": "Bay", "isCity": false},
    {"code": "043403000", "name": "City of Biñan", "isCity": true},
    {"code": "043404000", "name": "City of Cabuyao", "isCity": true},
    {"code": "043405000", "name": "City of Calamba", "isCity": true},
    {"code": "043406000", "name": "Calauan", "isCity": false},
    {"code": "043407000", "name": "Cavinti", "isCity": false},
    {"code": "043408000", "name": "Famy", "isCity": false},
    {"code": "043409000", "name": "Kalayaan", "isCity": false},
    {"code": "043410000", "name": "Liliw", "isCity": false},
    {"code": "043411000", "name": "Los Baños", "isCity": false},
    {"code": "043412000", "name": "Luisiana", "isCity": false},
    {"code": "043413000", "name": "Lumban", "isCity": false},
    {"code": "043414000", "name": "Mabitac", "isCity": false},
    {"code": "043415000", "name": "Magdalena", "isCity": false},
    {"code": "043416000", "name": "Majayjay", "isCity": false},
    {"code": "043417000", "name": "Nagcarlan", "isCity": false},
    {"code": "043418000", "name": "Paete", "isCity": false},
    {"code": "043419000", "name": "Pagsanjan", "isCity": false},
    {"code": "043420000", "name": "Pakil", "isCity": false},
    {"code": "043421000", "name": "Pangil", "isCity": false},
    {"code": "043422000", "name": "Pila", "isCity": false},
    {"code": "043423000", "name": "Rizal", "isCity": false},
    {"code": "043424000", "name": "City of San Pablo", "isCity": true},
    {"code": "043425000", "name": "City of San Pedro", "isCity": true},
    {"code": "043426000", "name": "Santa Cruz", "isCity": false},
    {"code": "043427000", "name": "Santa Maria", "isCity": false},
    {"code": "043428000", "name": "City of Santa Rosa", "isCity": true},
    {"code": "043429000", "name": "Siniloan", "isCity": false},
    {"code": "043430000", "name": "Victoria", "isCity": false},
  ];

  /// Fetch all cities and municipalities of Laguna via PSGC API with offline fallback
  Future<List<LagunaCity>> getLagunaCities({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCities != null && _cachedCities!.isNotEmpty) {
      return _cachedCities!;
    }

    try {
      final uri = Uri.parse('$_baseUrl/provinces/$provinceCode/cities-municipalities.json');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          final cities = decoded
              .map((item) => LagunaCity.fromJson(Map<String, dynamic>.from(item)))
              .toList();

          // Sort alphabetically by name
          cities.sort((a, b) => a.name.compareTo(b.name));
          _cachedCities = cities;
          return cities;
        }
      }
    } catch (e) {
      debugPrint('LagunaLocationService: Error fetching from API, using fallback. $e');
    }

    // Use built-in fallback if API request fails
    final fallbackList = _fallbackCitiesData
        .map((item) => LagunaCity.fromJson(item))
        .toList();
    fallbackList.sort((a, b) => a.name.compareTo(b.name));
    _cachedCities = fallbackList;
    return fallbackList;
  }

  /// Fetch barangays for a specific city/municipality code via PSGC API
  Future<List<LagunaBarangay>> getBarangays(String cityCode, {bool forceRefresh = false}) async {
    if (cityCode.isEmpty) return [];

    if (!forceRefresh && _cachedBarangays.containsKey(cityCode)) {
      return _cachedBarangays[cityCode]!;
    }

    try {
      final uri = Uri.parse('$_baseUrl/cities-municipalities/$cityCode/barangays.json');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          final barangays = decoded
              .map((item) => LagunaBarangay.fromJson(Map<String, dynamic>.from(item)))
              .toList();

          // Sort alphabetically
          barangays.sort((a, b) => a.name.compareTo(b.name));
          _cachedBarangays[cityCode] = barangays;
          return barangays;
        }
      }
    } catch (e) {
      debugPrint('LagunaLocationService: Error fetching barangays for $cityCode: $e');
      rethrow;
    }

    return [];
  }

  /// Clear in-memory caches
  void clearCache() {
    _cachedCities = null;
    _cachedBarangays.clear();
  }
}
