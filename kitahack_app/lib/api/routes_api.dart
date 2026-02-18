import 'dart:convert';
import 'package:http/http.dart' as http;

class RoutesApi {
  static const String _apiKey = 'AIzaSyA1wcRFfgPaCW3tKzS0nlvgra-U3TqYy4w';

  static const String _baseUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  /// Gets the fastest route from [origin] to [destination]
  /// avoiding [floodedZones] (list of lat/lng coordinates to avoid)
  static Future<Map<String, dynamic>?> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final body = jsonEncode({
      "origin": {
        "location": {
          "latLng": {
            "latitude": originLat,
            "longitude": originLng,
          }
        }
      },
      "destination": {
        "location": {
          "latLng": {
            "latitude": destLat,
            "longitude": destLng,
          }
        }
      },
      "travelMode": "DRIVE",
      "routingPreference": "TRAFFIC_AWARE", // avoids congested/flooded roads
      "computeAlternativeRoutes": true,     // gives backup routes too
      "languageCode": "en-US",
    });

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          // This tells Google WHAT data to return
          'X-Goog-FieldMask':
              'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Routes API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Routes API Exception: $e');
      return null;
    }
  }
}