import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // WEB SETUP (Chrome)
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBNG3DRJYnzFi_mB4nIByoWAc22f86cTTI", 
        appId: "1:482793649864:android:aa9025b31a12931e9657fd", 
        messagingSenderId: "482793649864", 
        projectId: "kitahack-487111", 
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
      home: const DashboardScreen(),
    );
  }
}