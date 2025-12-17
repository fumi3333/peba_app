import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/tracking/tracking_service.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  String? errorMessage;
  
  // 1. Try Initialize Firebase (Timeout 5s - bumped slightly)
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 5));
  } catch (e) {
    errorMessage = "Firebase 初期化失敗… (´；ω；｀) : $e";
  }
  
  // 2. Try Initialize Background Service (Only if Firebase passed, otherwise pointles to restart service logging)
  if (errorMessage == null) {
      try {
        await TrackingService.initialize().timeout(const Duration(seconds: 3));
      } catch (e) {
        // Service missing isn't critical for UI logging, so we just log warning but continue
        print("WARNING: Background Service Init Failed: $e");
      }
  }

  if (errorMessage != null) {
      print("CRITICAL: $errorMessage");
      print("Bypassing error to show UI...");
  }
  
  // Force launch UI for design verification
  runApp(const ProviderScope(child: PebaApp()));
}

class ErrorApp extends StatelessWidget {
  final String message;
  const ErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.white),
                const SizedBox(height: 16),
                const Text("初期化エラー (´・ω・｀)", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), 
                const SizedBox(height: 16),
                Text(message, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PebaApp extends StatelessWidget {
  const PebaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peba',
      theme: ThemeData.dark(), // Minimum viable dark mode
      home: const HomeScreen(),
    );
  }
}
