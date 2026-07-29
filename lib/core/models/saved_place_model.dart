class SavedPlaceModel {
  final String id;
  final String userId;
  final String label; // 'Home', 'Work', 'Gym', 'Favorite'
  final String address;
  final double latitude;
  final double longitude;

  const SavedPlaceModel({
    required this.id,
    required this.userId,
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory SavedPlaceModel.fromJson(Map<String, dynamic> json) {
    return SavedPlaceModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      label: json['label'] as String? ?? 'Favorite',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'label': label,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
