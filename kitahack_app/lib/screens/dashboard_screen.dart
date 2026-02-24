import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kitahack_app/services/flood_state.dart';
import 'package:geolocator/geolocator.dart';
import '../services/gemini_service.dart';
import '../services/flood_state.dart';

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

  // DARK MODE
  final String _darkMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [{"color": "#242f3e"}]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#746855"}]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [{"color": "#242f3e"}]
    },
    {
      "featureType": "administrative.locality",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#d59563"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [{"color": "#38414e"}]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [{"color": "#17263c"}]
    }
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

  // 5. Ask for Location Dialog
  Future<void> _askForLocationAndAddMarker(Map<String, dynamic> result) async {
    LatLng? selectedLocation = await showDialog<LatLng>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Where is this?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location, color: Colors.blue),
              title: const Text("My Current GPS Location"),
              onTap: () async {
                try {
                  Position pos = await Geolocator.getCurrentPosition();
                  Navigator.pop(ctx, LatLng(pos.latitude, pos.longitude));
                } catch (e) {
                  Navigator.pop(ctx, _klCenter); // Fallback if GPS fails
                }
              },
            ),
            const Divider(),
            const Text("Hackathon Demo Locations:", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.red),
              title: const Text("Masjid Jamek"),
              onTap: () => Navigator.pop(ctx, const LatLng(3.1495, 101.6960)),
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.orange),
              title: const Text("Kampung Baru"),
              onTap: () => Navigator.pop(ctx, const LatLng(3.1620, 101.7050)),
            ),
          ],
        ),
      ),
    );

    if (selectedLocation != null) {
      _addFloodMarker(result, selectedLocation);
      _showDialog("DANGER CONFIRMED", "Severity: ${result['severity']}/5\n${result['description']}", true);
    }
  }

  // 6. Calculate Colors & Add Shapes to Map
  void _addFloodMarker(Map<String, dynamic> data, LatLng location) {
    // Parse severity (Default to 1 if missing)
    int severity = data['severity'] is int ? data['severity'] : int.tryParse(data['severity'].toString()) ?? 1;
    
    // Determine Color based on Severity
    Color sevColor;
    double markerHue;
    
    if (severity <= 2) {
      sevColor = Colors.yellow;
      markerHue = BitmapDescriptor.hueYellow;
    } else if (severity <= 4) {
      sevColor = Colors.orange;
      markerHue = BitmapDescriptor.hueOrange;
    } else {
      sevColor = Colors.red;
      markerHue = BitmapDescriptor.hueRed;
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
      FloodState.sharedMarkers.add(newMarker);
      
      // Pan camera to the new report!
      _mapController.animateCamera(CameraUpdate.newLatLngZoom(location, 15.5));
    });
  }

  // ---- PHASE 3: SAFETY CHATBOT ----
  void _openSafetyChat() {
    TextEditingController _msgController = TextEditingController();
    // List<Map<String, String>> chatHistory = [
    //   {"role": "ai", "msg": "I am the KL Crisis Assistant. Are you safe?"}
    // ];

    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25))
          ),
          child: Column(
            children: [
              // Chat Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(25))
                ),
                child: Row(
                  children: const [
                    Icon(Icons.shield, color: Colors.red),
                    SizedBox(width: 10),
                    Text(
                      "Official Safety AI (NADMA)", 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: Colors.red)
                    ),
                  ],
                ),
              ),
              // Ethical Guardrail Banner
              Container(
                width: double.infinity,
                color: Colors.amber[100],
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, size: 16, color: Colors.brown),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "AI can make mistakes. In life-threatening emergencies, call 999 immediately.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.brown,
                          fontWeight: FontWeight.bold
                        ),
                      )
                    ),
                  ],
                ),
              ),
              // Chat List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: FloodState.chatHistory.length,
                  itemBuilder: (ctx, i) {
                    final msg = FloodState.chatHistory[i];
                    final isAi = msg["role"] == "ai";
                    return Align(
                      alignment: 
                        isAi ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isAi ? Colors.grey[200] : Colors.blue[100],
                          borderRadius: BorderRadius.circular(15)
                        ),
                        child: Text(msg["msg"]!),
                      ),
                    );
                  },
                ),
              ),
              // Input Field
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  left: 16,
                  right: 16
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        decoration: const InputDecoration(
                          hintText: "Ask for help...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(50))
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FloatingActionButton.small(
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.send, color: Colors.white),
                      onPressed: () async {
                        final text = _msgController.text.trim();
                        if (text.isEmpty) return;

                        setSheetState(() {
                          FloodState.chatHistory.add({"role": "user", "msg": text});
                          _msgController.clear();
                        });

                        final reply = await _geminiService.getSafetyAdvice(text);

                        setSheetState(() => 
                          FloodState.chatHistory.add({"role": "ai", "msg": reply}));
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

  // ---- PHASE 4: RESCUE SIMULATION (THE RED LINE) ----
  void _handleRescueRoute() async {
    setState(() => _isAnalyzing = true);
    await Future.delayed(const Duration(seconds: 2)); // Fake calculation time

    setState(() {
      _isAnalyzing = false;
      // Draw a Blue Route avoiding the Red Circle
      _polylines.add(
        Polyline(
          polylineId: const PolylineId("safe_route"),
          color: Colors.blue,
          width: 5,
          points: const [
            LatLng(3.1390, 101.6869), // Start: KLCC
            LatLng(3.1420, 101.6900),
            LatLng(3.1480, 101.6920), // Waypoint: Avoiding the flood
            LatLng(3.1500, 101.6950), // End: Near Masjid Jamek
          ],
        ),
      );
    });

    _showDialog(
      "ROUTE CALCULATED", 
      "Optimal path found. Avoiding 1 critical zone.", 
      false);
  }

  void _showDialog(String title, String body, bool isDanger) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: Text(title, style: TextStyle(color: isDanger ? Colors.red : Colors.green)),
        content: Text(body),
        actions: [TextButton(
          onPressed: () => Navigator.pop(ctx), 
          child: const Text("OK"))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1: THE GOOGLE MAP BASE LAYER
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: _klCenter,
              zoom: 15),
            markers: _markers,
            circles: _circles,
            polylines: _polylines,
            zoomControlsEnabled: false,
            style: _darkMapStyle,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),

          // 2: LOADING OVERLAY
          if (_isAnalyzing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ), 

          // 3: TOP BAR (BACK BUTTON + MODE INDICATOR)
          SafeArea(
            child: Padding(
              padding: const EdgeInsetsGeometry.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Back Button
                  FloatingActionButton.small(
                    heroTag: "back_btn",
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),

                  const Spacer(),

                  // Mode Label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [const BoxShadow(blurRadius: 10, color: Colors.black26)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isRescuerMode ? Icons.shield : Icons.person,
                          color: _isRescuerMode ? Colors.red : Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRescuerMode ? "RESCUER MODE" : "CIVILIAN MODE",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isRescuerMode ? Colors.red : Colors.blue
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),


          // 4: THE ACTION PANEL
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: _isRescuerMode ? 
              _buildRescuerControls() : _buildUserControls(),
          ),
        ],
      ),
    );
  }

  // ---- UI FOR RESCUE MODE ----
  Widget _buildRescuerControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [const BoxShadow(blurRadius: 15, color: Colors.black26)],
      ),
      child: Column(
        //crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 10),
              Text("COMMAND CENTER", style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
          const Divider(),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("Masjid Jamek (Zone A)"),
            subtitle: Text("Water Depth: 1.2m"),
            trailing: Text("CRITICAL", style: TextStyle(
              color: Colors.red, fontWeight: FontWeight.bold)),
          ),
          //const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _handleRescueRoute,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[800],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ), 
            child: const Text("CALCULATE FASTEST RESCUE ROUTE"),
          )
        ],
      ),
    );
  }

  // ---- UI FOR CIVILIAN MODE ----
  Widget _buildUserControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Chatbot Floating Button
        FloatingActionButton.extended(
          onPressed: _openSafetyChat, 
          label: const Text("Safety AI"),
          icon: const Icon(Icons.chat_bubble),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
        const SizedBox(height: 15),

        // Report Flood Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text("REPORT FLOOD (AI VERIFY)"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              // textStyle: const TextStyle(
              //   fontSize: 16, 
              //   fontWeight: FontWeight.bold),
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