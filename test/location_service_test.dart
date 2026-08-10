import 'package:flutter_test/flutter_test.dart';
import 'package:tryp/core/services/location_service.dart';

void main() {
  test('parses Nominatim search results into suggestions with coordinates', () {
    final suggestions = LocationService.parseNominatimSearchResults([
      {
        'lat': '-23.8333',
        'lon': '30.1667',
        'name': 'Tzaneen',
        'display_name': 'Tzaneen, Greater Tzaneen, Limpopo, South Africa',
      },
    ]);

    expect(suggestions, hasLength(1));
    expect(suggestions.single.name, 'Tzaneen');
    expect(
      suggestions.single.address,
      'Tzaneen, Greater Tzaneen, Limpopo, South Africa',
    );
    expect(suggestions.single.placeId, 'osm:-23.8333,30.1667');
  });

  test('resolves an OpenStreetMap suggestion without another API request', () {
    final location = LocationService.parseNominatimPlaceId(
      'osm:-23.8333,30.1667',
    );

    expect(location, isNotNull);
    expect(location!.latitude, -23.8333);
    expect(location.longitude, 30.1667);
    expect(location.placeId, 'osm:-23.8333,30.1667');
  });

  test('parses Nominatim reverse-geocoding results', () {
    final location = LocationService.parseNominatimReverseResult(
      {
        'name': 'Tzaneen',
        'display_name': 'Tzaneen, Mopani District, Limpopo, South Africa',
        'address': {'town': 'Tzaneen'},
      },
      latitude: -23.8333,
      longitude: 30.1667,
    );

    expect(location, isNotNull);
    expect(location!.shortName, 'Tzaneen');
    expect(location.address, contains('Mopani District'));
  });

  test('ignores malformed or incomplete OSM results', () {
    final suggestions = LocationService.parseNominatimSearchResults([
      {'display_name': 'Missing coordinates'},
      {'lat': '-23.8', 'lon': '30.1'},
    ]);

    expect(suggestions, hasLength(1));
    expect(suggestions.single.placeId, 'osm:-23.8,30.1');
    expect(LocationService.parseNominatimPlaceId('google-place-id'), isNull);
  });
}
