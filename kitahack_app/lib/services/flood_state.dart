import 'package:google_maps_flutter/google_maps_flutter.dart';

class FloodState {
  static final Set<Marker> sharedMarkers = {};
  static final Set<Circle> sharedCircles = {};

  static List<Map<String, String>> chatHistory = [
    {"role": "ai", "msg": "I am the KL Crisis Assistant. Are you safe?"}
  ];
}