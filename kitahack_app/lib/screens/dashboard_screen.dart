import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const LatLng _klCenter = LatLng(3.1390, 101.6869);

  bool _isRescuerMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1: THE GOOGLE MAP BASE LAYER
          GoogleMap(initialCameraPosition: const CameraPosition(
            target: _klCenter,
            zoom: 14
            ),
            mapType: MapType.normal,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            markers: {},
          ),

          // 2: THE ROLE SWITCHER
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26, 
                        blurRadius: 10, 
                        offset: Offset(0, 4))
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20, 
                    vertical: 8
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Civilian",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isRescuerMode ? Colors.grey : Colors.blue)
                      ),
                      Switch(
                        value: _isRescuerMode, 
                        activeThumbColor: Colors.red,
                        inactiveThumbColor: Colors.blue,
                        onChanged: (val) {
                          setState(() {
                            _isRescuerMode = val;
                          });
                        },
                      ),
                      Text("Rescuer",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isRescuerMode ? Colors.red : Colors.grey)
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3: THE ACTION PANEL
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
              SizedBox(width: 10),
              Text("COMMAND CENTER", style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const Divider(),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("CRITICAL: Masjid Jamek Area"),
            subtitle: Text("Water Level: 1.5m (Rising Fast)"),
            trailing: Text("70% Chance", style: TextStyle(
              color: Colors.red, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              // TODO: Call Google Routes API
            },
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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Chatbot Floating Button
        FloatingActionButton.extended(
          onPressed: () {
            // TODO: Link to Gemini Chatbot
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Opening AI Safety Assistant...")),
            );
          }, 
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
              textStyle: const TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () {
              // TODO: Open Camera & Gemini Version
              print("Open Camera for AI Verification");
            },
          ),
        ),
      ],
    );
  }  
}