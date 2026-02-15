import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // APP TITLE
              Text("Resilience\nBuilder",
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent[700]
                ),
              ),
              const Text(
                "Kuala Lumpur Crisis Response", 
                style: TextStyle(color: Colors.grey)),
              const Spacer(),

              // OPTION 1: CIVILIAN
              _buildRoleCard(
                context,
                title: "I Need Help",
                subtitle: "Report floods & get safety advice",
                icon: Icons.health_and_safety,
                color: Colors.blue,
                isRescuer: false,
              ),

              const SizedBox(height: 20),

              // OPTION 2: RESCUER
              _buildRoleCard(
                context,
                title: "I Am A Rescuer",
                subtitle: "View command center & routes",
                icon: Icons.emergency,
                color: Colors.red,
                isRescuer: true,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon, 
    required Color color,
    required bool isRescuer
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(isRescuerMode: isRescuer),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color
                  )),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color)
          ],
        ),
      ),
    );
  }
}