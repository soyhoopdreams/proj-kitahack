class FloodAlert {
  final String id;
  final String locationName;
  final double latitude;
  final double longitude;
  final double floodDepth; // in meters
  final double probability; // 0.0 to 1.0 
  final String severity; // "Low", "Moderate", "Critical"
  final DateTime expectedTime;

  FloodAlert({
    required this.id,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.floodDepth,
    required this.probability,
    required this.severity,
    required this.expectedTime,
  });
}