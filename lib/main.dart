import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/tracking/tracking_service.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Try Initialize Firebase (Timeout 3s)
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 3));
  } catch (e) {
    print("WARNING: Firebase Init Failed or Timed out. App running in Offline/Fallback mode. Error: $e");
  }
  
  // 2. Try Initialize Background Service (Timeout 3s)
  try {
    // Initialize Background Service
    await TrackingService.initialize().timeout(const Duration(seconds: 3));
  } catch (e) {
    print("WARNING: Background Service Init Failed. Tracking disabled. Error: $e");
  }

  runApp(const ProviderScope(child: PebaApp()));
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
