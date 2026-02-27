import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kitahack_app/services/flood_state.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
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

  @override
  void initState() {
    super.initState();
    _isRescuerMode = widget.isRescuerMode;
    _markers.addAll(FloodState.sharedMarkers);
    _circles.addAll(FloodState.sharedCircles);
    _checkLocationPermission();
  }

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

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if GPS is on
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    // 2. Check current permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 3. Ask the User
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _setupSimulatedData();
  }

  // ---- PHASE 1: MOCK DATA SETUP ----
  void _setupSimulatedData() {
    setState(() {
      // Draw a "Red Zone"
      _circles.add(
        Circle(
          circleId: const CircleId("flood_zone"),
          center: const LatLng(3.1495, 101.6960),
          radius: 150,
          fillColor: Colors.red.withValues(alpha: 0.5),
          strokeColor: Colors.red,
          strokeWidth: 2,
        ),
      );
    });
  }

// ---- PHASE 2: VISUAL INTELLIGENCE (CAMERA & GALLERY) ----
  Future<void> _handleReportFlood() async {
    // 1. Ask User: Camera or Gallery?
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Upload Evidence"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text("Take Photo"),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.orange),
              title: const Text("Upload from Gallery"),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return; // User canceled

    // 2. Pick the Image
    final XFile? photo = await _picker.pickImage(source: source);
    if (photo == null) return;

    setState(() => _isAnalyzing = true);

    // 3. Send to Gemini for 1-5 Severity Rating
    try {
      final result = await _geminiService.analyzeFloodImage(File(photo.path));

      if (result['isFlood'] == true) {
        // 4. Ask for Location before dropping the pin
        await _askForLocationAndAddMarker(result);
      } else {
        _showDialog("Safe", "Gemini did not detect a flood.", false);
      } 
    } catch (e) {
      _showDialog("Error", "Could not analyze image. Try again.", false);
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  // 5. Ask for Location Dialog (Upgraded with GPS & Text Search)
  Future<void> _askForLocationAndAddMarker(Map<String, dynamic> result) async {
    TextEditingController _locationController = TextEditingController();
    bool _isLoading = false; // Controls the loading spinner

    LatLng? selectedLocation = await showDialog<LatLng>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder( // StatefulBuilder allows the dialog to update live
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Where is the flood?"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---- OPTION 1: GPS BUTTON ----
                ListTile(
                  leading: const Icon(Icons.my_location, color: Colors.blue),
                  title: const Text("Use Current GPS Location"),
                  onTap: () async {
                    setDialogState(() => _isLoading = true);
                    try {
                      Position pos = await Geolocator.getCurrentPosition(
                        desiredAccuracy: LocationAccuracy.high
                      );
                      Navigator.pop(ctx, LatLng(pos.latitude, pos.longitude));
                    } catch (e) {
                      setDialogState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("GPS failed. Try typing the address.")),
                      );
                    }
                  },
                ),
                
                const Divider(),
                const Text("OR Type Location:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                
                // ---- OPTION 2: TEXT INPUT ----
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    hintText: "e.g., KLCC, Bukit Bintang...",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 15),

                // ---- SEARCH BUTTON / SPINNER ----
                if (_isLoading) 
                  const CircularProgressIndicator()
                else 
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                    onPressed: () async {
                      if (_locationController.text.trim().isEmpty) return;
                      
                      setDialogState(() => _isLoading = true);
                      try {
                        // Translate text into coordinates!
                        List<Location> locations = await locationFromAddress(_locationController.text);
                        if (locations.isNotEmpty) {
                          Navigator.pop(ctx, LatLng(locations.first.latitude, locations.first.longitude));
                        }
                      } catch (e) {
                        setDialogState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Location not found. Please try another name.")),
                        );
                      }
                    },
                    child: const Text("Search & Use Address"),
                  )
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null), // Cancel button
                child: const Text("Cancel", style: TextStyle(color: Colors.red)),
              )
            ],
          );
        }
      ),
    );

    // If they picked a location, drop the pin!
    if (selectedLocation != null) {
      _addFloodMarker(result, selectedLocation);
      _showDialog("DANGER CONFIRMED", "Severity: ${result['severity']}/5\n${result['description']}", true);
    }
  }

 // 6. Calculate Colors & Add Shapes to Map
  void _addFloodMarker(Map<String, dynamic> data, LatLng location) {
    // Parse severity (Default to 1 if missing)
    int severity = data['severity'] is int ? data['severity'] : int.tryParse(data['severity'].toString()) ?? 1;
    
    // Determine Color based on Severity (Green to Red Scale)
    Color sevColor;
    double markerHue;
    
    switch (severity) {
      case 1:
        sevColor = Colors.green;
        markerHue = BitmapDescriptor.hueGreen; // 120.0
        break;
      case 2:
        sevColor = Colors.lightGreen;
        markerHue = 90.0; // A lime color between Green and Yellow
        break;
      case 3:
        sevColor = Colors.yellow;
        markerHue = BitmapDescriptor.hueYellow; // 60.0
        break;
      case 4:
        sevColor = Colors.orange;
        markerHue = BitmapDescriptor.hueOrange; // 30.0
        break;
      case 5:
      default:
        sevColor = Colors.red;
        markerHue = BitmapDescriptor.hueRed; // 0.0
        break;
    }

    final String uniqueId = DateTime.now().toString();

    // Create Marker
    final newMarker = Marker(
      markerId: MarkerId('marker_$uniqueId'),
      position: location,
      icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
      infoWindow: InfoWindow(
        title: "CONFIRMED FLOOD (Level $severity/5)",
        snippet: data['description'],
      ),
    );

    // Create Colored Circle Zone
    final newCircle = Circle(
      circleId: CircleId('circle_$uniqueId'),
      center: location,
      radius: severity * 50.0, // Higher severity = bigger circle!
      fillColor: sevColor.withOpacity(0.4),
      strokeColor: sevColor,
      strokeWidth: 2,
    );

    setState(() {
      _markers.add(newMarker);
      _circles.add(newCircle);
      
      // Save both to global memory so Rescuer Mode sees them!
      FloodState.sharedMarkers.add(newMarker);
      FloodState.sharedCircles.add(newCircle); 
      
      // Pan camera to the new report!
      _mapController.animateCamera(CameraUpdate.newLatLngZoom(location, 15.5));
    });
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