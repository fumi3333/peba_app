import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/tracking/tracking_service.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Initialize Background Service
  await TrackingService.initialize();

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
