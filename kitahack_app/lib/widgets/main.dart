import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kitahack_app/screens/home_screen.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const ResilienceBuilderApp());
}

class ResilienceBuilderApp extends StatelessWidget {
  const ResilienceBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResilienceBuilder',
      theme: ThemeData(
        // Use a "Warning" color scheme
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
      ),
      home: const HomeScreen(), // Start at the Map
    );
  }
}