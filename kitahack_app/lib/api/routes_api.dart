import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Represents a confirmed flood zone to avoid
class FloodZone {
  final double lat;
  final double lng;
  final double radiusMeters; // how wide the flood area is
  final int severity;        // 1–5, from Gemini analysis
  final String label;

  const FloodZone({
    required this.lat,
    required this.lng,
    this.radiusMeters = 200,
    this.severity = 3,
    this.label = 'Flood Zone',
  });
}

class RoutesApi {
  static const String _apiKey = 'AIzaSyDURrgzfgeWscMzTnsCckep4LxXotUaexo'; 

  static const String _baseUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  // -----------------------------------------------------------------------
  // FLOOD ZONE REGISTRY
  // This list is updated whenever Gemini confirms a new flood from a photo.
  // The dashboard calls addFloodZone() after AI verification.
  // -----------------------------------------------------------------------
  static final List<FloodZone> activeFloodZones = [
    // Pre-seeded simulated zone for demo (Masjid Jamek area)
    const FloodZone(
      lat: 3.1495,
      lng: 101.6960,
      radiusMeters: 200,
      severity: 4,
      label: 'Masjid Jamek (Zone A)',
    ),
  ];

  /// Call this after Gemini confirms a flood photo — adds it to avoidance list
  static void addFloodZone(double lat, double lng, int severity, String label) {
    activeFloodZones.add(FloodZone(
      lat: lat,
      lng: lng,
      radiusMeters: 150 + (severity * 30), // larger radius for worse floods
      severity: severity,
      label: label,
    ));
  }

  // -----------------------------------------------------------------------
  // MAIN ROUTING FUNCTION
  // Automatically detects which flood zones are in the way and routes around
  // -----------------------------------------------------------------------
  static Future<Map<String, dynamic>?> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    // 1. Find which flood zones are blocking the path (excluding destination)
    final blockingZones = _findBlockingZones(
      originLat, originLng,
      destLat, destLng,
    );

    print('Routes API: Found ${blockingZones.length} blocking flood zone(s)');

    // 2. Compute detour waypoints to steer around each blocking zone
    final detourWaypoints = _computeDetourWaypoints(
      originLat, originLng,
      destLat, destLng,
      blockingZones,
    );

