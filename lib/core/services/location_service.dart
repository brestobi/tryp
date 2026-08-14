import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:tryp/config/environment.dart';

/// Provider-neutral geographic coordinate in latitude/longitude order.
class MapCoordinate {
  final double latitude;
  final double longitude;

  const MapCoordinate(this.latitude, this.longitude);
}

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
  final List<MapCoordinate> polylinePoints;

  const RouteResult({
    required this.distanceKm,
    required this.durationMins,
    required this.polylinePoints,
  });
}

class LocationService {
  static const String _mapboxGeocodingUrl =
      'https://api.mapbox.com/geocoding/v5/mapbox.places';
  static const String _mapboxDirectionsUrl =
      'https://api.mapbox.com/directions/v5/mapbox/driving';

  final Dio _dio;

  LocationService({Dio? dio}) : _dio = dio ?? Dio();

  String get _mapboxAccessToken => Environment.mapboxAccessToken;

  Options get _mapboxOptions => Options(
    headers: const {'Accept-Language': 'en'},
  );

  static List<Map<String, dynamic>> _mapboxFeatures(dynamic data) {
    if (data is! Map) return [];
    final features = data['features'];
    if (features is! List) return [];
    return features.whereType<Map>().map(
      (feature) => Map<String, dynamic>.from(feature),
    ).toList();
  }

  static List<double>? _featureCenter(Map<String, dynamic> feature) {
    final rawCenter = feature['center'];
    final rawGeometry = feature['geometry'];
    final rawCoordinates = rawCenter ??
        (rawGeometry is Map ? rawGeometry['coordinates'] : null);
    if (rawCoordinates is! List || rawCoordinates.length < 2) return null;

    final longitude = (rawCoordinates[0] as num?)?.toDouble();
    final latitude = (rawCoordinates[1] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    return [latitude, longitude];
  }

  /// Parse Mapbox Geocoding search results into the app's suggestion model.
  /// Coordinates are embedded in the provider ID so selecting a suggestion
  /// does not require a second request.
  static List<PlaceSuggestion> parseMapboxSearchResults(dynamic data) {
    final suggestions = <PlaceSuggestion>[];
    for (final feature in _mapboxFeatures(data)) {
      final center = _featureCenter(feature);
      final id = feature['id']?.toString().trim() ?? '';
      if (center == null || id.isEmpty) continue;

      final placeName = feature['place_name']?.toString().trim() ?? '';
      final text = feature['text']?.toString().trim() ?? '';
      final name = text.isNotEmpty
          ? text
          : placeName.split(',').first.trim();
      if (name.isEmpty) continue;

      suggestions.add(
        PlaceSuggestion(
          placeId: 'mapbox:$id|${center[0]},${center[1]}',
          name: name,
          address: placeName.isNotEmpty ? placeName : name,
        ),
      );
    }
    return suggestions;
  }

  /// Parse a Mapbox result's encoded coordinates into a location.
  static UserLocation? parseMapboxPlaceId(String placeId) {
    if (!placeId.startsWith('mapbox:')) return null;
    final separator = placeId.lastIndexOf('|');
    if (separator == -1 || separator == placeId.length - 1) return null;

    final coordinates = placeId.substring(separator + 1).split(',');
    if (coordinates.length != 2) return null;

    final latitude = double.tryParse(coordinates[0]);
    final longitude = double.tryParse(coordinates[1]);
    if (latitude == null || longitude == null) return null;

    return UserLocation(
      latitude: latitude,
      longitude: longitude,
      address: 'Selected Mapbox location',
      shortName: 'Selected place',
      placeId: placeId,
    );
  }

  static UserLocation? parseMapboxReverseResult(
    dynamic data, {
    required double latitude,
    required double longitude,
  }) {
    final features = _mapboxFeatures(data);
    if (features.isEmpty) return null;

    final feature = features.first;
    final address = feature['place_name']?.toString().trim() ?? '';
    if (address.isEmpty) return null;

    final text = feature['text']?.toString().trim() ?? '';
    final shortName = text.isNotEmpty ? text : 'Your Location';
    return UserLocation(
      latitude: latitude,
      longitude: longitude,
      address: address,
      shortName: shortName,
    );
  }

  /// Request permission and get the device's current GPS position.
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

  /// Reverse geocode a lat/lng to a human-readable address with Mapbox.
  Future<UserLocation> reverseGeocode(double lat, double lng) async {
    if (_mapboxAccessToken.isNotEmpty) {
      try {
        final response = await _dio.get(
          '$_mapboxGeocodingUrl/$lng,$lat.json',
          queryParameters: {
            'access_token': _mapboxAccessToken,
            'language': 'en',
            'limit': 1,
          },
          options: _mapboxOptions,
        );
        final data = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;
        final location = parseMapboxReverseResult(
          data,
          latitude: lat,
          longitude: lng,
        );
        if (location != null) return location;
      } catch (e) {
        debugPrint('❌ Mapbox reverse geocode error: $e');
      }
    }

    return UserLocation(
      latitude: lat,
      longitude: lng,
      address: '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
      shortName: 'Your Location',
    );
  }

  /// Full pipeline: get GPS → Mapbox reverse geocode → return UserLocation.
  Future<UserLocation> getUserLocationWithAddress() async {
    final position = await getCurrentPosition();
    if (position == null) return UserLocation.fallback();
    return reverseGeocode(position.latitude, position.longitude);
  }

  /// Search Mapbox Geocoding for user-facing autocomplete suggestions.
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    MapCoordinate? near,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2 || _mapboxAccessToken.isEmpty) return [];

