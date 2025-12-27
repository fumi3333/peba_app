import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logging/log_repository.dart';

// NOTE: This service runs in a separate isolate (background).
// We cannot easily inject Riverpod providers here without complex setup.
// For MVP, we will duplicate some logic or use direct singleton access where possible.

class TrackingService {
  static const String notificationChannelId = 'peba_foreground';
  static const int notificationId = 888;

  // Riverpod container for background isolate
  static ProviderContainer? _container;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Android Notification Setup
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Peba 常駐サービス',
      description: 'Pebaが静かに監視中...', 
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

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
        initialNotificationTitle: 'Peba 動作中', 
        initialNotificationContent: '監視を開始しました',
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

    // Initialize Riverpod container for this isolate
    _container = ProviderContainer();
    
    // Periodic Timer (e.g., every 15 minutes to save battery but catch entries)
    // For MVP demo, lets might make it faster, but requirement said "periodic".
    Timer.periodic(const Duration(minutes: 15), (timer) async {
       if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // Update notification
          service.setForegroundNotificationInfo(
            title: "Peba 監視スキャン", 
            content: "最終更新: ${DateTime.now()}",
          );
        }
      }
      
      await _performCheck();
    });
  }
  
  static Future<void> _performCheck() async {
      // 1. Get Current Location
      try {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        
        final prefs = await SharedPreferences.getInstance();
        final double? workLat = prefs.getDouble('work_lat');
        final double? workLng = prefs.getDouble('work_lng');
        final int hourlyWage = prefs.getInt('hourly_wage') ?? 1500; // Read hourly_wage
        
        if (workLat == null || workLng == null) return;
        
        // 3. Calculate Distance
        double distanceInMeters = Geolocator.distanceBetween(
          position.latitude, 
          position.longitude, 
          workLat, 
          workLng
        );
        
        // 4. Logic: If inside 200m, Log IT.
        // For MVP, we log every check if inside, or if we just entered/exited.
        // To keep it simple stateless: Log if inside radius.
        
        if (distanceInMeters <= 200) { // Changed radius to 200m
            // Use Riverpod container to access logRepositoryProvider
            await _container!.read(logRepositoryProvider).logEntry(
              latitude: position.latitude, 
              longitude: position.longitude, 
              isMock: position.isMocked,
              note: 'AUTO_TRACKING',
              hourlyWage: hourlyWage, // Pass hourlyWage
            );
        } 
        
        // Advanced: We could track state (wasOutside -> nowInside = IN) using SharedPreferences
        // But "Complete Automatic" logging every 15 mins while available is safer evidence than missing an edge case.
        
      } catch (e) {
        print("Peba Tracking Error: $e");
      }
  }



}
