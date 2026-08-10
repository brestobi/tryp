import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';
import 'package:tryp/config/environment.dart';

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
  final Dio _dio = Dio();

  String get _googleMapsApiKey => Environment.googleMapsApiKey;

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

  /// Reverse geocode a lat/lng to a human-readable address via Google Maps API or Nominatim fallback
  Future<UserLocation> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '$lat,$lng',
          'key': _googleMapsApiKey,
          'result_type': 'street_address|sublocality|locality',
          'language': 'en',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data is String
            ? jsonDecode(response.data as String)
            : response.data as Map<String, dynamic>;

        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final result = (data['results'] as List).first as Map<String, dynamic>;
          final fullAddress = result['formatted_address'] as String? ?? '';
          
          String shortName = _extractShortName(result);

          return UserLocation(
            latitude: lat,
            longitude: lng,
            address: fullAddress,
            shortName: shortName,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Google Reverse geocode error: $e');
    }

    // Try Nominatim reverse geocode fallback
    try {
      final nomResponse = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
        },
        options: Options(headers: {'User-Agent': 'TRYPApp/1.0'}),
      );

      if (nomResponse.statusCode == 200) {
        final data = nomResponse.data is String
            ? jsonDecode(nomResponse.data as String)
            : nomResponse.data as Map<String, dynamic>;
        final displayName = data['display_name'] as String? ?? '';
        final name = (data['name'] as String?).toString().isNotEmpty
            ? data['name'] as String
            : (data['address']?['suburb'] ?? data['address']?['town'] ?? 'Location');

        if (displayName.isNotEmpty) {
          return UserLocation(
            latitude: lat,
            longitude: lng,
            address: displayName,
            shortName: name,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Nominatim Reverse geocode error: $e');
    }

    return UserLocation(
      latitude: lat,
      longitude: lng,
      address: '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
      shortName: 'Your Location',
    );
  }

  String _extractShortName(Map<String, dynamic> result) {
    final components = result['address_components'] as List? ?? [];
    
    String? sublocality;
    String? locality;
    String? route;
    String? streetNumber;

    for (final component in components) {
      final types = (component['types'] as List).cast<String>();
      final longName = component['long_name'] as String;

      if (types.contains('sublocality_level_1') || types.contains('sublocality')) {
        sublocality = longName;
      }
      if (types.contains('locality')) {
        locality = longName;
      }
      if (types.contains('route')) {
        route = longName;
      }
      if (types.contains('street_number')) {
        streetNumber = longName;
      }
    }

    if (sublocality != null) return sublocality;
    if (route != null && streetNumber != null) return '$streetNumber $route';
    if (route != null) return route;
    if (locality != null) return locality;
    return 'Your Location';
  }

  /// Full pipeline: get GPS → reverse geocode → return UserLocation
  Future<UserLocation> getUserLocationWithAddress() async {
    final position = await getCurrentPosition();
    if (position == null) return UserLocation.fallback();
    return reverseGeocode(position.latitude, position.longitude);
  }

  /// Search Google Places for user-facing autocomplete suggestions.
  /// Coordinates are intentionally resolved only after a suggestion is selected.
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    LatLng? near,
  }) async {
    if (query.trim().length < 2 || _googleMapsApiKey.isEmpty) return [];

    try {
      final parameters = <String, dynamic>{
        'input': query.trim(),
        'key': _googleMapsApiKey,
        'language': 'en',
        'components': 'country:za',
      };
      if (near != null) {
        parameters['location'] = '${near.latitude},${near.longitude}';
        parameters['radius'] = 50000;
      }

      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: parameters,
      );
      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data as Map<String, dynamic>;

      if (response.statusCode == 200 && data['status'] == 'OK') {
        return (data['predictions'] as List? ?? []).map((prediction) {
          final item = prediction as Map<String, dynamic>;
          final formatting = item['structured_formatting'] as Map<String, dynamic>?;
          return PlaceSuggestion(
            placeId: item['place_id'] as String,
            name: formatting?['main_text'] as String? ??
                item['description'] as String? ??
                'Selected place',
            address: formatting?['secondary_text'] as String? ??
                item['description'] as String? ??
                '',
          );
        }).toList();
      }

      debugPrint('⚠️ Google Places autocomplete status: ${data['status']}');
    } catch (e) {
      debugPrint('❌ Google Places autocomplete error: $e');
    }

    return [];
  }

  /// Resolve the selected Google Place ID to the exact map coordinates.
  Future<UserLocation?> getPlaceDetails(String placeId) async {
    if (placeId.isEmpty || _googleMapsApiKey.isEmpty) return null;

    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': placeId,
          'key': _googleMapsApiKey,
          'fields': 'place_id,name,formatted_address,geometry,address_component',
          'language': 'en',
        },
      );
      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>?;
      final geometry = result?['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      final lat = (location?['lat'] as num?)?.toDouble();
      final lng = (location?['lng'] as num?)?.toDouble();

      if (data['status'] != 'OK' || result == null || lat == null || lng == null) {
        debugPrint('⚠️ Google Place Details status: ${data['status']}');
        return null;
      }

      final name = result['name'] as String? ?? 'Selected place';
      final address = result['formatted_address'] as String? ?? name;
      return UserLocation(
        latitude: lat,
        longitude: lng,
        address: address,
        shortName: name,
        placeId: result['place_id'] as String? ?? placeId,
      );
    } catch (e) {
      debugPrint('❌ Google Place Details error: $e');
      return null;
    }
  }

  /// Backward-compatible helper that returns resolved Google locations.
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
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
        },
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
    final distanceMeters = Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
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

