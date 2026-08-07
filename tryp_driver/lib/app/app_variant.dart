/// Identifies which branded TRYP application is running.
enum AppVariant {
  passenger,
  driver,
}

/// Set once by the selected Flutter entry point before the widget tree starts.
late final AppVariant currentAppVariant;

extension AppVariantX on AppVariant {
  bool get isDriver => this == AppVariant.driver;
  bool get isPassenger => this == AppVariant.passenger;
  String get displayName => isDriver ? 'TRYP Driver' : 'TRYP';
  String get expectedRole => isDriver ? 'driver' : 'passenger';
}
