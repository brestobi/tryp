import 'package:flutter_test/flutter_test.dart';
import 'package:tryp/core/services/location_service.dart';

void main() {
  test('parses Mapbox search results into suggestions with coordinates', () {
    final suggestions = LocationService.parseMapboxSearchResults({
      'features': [
        {
          'id': 'place.123',
          'text': 'Tzaneen',
          'place_name': 'Tzaneen, Mopani District, Limpopo, South Africa',
          'center': [30.1667, -23.8333],
        },
      ],
    });

    expect(suggestions, hasLength(1));
    expect(suggestions.single.name, 'Tzaneen');
    expect(
      suggestions.single.address,
      'Tzaneen, Mopani District, Limpopo, South Africa',
    );
    expect(suggestions.single.placeId, 'mapbox:place.123|-23.8333,30.1667');
  });

  test('resolves a Mapbox suggestion without another API request', () {
    final location = LocationService.parseMapboxPlaceId(
      'mapbox:place.123|-23.8333,30.1667',
    );

    expect(location, isNotNull);
    expect(location!.latitude, -23.8333);
    expect(location.longitude, 30.1667);
    expect(location.placeId, 'mapbox:place.123|-23.8333,30.1667');
  });

  test('parses Mapbox reverse-geocoding results', () {
    final location = LocationService.parseMapboxReverseResult(
      {
        'features': [
          {
            'text': 'Tzaneen',
            'place_name':
                'Tzaneen, Mopani District, Limpopo, South Africa',
          },
        ],
      },
      latitude: -23.8333,
      longitude: 30.1667,
    );

    expect(location, isNotNull);
    expect(location!.shortName, 'Tzaneen');
    expect(location.address, contains('Mopani District'));
  });

  test('ignores malformed or incomplete Mapbox results', () {
    final suggestions = LocationService.parseMapboxSearchResults({
      'features': [
        {'id': 'place.missing', 'text': 'Missing coordinates'},
        {
          'id': 'place.456',
          'place_name': 'Tzaneen, South Africa',
          'center': [30.1, -23.8],
        },
      ],
    });

    expect(suggestions, hasLength(1));
    expect(suggestions.single.placeId, 'mapbox:place.456|-23.8,30.1');
    expect(LocationService.parseMapboxPlaceId('google-place-id'), isNull);
  });
}