    // 3. Build the API request body with waypoints if needed
    final body = _buildRequestBody(
      originLat, originLng,
      destLat, destLng,
      detourWaypoints,
    );

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask':
              'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        // Attach metadata so dashboard can show what was avoided
        result['_avoidedZones'] = blockingZones.length;
        result['_detourApplied'] = detourWaypoints.isNotEmpty;
        return result;
      } else {
        print('Routes API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Routes API Exception: $e');
      return null;
    }
  }

  // -----------------------------------------------------------------------
  // STEP 1: Find which flood zones sit between origin and destination
  // We skip the destination zone itself — that's where we're going on purpose
  // -----------------------------------------------------------------------
  static List<FloodZone> _findBlockingZones(
    double originLat, double originLng,
    double destLat, double destLng,
  ) {
    final blocking = <FloodZone>[];

    for (final zone in activeFloodZones) {
      // Skip if this zone IS the destination (we still need to go there)
      final distToDest = _distanceMeters(zone.lat, zone.lng, destLat, destLng);
      if (distToDest < zone.radiusMeters) continue;

      // Check if this zone is close to the straight line between origin → dest
      final distToPath = _distanceToSegmentMeters(
        zone.lat, zone.lng,       // flood zone center
        originLat, originLng,     // segment start
        destLat, destLng,         // segment end
      );

      if (distToPath < zone.radiusMeters + 100) { // +100m buffer
        blocking.add(zone);
        print('  Blocking zone: ${zone.label} (${distToPath.toStringAsFixed(0)}m from path)');
      }
    }

    return blocking;
  }

  // -----------------------------------------------------------------------
  // STEP 2: For each blocking zone, compute a waypoint offset to its side
  // We push the waypoint perpendicular to the route by the zone's radius
  // -----------------------------------------------------------------------
  static List<Map<String, double>> _computeDetourWaypoints(
    double originLat, double originLng,
    double destLat, double destLng,
    List<FloodZone> blockingZones,
  ) {
    if (blockingZones.isEmpty) return [];

    final waypoints = <Map<String, double>>[];

    // Direction vector of the main route
    final routeDLat = destLat - originLat;
    final routeDLng = destLng - originLng;
    final routeLen = sqrt(routeDLat * routeDLat + routeDLng * routeDLng);

    // Perpendicular unit vector (rotate 90°)
    final perpLat = -routeDLng / routeLen;
    final perpLng = routeDLat / routeLen;

    for (final zone in blockingZones) {
      // Offset distance in degrees (approx: 1 degree lat ≈ 111km)
      final offsetDeg = (zone.radiusMeters + 150) / 111000;

      // Try both sides, pick the one further from other flood zones
      final waypointA = {
        'lat': zone.lat + perpLat * offsetDeg,
        'lng': zone.lng + perpLng * offsetDeg,
      };
      final waypointB = {
        'lat': zone.lat - perpLat * offsetDeg,
        'lng': zone.lng - perpLng * offsetDeg,
      };

      // Pick the side with fewer nearby flood zones
      final scoreA = _countNearbyZones(waypointA['lat']!, waypointA['lng']!);
      final scoreB = _countNearbyZones(waypointB['lat']!, waypointB['lng']!);

      waypoints.add(scoreA <= scoreB ? waypointA : waypointB);
      print('  Detour waypoint added for: ${zone.label}');
    }

    return waypoints;
  }

  /// Count how many active flood zones are within 300m of a point
  static int _countNearbyZones(double lat, double lng) {
    return activeFloodZones
        .where((z) => _distanceMeters(lat, lng, z.lat, z.lng) < 300)
        .length;
  }

  // -----------------------------------------------------------------------
  // STEP 3: Build the full Routes API request body
  // -----------------------------------------------------------------------
  static Map<String, dynamic> _buildRequestBody(
    double originLat, double originLng,
    double destLat, double destLng,
    List<Map<String, double>> waypoints,
  ) {
    final body = <String, dynamic>{
      "origin": {
        "location": {
          "latLng": {"latitude": originLat, "longitude": originLng}
        }
      },
      "destination": {
        "location": {
          "latLng": {"latitude": destLat, "longitude": destLng}
        }
      },
      "travelMode": "DRIVE",
      "routingPreference": "TRAFFIC_AWARE",
      "computeAlternativeRoutes": false,
      "languageCode": "en-US",
    };

    // Add detour waypoints if we have any
    if (waypoints.isNotEmpty) {
      body["intermediates"] = waypoints.map((wp) => {
        "via": true, // 'via' = pass through without stopping, keeps route efficient
        "location": {
          "latLng": {"latitude": wp['lat'], "longitude": wp['lng']}
        }
      }).toList();
    }

    return body;
  }

  // -----------------------------------------------------------------------
  // GEOMETRY HELPERS
  // -----------------------------------------------------------------------

  /// Straight-line distance between two lat/lng points in metres (Haversine)
  static double _distanceMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0; // Earth radius in metres
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
            sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// Perpendicular distance from point P to line segment AB in metres
  static double _distanceToSegmentMeters(
    double pLat, double pLng,   // the flood zone centre
    double aLat, double aLng,   // segment start (origin)
    double bLat, double bLng,   // segment end (destination)
  ) {
    final dx = bLat - aLat;
    final dy = bLng - aLng;
    final lenSq = dx * dx + dy * dy;

    if (lenSq == 0) return _distanceMeters(pLat, pLng, aLat, aLng);

    // Project point onto segment, clamped to [0,1]
    double t = ((pLat - aLat) * dx + (pLng - aLng) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);

    final closestLat = aLat + t * dx;
    final closestLng = aLng + t * dy;

    return _distanceMeters(pLat, pLng, closestLat, closestLng);
  }

  static double _toRad(double deg) => deg * pi / 180;

  // -----------------------------------------------------------------------
  // POLYLINE DECODER
  // Converts Google's encoded polyline string → list of [lat, lng] pairs
  // -----------------------------------------------------------------------
  static List<List<double>> decodePolyline(String encoded) {
    final List<List<double>> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0, result = 0, byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add([lat / 1e5, lng / 1e5]);
    }

    return points;
  }
}