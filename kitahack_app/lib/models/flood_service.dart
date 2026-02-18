import 'dart:async';
import '../models/flood_alert.dart';

class FloodService {
  // Mimics call to floodforecasting.googleapis.com
  
  Future<List<FloodAlert>> getLiveFloodAlerts() async {
    // Simulate network loading time (1 second)
    await Future.delayed(const Duration(seconds: 1));

    return [
      // ALERT 1: Critical Flood at Masjid Jamek
      FloodAlert(
        id: 'kl-001',
        locationName: 'Masjid Jamek (Klang River)',
        latitude: 3.1490, 
        longitude: 101.6965,
        floodDepth: 1.5,
        probability: 0.95,
        severity: 'CRITICAL',
        expectedTime: DateTime.now().add(const Duration(minutes: 30)),
      ),

      // ALERT 2: A smaller warning nearby (Dataran Merdeka)
      FloodAlert(
        id: 'kl-002',
        locationName: 'Dataran Merdeka Area',
        latitude: 3.1502, 
        longitude: 101.6938,
        floodDepth: 0.3, 
        probability: 0.60, 
        severity: 'MODERATE',
        expectedTime: DateTime.now().add(const Duration(hours: 2)), 
      ),
    ];
  }
}