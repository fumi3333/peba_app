import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ntp/ntp.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

// NOTE: This service runs in a separate isolate (background).
// We cannot easily inject Riverpod providers here without complex setup.
// For MVP, we will duplicate some logic or use direct singleton access where possible.

class TrackingService {
  static const String notificationChannelId = 'peba_foreground';
  static const int notificationId = 888;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Android Notification Setup
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Peba 常駐サービス', // Peba Service
      description: 'Pebaが静かに監視中...', // Peba is silently watching...
      importance: Importance.low,
    );

    await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Peba 動作中', // Peba Active
        initialNotificationContent: '監視を開始しました...', // Monitoring implementation...
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Initialize Firebase in this isolate
    await Firebase.initializeApp();
    
    // Ensure DartUI is ready
    DartPluginRegistrant.ensureInitialized();
    
    // Check SharedPrefs for Workplace Location
    final prefs = await SharedPreferences.getInstance();
    
    // Periodic Timer (e.g., every 15 minutes to save battery but catch entries)
    // For MVP demo, lets might make it faster, but requirement said "periodic".
    Timer.periodic(const Duration(minutes: 15), (timer) async {
       if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // Update notification
          service.setForegroundNotificationInfo(
            title: "Peba 監視中", // Peba Monitoring
            content: "最終スキャン: ${DateTime.now()}", // Last scan:
          );
        }
      }
      
      await _performCheck(prefs);
    });
  }
  
  static Future<void> _performCheck(SharedPreferences prefs) async {
      // 1. Get Current Location
      try {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        
        // 2. Get Workplace Location
        double? workLat = prefs.getDouble('work_lat');
        double? workLng = prefs.getDouble('work_lng');
        
        if (workLat == null || workLng == null) return;
        
        // 3. Calculate Distance
        double distanceInMeters = Geolocator.distanceBetween(
          position.latitude, 
          position.longitude, 
          workLat, 
          workLng
        );
        
        // 4. Logic: If inside 100m, Log IT.
        // For MVP, we log every check if inside, or if we just entered/exited.
        // To keep it simple stateless: Log if inside radius.
        
        if (distanceInMeters <= 100) {
            await _logToFirestore(position, "STAY");
        } 
        
        // Advanced: We could track state (wasOutside -> nowInside = IN) using SharedPreferences
        // But "Complete Automatic" logging every 15 mins while available is safer evidence than missing an edge case.
        
      } catch (e) {
        print("Peba Tracking Error: $e");
      }
  }

  static Future<void> _logToFirestore(Position position, String note) async {
      try {
          // Safeguard: Check if Firebase is actually init in this isolate?
          // If not, accessing instance might throw or be null.
          
          final instance = FirebaseAuth.instance; // Might throw
          final user = instance.currentUser;
          if (user == null) return;
          
          DateTime timestamp = await NTP.now();
          
          final rawString = '${user.uid}-${timestamp.toIso8601String()}-${position.latitude}-${position.longitude}';
          final digest = sha256.convert(utf8.encode(rawString));

          await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('logs').add({
            'timestamp': Timestamp.fromDate(timestamp),
            'location': GeoPoint(position.latitude, position.longitude),
            'isMock': position.isMocked,
            'hash': digest.toString(),
            'note': note,
            'generated_by': 'background_service'
          });
      } catch (e) {
          print("Log Error: $e");
      }
  }

}
