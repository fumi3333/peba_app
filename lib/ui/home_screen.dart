import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../features/auth/auth_service.dart';
import '../features/logging/log_repository.dart';
import '../features/tracking/tracking_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Mock settings for MVP
  final double hourlyWage = 1500; 

  @override
  void initState() {
    super.initState();
    // Ensure we sign in immediately
    ref.read(authServiceProvider).signInAnonymously();
  }

  Future<void> _setWorkplace() async {
    // Check permissions first
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Open settings
      await Geolocator.openAppSettings();
      return;
    }

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('work_lat', position.latitude);
    await prefs.setDouble('work_lng', position.longitude);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('勤務地セット完了！計測開始だ (｀･ω･´)ゞ')), 
      );
    }
    
    // Start Service if not running
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      service.startService();
    }
  }

  Future<void> _onStressPressed() async {
    // 1. Log "Stress"
    final position = await Geolocator.getCurrentPosition();
    await ref.read(logRepositoryProvider).logEntry(
      latitude: position.latitude, 
      longitude: position.longitude, 
      isMock: position.isMocked,
      note: 'STRESS BUTTON'
    );
    
    // 2. Feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('記録完了！お疲れ様です (｀･ω･´)ゞ 推定 +500円'), 
          duration: Duration(seconds: 1),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logStream = ref.watch(logRepositoryProvider).getLogStream();

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark mode for tired eyes
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '未払い額', // Simplified title
                style: TextStyle(color: Colors.grey, letterSpacing: 2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              StreamBuilder(
                stream: logStream,
                builder: (context, snapshot) {
                  // Fix for Infinite Loading:
                  // If connection is waiting (initial load) OR no data, just show default 0.
                  // We do NOT want to show a loader that might hang if Firebase is offline.
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                       return const Text(
                        '¥ 0',
                        style: TextStyle(
                          color: Colors.white30,
                          fontSize: 64, 
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Monospace'
                        ),
                        textAlign: TextAlign.center,
                      );
                  }

                  // If we have no data (e.g. empty stream from offline mode, or just no logs yet)
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                       return const Text(
                        '¥ 0',
                        style: TextStyle(
                          color: Colors.white30,
                          fontSize: 64, 
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Monospace'
                        ),
                        textAlign: TextAlign.center,
                      );
                  }
                  
                  final docs = snapshot.data!.docs;
                  double totalHours = docs.length * 0.25; 
                  int amount = (totalHours * hourlyWage).round();

                  return Text(
                    '¥ $amount',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Monospace'
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 48),
              
              const Spacer(),
              
              // Stress Button -> "勤怠" (Clean)
              GestureDetector(
                onTap: _onStressPressed,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent, width: 2)
                  ),
                  child: const Center(
                    child: Text(
                      '勤怠', 
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 24
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              
              const Spacer(),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                   TextButton.icon(
                    onPressed: _setWorkplace, 
                    icon: const Icon(Icons.location_on, color: Colors.white70),
                    label: const Text('勤務地を設定', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
