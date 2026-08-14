/// Service areas supported by TRYP's current operating footprint.
class TRYPServiceAreas {
  TRYPServiceAreas._();

  static const String tzaneenTheOaks = 'tzaneen_the_oaks';
  static const String phalaborwa = 'phalaborwa';

  static const List<TRYPServiceArea> all = [
    TRYPServiceArea(
      id: tzaneenTheOaks,
      label: 'Tzaneen ↔ The Oaks',
      description: 'Tzaneen, The Oaks and nearby communities',
    ),
    TRYPServiceArea(
      id: phalaborwa,
      label: 'Phalaborwa',
      description: 'Phalaborwa and nearby communities',
    ),
  ];

  static TRYPServiceArea? byId(String? id) {
    for (final area in all) {
      if (area.id == id) return area;
    }
    return null;
  }
}

class TRYPServiceArea {
  final String id;
  final String label;
  final String description;

  const TRYPServiceArea({
    required this.id,
    required this.label,
    required this.description,
  });
}
