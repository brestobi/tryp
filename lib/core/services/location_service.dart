import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';

class UserLocation {
  final double latitude;
  final double longitude;
  final String address;
  final String shortName;
  final String? placeId;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.shortName,
    this.placeId,
  });

  factory UserLocation.fallback() => const UserLocation(
    latitude: -26.1076,
    longitude: 28.0567,
    address: 'Sandton City, Sandton',
    shortName: 'Current Location',
  );
}

class PlaceSuggestion {
  final String placeId;
  final String name;
  final String address;

  const PlaceSuggestion({
    required this.placeId,
    required this.name,
    required this.address,
  });
}

class RouteResult {
  final double distanceKm;
  final int durationMins;
  final List<LatLng> polylinePoints;

  const RouteResult({
    required this.distanceKm,
    required this.durationMins,
    required this.polylinePoints,
  });
}

class LocationService {
  static const String _nominatimSearchUrl =
      'https://nominatim.openstreetmap.org/search';
  static const String _nominatimReverseUrl =
      'https://nominatim.openstreetmap.org/reverse';

  final Dio _dio;

  LocationService({Dio? dio}) : _dio = dio ?? Dio();

  Options get _nominatimOptions => Options(
    headers: const {'User-Agent': 'TRYPApp/1.0', 'Accept-Language': 'en'},
  );

  /// Parse Nominatim search results into the app's suggestion model.
  ///
  /// Nominatim returns coordinates with each search result, so the values are
  /// encoded in the legacy placeId field. This lets existing selection flows
  /// resolve a result without making a second provider request.
  static List<PlaceSuggestion> parseNominatimSearchResults(dynamic data) {
    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((item) {
          final lat = item['lat']?.toString();
          final lon = item['lon']?.toString();
          final displayName = item['display_name']?.toString().trim() ?? '';
          final rawName = item['name']?.toString().trim() ?? '';
          final name = rawName.isNotEmpty
              ? rawName
              : displayName.split(',').first.trim();

          return PlaceSuggestion(
            placeId: lat != null && lon != null ? 'osm:$lat,$lon' : '',
            name: name.isNotEmpty ? name : 'Selected place',
            address: displayName.isNotEmpty ? displayName : name,
          );
        })
        .where((suggestion) => suggestion.placeId.isNotEmpty)
        .toList();
  }

  /// Parse a Nominatim result's encoded coordinates into a location.
  static UserLocation? parseNominatimPlaceId(String placeId) {
    if (!placeId.startsWith('osm:')) return null;
    final coordinates = placeId.substring(4).split(',');
    if (coordinates.length != 2) return null;

    final latitude = double.tryParse(coordinates[0]);
    final longitude = double.tryParse(coordinates[1]);
    if (latitude == null || longitude == null) return null;

    return UserLocation(
      latitude: latitude,
      longitude: longitude,
      address: 'Selected OpenStreetMap location',
      shortName: 'Selected place',
      placeId: placeId,
    );
  }

  static UserLocation? parseNominatimReverseResult(
    dynamic data, {
    required double latitude,
    required double longitude,
  }) {
    if (data is! Map) return null;
    final displayName = data['display_name']?.toString().trim() ?? '';
    if (displayName.isEmpty) return null;

    final address = data['address'];
    final addressMap = address is Map ? address : const <String, dynamic>{};
    final rawName = data['name']?.toString().trim() ?? '';
    final fallbackName =
        addressMap['suburb'] ??
        addressMap['town'] ??
        addressMap['city'] ??
        addressMap['municipality'] ??
        'Your Location';
    final shortName = rawName.isNotEmpty ? rawName : fallbackName.toString();

    return UserLocation(
      latitude: latitude,
      longitude: longitude,
      address: displayName,
      shortName: shortName,
    );
  }

