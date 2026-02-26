import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/flood_alert.dart';

/// (https://developers.google.com/flood-forecasting/rest).
/// Targets the `v1/floodStatus:searchLatestFloodStatusByArea` endpoint.
/// For the demo, the UI uses the mock `flood_service.dart` to guarantee an active event.
class LiveGoogleFloodApi {
  // In a real app, this API key would be hidden in a .env file
  static const String _apiKey = 'YOUR_GOOGLE_CLOUD_API_KEY';
  
  // Official Google Flood Forecasting API endpoint for area searches
  static const String _baseUrl = 'https://floodforecasting.googleapis.com/v1/floodStatus:searchLatestFloodStatusByArea';

  /// Fetches real-time flood status using CLDR region codes ('MY' for Malaysia)
  Future<List<FloodAlert>> fetchLiveAlerts({String regionCode = 'MY'}) async {
    try {
      // 1. Build the Request URI with the API Key
      final uri = Uri.parse('$_baseUrl?key=$_apiKey');
      
      // 2. Build the Request Body following Google's gRPC Transcoding syntax
      final Map<String, dynamic> requestBody = {
        "regionCode": regionCode, // Queries the entire country of Malaysia
        "includeNonQualityVerified": false // We only want verified gauge data
      };

      // 3. Make the Network Call (POST request)
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      // 4. Handle the Response
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> floodStatuses = data['floodStatuses'] ?? [];

        // 5. The Adapter Pattern: Convert Google's format into our UI model
        return floodStatuses.map((json) {
          // Extract precise gauge coordinates
          final location = json['gaugeLocation'] ?? {};
          final double lat = location['latitude']?.toDouble() ?? 0.0;
          final double lng = location['longitude']?.toDouble() ?? 0.0;
          
          // Google returns specific enums. E.g., 'UNKNOWN', 'NO_FLOODING', 'ABOVE_NORMAL', 'SEVERE', 'EXTREME'
          final String rawSeverity = json['severity'] ?? 'UNKNOWN';
          
          // Translate Google's severity to our UI format
          final String uiSeverity = _mapSeverity(rawSeverity);
          
          return FloodAlert(
            id: json['gaugeId'] ?? DateTime.now().toString(),
            locationName: 'Flood Gauge: ${json['gaugeId']}', // The official gauge ID
            latitude: lat,
            longitude: lng,
            floodDepth: uiSeverity == 'CRITICAL' ? 1.5 : 0.5, // Estimated for UI purposes
            probability: 0.95, // Official gauges are highly accurate
            severity: uiSeverity,
            expectedTime: json['issuedTime'] != null 
                ? DateTime.parse(json['issuedTime']) 
                : DateTime.now(),
          );
        }).where((alert) => alert.severity != 'LOW').toList(); 
        // Filter out 'NO_FLOODING' areas so we only return active threats
        
      } else {
        throw Exception('Failed to load Google Flood data. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error communicating with Google Flood API: $e');
      return []; // Return empty list so the app doesn't crash on network failure
    }
  }

  /// Internal helper to translate Google's specific severity enums into our simplified UI states
  String _mapSeverity(String googleSeverity) {
    switch (googleSeverity) {
      case 'EXTREME':
      case 'SEVERE':
        return 'CRITICAL';
      case 'ABOVE_NORMAL':
        return 'MODERATE';
      case 'NO_FLOODING':
      case 'UNKNOWN':
      default:
        return 'LOW';
    }
  }
}