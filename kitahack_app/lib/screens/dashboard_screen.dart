import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_service.dart';
import '../api/routes_api.dart';

class DashboardScreen extends StatefulWidget {
  final bool isRescuerMode;

  const DashboardScreen({super.key, required this.isRescuerMode});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const LatLng _klCenter = LatLng(3.1390, 101.6869);

  bool _isAnalyzing = false;
  late bool _isRescuerMode;

  // MAP STATE
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};

  // SERVICES
  final GeminiService _geminiService = GeminiService();
  final ImagePicker _picker = ImagePicker();

  // DARK MAP STYLE
  final String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#242f3e"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
    {"featureType": "administrative.locality", "elementType": "labels.text.fill",
      "stylers": [{"color": "#d59563"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _isRescuerMode = widget.isRescuerMode;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _setupSimulatedData();
  }

  // ---- PHASE 1: DRAW ALL ACTIVE FLOOD ZONES ON MAP ----
  void _setupSimulatedData() {
    _refreshFloodZonesOnMap();
  }

  /// Redraws all circles and markers for every zone in RoutesApi.activeFloodZones.
  /// Called on init AND after each new Gemini-confirmed flood.
  void _refreshFloodZonesOnMap() {
    setState(() {
      _circles.clear();

      for (final zone in RoutesApi.activeFloodZones) {
        final zoneLatLng = LatLng(zone.lat, zone.lng);

        // Red circle = flood area
        _circles.add(Circle(
          circleId: CircleId('zone_${zone.lat}_${zone.lng}'),
          center: zoneLatLng,
          radius: zone.radiusMeters,
          fillColor: _severityColor(zone.severity).withOpacity(0.35),
          strokeColor: _severityColor(zone.severity),
          strokeWidth: 2,
        ));

        // Pin on each flood zone
        _markers.add(Marker(
          markerId: MarkerId('pin_${zone.lat}_${zone.lng}'),
          position: zoneLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            zone.severity >= 4
                ? BitmapDescriptor.hueRed
                : BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: '⚠️ ${zone.label}',
            snippet: 'Severity: ${zone.severity}/5 — Route will avoid this',
          ),
        ));
      }
    });
  }

  /// Returns a color based on flood severity (1=yellow → 5=red)
  Color _severityColor(int severity) {
    switch (severity) {
      case 1: return Colors.yellow;
      case 2: return Colors.orange;
      case 3: return Colors.deepOrange;
      case 4: return Colors.red;
      case 5: return Colors.red[900]!;
      default: return Colors.red;
    }
  }

  // ---- PHASE 2: AI PHOTO VERIFICATION → AUTO-ADD TO AVOIDANCE LIST ----
  Future<void> _handleReportFlood() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
    if (photo == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final result = await _geminiService.analyzeFloodImage(File(photo.path));

      if (result['isFlood'] == true) {
        final severity = result['severity'] as int? ?? 3;
        final description = result['description'] as String? ?? 'Flood confirmed';

        // ✅ KEY STEP: Gemini confirmed flood → add to route avoidance list
        // In production this would use the device's real GPS location.
        // For demo we use a hardcoded "nearby" point slightly offset from centre.
        const reportedLat = 3.1410;
        const reportedLng = 101.6880;

        RoutesApi.addFloodZone(
          reportedLat,
          reportedLng,
          severity,
          'User Report (AI Verified)',
        );

        // Redraw all flood zones including the new one
        _refreshFloodZonesOnMap();

        _showDialog(
          "⚠️ FLOOD CONFIRMED & MAPPED",
          "Severity: $severity/5\n$description\n\n"
              "This location has been added to the route avoidance list. "
              "Future rescue routes will automatically detour around it.",
          true,
        );
      } else {
        _showDialog(
          "No Flood Detected",
          "Gemini did not detect a flood in this image.",
          false,
        );
      }
    } catch (e) {
      _showDialog("Error", "Could not analyze image. Please try again.", true);
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  // ---- PHASE 3: SAFETY CHATBOT ----
  void _openSafetyChat() {
    final TextEditingController msgController = TextEditingController();
    final List<Map<String, String>> chatHistory = [
      {"role": "ai", "msg": "I am the KL Crisis Assistant. Are you safe?"}
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield, color: Colors.red),
                    SizedBox(width: 10),
                    Text("Official Safety AI (NADMA)",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                color: Colors.amber[100],
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.brown),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "AI can make mistakes. In emergencies, call 999 immediately.",
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.brown,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: chatHistory.length,
                  itemBuilder: (ctx, i) {
                    final isAi = chatHistory[i]["role"] == "ai";
                    return Align(
                      alignment: isAi
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isAi ? Colors.grey[200] : Colors.blue[100],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(chatHistory[i]["msg"]!),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  left: 16,
                  right: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: msgController,
                        decoration: const InputDecoration(
                          hintText: "Ask for help...",
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(50)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FloatingActionButton.small(
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.send, color: Colors.white),
                      onPressed: () async {
                        final text = msgController.text.trim();
                        if (text.isEmpty) return;
                        setSheetState(() {
                          chatHistory.add({"role": "user", "msg": text});
                          msgController.clear();
                        });
                        final reply =
                            await _geminiService.getSafetyAdvice(text);
                        setSheetState(() =>
                            chatHistory.add({"role": "ai", "msg": reply}));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- PHASE 4: RESCUE ROUTE WITH AUTOMATIC FLOOD AVOIDANCE ----
  void _handleRescueRoute() async {
    setState(() {
      _isAnalyzing = true;
      _polylines.clear();
    });

    final result = await RoutesApi.getRoute(
      originLat: 3.1390, // Rescuer: KLCC
      originLng: 101.6869,
      destLat: 3.1500,   // Destination: Masjid Jamek flood zone
      destLng: 101.6950,
    );

    setState(() => _isAnalyzing = false);

    if (result != null) {
      final routes = result['routes'] as List?;
      final avoidedCount = result['_avoidedZones'] as int? ?? 0;
      final detourApplied = result['_detourApplied'] as bool? ?? false;

      if (routes != null && routes.isNotEmpty) {
        final route = routes[0];
        final distanceMeters = route['distanceMeters'] ?? 0;
        final duration = route['duration'] ?? 'N/A';
        final encodedPolyline =
            route['polyline']?['encodedPolyline'] as String?;

        if (encodedPolyline != null && encodedPolyline.isNotEmpty) {
          final decodedPoints = RoutesApi.decodePolyline(encodedPolyline);
          final latLngPoints =
              decodedPoints.map((p) => LatLng(p[0], p[1])).toList();

          setState(() {
            _polylines.add(Polyline(
              polylineId: const PolylineId("safe_route"),
              // Blue = safe detoured route, green = direct (no floods in way)
              color: detourApplied ? Colors.blue : Colors.green,
              width: 5,
              points: latLngPoints,
            ));
          });

          // Fit camera to show the full route
          _mapController.animateCamera(
            CameraUpdate.newLatLngBounds(
              _boundsFromLatLngList(latLngPoints),
              80,
            ),
          );
        } else {
          _drawFallbackRoute();
        }

        // Build a clear summary message for the rescuer
        String routeMsg =
            "Distance: ${(distanceMeters / 1000).toStringAsFixed(1)} km\n"
            "ETA: $duration\n\n";

        if (detourApplied) {
          routeMsg +=
              "⚠️ Detour applied — avoided $avoidedCount flood zone(s).\n"
              "Route shown in BLUE.\n"
              "This is the fastest safe path.";
        } else {
          routeMsg +=
              "✅ No flood zones blocking direct route.\n"
              "Route shown in GREEN.";
        }

        _showDialog("ROUTE CALCULATED", routeMsg, false);
      } else {
        _drawFallbackRoute();
        _showDialog("No Route Found", "API returned no routes.", true);
      }
    } else {
      _drawFallbackRoute();
      _showDialog(
        "Route Unavailable",
        "Could not connect to Routes API.\n\n"
            "Check:\n"
            "• API key in routes_api.dart\n"
            "• Routes API enabled in Cloud Console\n"
            "• Billing active on project",
        true,
      );
    }
  }

  void _drawFallbackRoute() {
    setState(() {
      _polylines.add(const Polyline(
        polylineId: PolylineId("fallback_route"),
        color: Colors.blueGrey,
        width: 4,
        points: [
          LatLng(3.1390, 101.6869),
          LatLng(3.1420, 101.6900),
          LatLng(3.1460, 101.6920),
          LatLng(3.1500, 101.6950),
        ],
      ));
    });
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double minLat = list.first.latitude;
    double maxLat = list.first.latitude;
    double minLng = list.first.longitude;
    double maxLng = list.first.longitude;
    for (final p in list) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _showDialog(String title, String body, bool isDanger) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            style: TextStyle(color: isDanger ? Colors.red : Colors.green)),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1: GOOGLE MAP
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition:
                const CameraPosition(target: _klCenter, zoom: 15),
            markers: _markers,
            circles: _circles,
            polylines: _polylines,
            zoomControlsEnabled: false,
            style: _darkMapStyle,
          ),

          // 2: LOADING OVERLAY
          if (_isAnalyzing)
            Container(
              color: Colors.black54,
              child:
                  const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),

          // 3: TOP BAR
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  FloatingActionButton.small(
                    heroTag: "back_btn",
                    backgroundColor: Colors.white,
                    child:
                        const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(blurRadius: 10, color: Colors.black26)
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isRescuerMode ? Icons.shield : Icons.person,
                          color:
                              _isRescuerMode ? Colors.red : Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRescuerMode
                              ? "RESCUER MODE"
                              : "CIVILIAN MODE",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isRescuerMode
                                ? Colors.red
                                : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4: ACTION PANEL
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: _isRescuerMode
                ? _buildRescuerControls()
                : _buildUserControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildRescuerControls() {
    final zoneCount = RoutesApi.activeFloodZones.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(blurRadius: 15, color: Colors.black26)],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 10),
              Text("COMMAND CENTER",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("Masjid Jamek (Zone A)"),
            subtitle: Text("Water Depth: 1.2m"),
            trailing: Text("CRITICAL",
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
          // Shows how many zones the router is currently avoiding
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Text(
              "🚧 Routing around $zoneCount active flood zone(s)",
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: _handleRescueRoute,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[800],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text("CALCULATE FASTEST RESCUE ROUTE"),
          ),
        ],
      ),
    );
  }

  Widget _buildUserControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          onPressed: _openSafetyChat,
          label: const Text("Safety AI"),
          icon: const Icon(Icons.chat_bubble),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text("REPORT FLOOD (AI VERIFY)"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: _handleReportFlood,
          ),
        ),
      ],
    );
  }
}