  /// Request permission and get the device's current GPS position
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ Location services are disabled.');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('❌ Location permission denied.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('❌ Location permission permanently denied.');
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
      return null;
    }
  }

  /// Reverse geocode a lat/lng to a human-readable address via OpenStreetMap.
  Future<UserLocation> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get(
        _nominatimReverseUrl,
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'jsonv2',
          'addressdetails': 1,
        },
        options: _nominatimOptions,
      );
      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      final location = parseNominatimReverseResult(
        data,
        latitude: lat,
        longitude: lng,
      );
      if (location != null) return location;
    } catch (e) {
      debugPrint('❌ OpenStreetMap reverse geocode error: $e');
    }

    return UserLocation(
      latitude: lat,
      longitude: lng,
      address: '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
      shortName: 'Your Location',
    );
  }

  /// Full pipeline: get GPS → reverse geocode → return UserLocation
  Future<UserLocation> getUserLocationWithAddress() async {
    final position = await getCurrentPosition();
    if (position == null) return UserLocation.fallback();
    return reverseGeocode(position.latitude, position.longitude);
  }

  /// Search OpenStreetMap Nominatim for user-facing autocomplete suggestions.
  /// Coordinates are returned with every result, so no API key is required.
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    LatLng? near,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) return [];

    try {
      final response = await _dio.get(
        _nominatimSearchUrl,
        queryParameters: {
          'q': trimmedQuery,
          'format': 'jsonv2',
          'addressdetails': 1,
          'limit': 8,
          'countrycodes': 'za',
          'accept-language': 'en',
        },
        options: _nominatimOptions,
      );
      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      return parseNominatimSearchResults(data);
    } catch (e) {
      debugPrint('❌ OpenStreetMap autocomplete error: $e');
      return [];
    }
  }

  /// Resolve a selected OpenStreetMap result without a second network call.
  Future<UserLocation?> getPlaceDetails(String placeId) async {
    return parseNominatimPlaceId(placeId);
  }

  /// Backward-compatible helper that returns resolved OpenStreetMap locations.
  Future<List<UserLocation>> searchLocations(String query) async {
    final suggestions = await searchPlaces(query);
    final locations = <UserLocation>[];
    for (final suggestion in suggestions) {
      final location = await getPlaceDetails(suggestion.placeId);
      if (location != null) locations.add(location);
    }
    return locations;
  }

  /// Get real road driving route calculation via OSRM API
  Future<RouteResult> getRealRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      final response = await _dio.get(
        'http://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat',
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );

      if (response.statusCode == 200) {
        final data = response.data is String
            ? jsonDecode(response.data as String)
            : response.data as Map<String, dynamic>;

        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = (data['routes'] as List).first;
          final leg = (route['legs'] as List).first;

          final distanceMeters = (leg['distance'] as num).toDouble();
          final durationSeconds = (leg['duration'] as num).toDouble();

          final distanceKm = distanceMeters / 1000.0;
          final durationMins = (durationSeconds / 60.0).round();

          final geometry = route['geometry'];
          final coordinates = (geometry['coordinates'] as List);

          final List<LatLng> points = coordinates.map((coord) {
            final lngVal = (coord[0] as num).toDouble();
            final latVal = (coord[1] as num).toDouble();
            return LatLng(latVal, lngVal);
          }).toList();

          return RouteResult(
            distanceKm: distanceKm,
            durationMins: durationMins < 1 ? 1 : durationMins,
            polylinePoints: points,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ OSRM routing error: $e');
    }

    // Fallback: Haversine distance with 1.35x road factor & interpolated points
    final distanceMeters = Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
    final straightKm = distanceMeters / 1000.0;
    final roadKm = straightKm * 1.35;
    final durationMins = (roadKm / 35.0 * 60).round();

    final midLat = (startLat + endLat) / 2 + 0.003;
    final midLng = (startLng + endLng) / 2 + 0.002;

    return RouteResult(
      distanceKm: roadKm < 0.5 ? 0.5 : roadKm,
      durationMins: durationMins < 3 ? 3 : durationMins,
      polylinePoints: [
        LatLng(startLat, startLng),
        LatLng(midLat, midLng),
        LatLng(endLat, endLng),
      ],
    );
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// A provider that fetches the user's real current location on first watch
final currentUserLocationProvider = FutureProvider<UserLocation>((ref) async {
  final service = ref.read(locationServiceProvider);
  return service.getUserLocationWithAddress();
});
