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

  @override
  void initState() {
    super.initState();
    _isRescuerMode = widget.isRescuerMode;
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

  // ---- PHASE 2: VISUAL INTELLIGENCE (CAMERA) ----
  Future<void> _handleReportFlood() async {
    // 1. Pick Image
    //final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
    if (photo == null) return;

    setState(() => _isAnalyzing = true);

    // 2. Send to Gemini
    try {
      final result = await _geminiService.analyzeFloodImage(File(photo.path));

      if (result['isFlood'] == true) {
        // 3. If Flood Confirmed, Add Marker
        _addFloodMarker(result);
        _showDialog("DANGER CONFIRMED", "Severity: ${result['severity']}/5\n${result['description']}", true);
      } else {
        _showDialog("Safe", "Gemini did not detect a flood.", false);
      } 
    } catch (e) {
      _showDialog("Error", "Could not analyze image. Try again.", false);
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _addFloodMarker(Map<String, dynamic> data) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(DateTime.now().toString()),
          position: _klCenter,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: "CONFIRMED FLOOD (Level ${data['severity']})",
            snippet: data['description'],
          ),
        ),
      );
    });
  }

  // ---- PHASE 3: SAFETY CHATBOT ----
  void _openSafetyChat() {
    TextEditingController _msgController = TextEditingController();
    List<Map<String, String>> chatHistory = [
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
                  itemCount: chatHistory.length,
                  itemBuilder: (ctx, i) {
                    final isAi = chatHistory[i]["role"] == "ai";
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
                        child: Text(chatHistory[i]["msg"]!),
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
                          chatHistory.add({"role": "user", "msg": text});
                          _msgController.clear();
                        });

                        final reply = await _geminiService.getSafetyAdvice(text);

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

  // ---- PHASE 4: RESCUE SIMULATION (THE RED LINE) ----
  void _handleRescueRoute() async {
  setState(() => _isAnalyzing = true);

  final result = await RoutesApi.getRoute(
    originLat: 3.1390,   // rescuer start point (KLCC)
    originLng: 101.6869,
    destLat: 3.1500,     // flood zone destination (Masjid Jamek)
    destLng: 101.6950,
  );

  if (result != null) {
    final routes = result['routes'] as List;
    if (routes.isNotEmpty) {
      final distance = routes[0]['distanceMeters'];
      final duration = routes[0]['duration'];

      setState(() {
        _isAnalyzing = false;
        // Still draw the blue line on map
        _polylines.add(
          Polyline(
            polylineId: const PolylineId("safe_route"),
            color: Colors.blue,
            width: 5,
            points: const [
              LatLng(3.1390, 101.6869),
              LatLng(3.1420, 101.6900),
              LatLng(3.1480, 101.6920),
              LatLng(3.1500, 101.6950),
            ],
          ),
        );
      });

      _showDialog(
        "ROUTE CALCULATED",
        "Distance: ${(distance / 1000).toStringAsFixed(1)} km\nETA: $duration\nAvoiding 1 critical flood zone.",
        false,
      );
    }
  } else {
    setState(() => _isAnalyzing = false);
    _showDialog("Error", "Could not calculate route. Check API key.", true);
  }
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