import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// TRYP map presentation styles.
class TRYPMapStyles {
  TRYPMapStyles._();

  /// Mapbox Standard gives us a stable base that supports runtime branding.
  static const String light = 'mapbox://styles/mapbox/standard';

  /// Applies TRYP's clean, ride-focused map presentation.
  static Future<void> applyBranding(MapboxMap map) async {
    try {
      await map.setStyleImportConfigProperties('basemap', {
        'lightPreset': 'day',
        'showPointOfInterestLabels': false,
        'showTransitLabels': false,
        'showPlaceLabels': true,
        'showRoadLabels': true,
        'show3dObjects': false,
      });
    } catch (error) {
      // Custom Mapbox Studio styles may not expose the Standard basemap import.
      debugPrint('TRYP map branding was not applied: $error');
    }
  }
}
