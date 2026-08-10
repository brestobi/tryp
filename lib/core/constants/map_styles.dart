/// TRYP map presentation styles.
class TRYPMapStyles {
  TRYPMapStyles._();

  /// A subdued night style that keeps roads and markers easy to read.
  static const String dark = '''[
  {
    "featureType": "all",
    "elementType": "geometry",
    "stylers": [{"color": "#202124"}]
  },
  {
    "featureType": "all",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#aeb4bd"}]
  },
  {
    "featureType": "all",
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#202124"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#34373d"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#17181b"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#454a53"}]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [{"color": "#25272b"}]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#8e959f"}]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [{"color": "#25272b"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#101d2a"}]
  }
]''';
}
