/// Returns whether a ride request can be submitted.
///
/// The UI may show a fare only after route/map calculations finish, but this
/// helper also keeps the submit guard explicit and testable.
bool canRequestTrip({
  required bool mapCalculationComplete,
  required double? fare,
  required bool isLoading,
}) {
  return mapCalculationComplete &&
      !isLoading &&
      fare != null &&
      fare.isFinite &&
      fare > 0;
}
