import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/role_selection_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  if (kIsWeb) {
    // WEB SETUP (Chrome)
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY'] ?? '', 
        appId: dotenv.env['FIREBASE_APP_ID'] ?? '', 
        messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '', 
        projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '', 
      ),
    );
  } else {
    // MOBILE SETUP (Android/iOS)
    await Firebase.initializeApp();
  }

  runApp(const ResilienceBuilderApp());
}

class ResilienceBuilderApp extends StatelessWidget {
  const ResilienceBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResilienceBuilder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
      ),
      home: const RoleSelectionScreen(),
    );
  }
}