    try {
      final response = await _dio.get(
        '$_mapboxGeocodingUrl/${Uri.encodeComponent(trimmedQuery)}.json',
        queryParameters: {
          'access_token': _mapboxAccessToken,
          'autocomplete': 'true',
          'language': 'en',
          'limit': 8,
          'country': 'za',
          'types': 'address,poi,place,locality,neighborhood',
          if (near != null) 'proximity': '${near.longitude},${near.latitude}',
        },
        options: _mapboxOptions,
      );
      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      return parseMapboxSearchResults(data);
    } catch (e) {
      debugPrint('❌ Mapbox autocomplete error: $e');
      return [];
    }
  }

  /// Resolve a selected Mapbox result without a second network call.
  Future<UserLocation?> getPlaceDetails(String placeId) async {
    return parseMapboxPlaceId(placeId);
  }

  /// Return resolved Mapbox locations for a search query.
  Future<List<UserLocation>> searchLocations(String query) async {
    final suggestions = await searchPlaces(query);
    final locations = <UserLocation>[];
    for (final suggestion in suggestions) {
      final location = await getPlaceDetails(suggestion.placeId);
      if (location != null) locations.add(location);
    }
    return locations;
  }

  /// Get a real road driving route from Mapbox Directions.
  Future<RouteResult> getRealRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    if (_mapboxAccessToken.isNotEmpty) {
      try {
        final response = await _dio.get(
          '$_mapboxDirectionsUrl/$startLng,$startLat;$endLng,$endLat',
          queryParameters: {
            'access_token': _mapboxAccessToken,
            'overview': 'full',
            'geometries': 'geojson',
            'steps': 'false',
          },
          options: Options(
            headers: const {'Accept-Language': 'en'},
            receiveTimeout: const Duration(seconds: 8),
          ),
        );

        final data = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;
        if (data is Map && data['code'] == 'Ok') {
          final routes = data['routes'];
          if (routes is List && routes.isNotEmpty) {
            final route = routes.first;
            final distanceMeters = (route['distance'] as num).toDouble();
            final durationSeconds = (route['duration'] as num).toDouble();
            final geometry = route['geometry'];
            final coordinates = geometry is Map
                ? geometry['coordinates']
                : null;
            if (coordinates is List && coordinates.isNotEmpty) {
              final points = coordinates.whereType<List>().where((coord) {
                return coord.length >= 2 &&
                    coord[0] is num &&
                    coord[1] is num;
              }).map((coord) {
                return MapCoordinate(
                  (coord[1] as num).toDouble(),
                  (coord[0] as num).toDouble(),
                );
              }).toList();

              if (points.isNotEmpty) {
                final durationMins = (durationSeconds / 60.0).round();
                return RouteResult(
                  distanceKm: distanceMeters / 1000.0,
                  durationMins: durationMins < 1 ? 1 : durationMins,
                  polylinePoints: points,
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Mapbox routing error: $e');
      }
    }

    // Keep the app usable if Mapbox is temporarily unavailable.
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
        MapCoordinate(startLat, startLng),
        MapCoordinate(midLat, midLng),
        MapCoordinate(endLat, endLng),
      ],
    );
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// A provider that fetches the user's real current location on first watch.
final currentUserLocationProvider = FutureProvider<UserLocation>((ref) async {
  final service = ref.read(locationServiceProvider);
  return service.getUserLocationWithAddress();
});
