import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:ntp/ntp.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_service.dart';

final logRepositoryProvider = Provider<LogRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  try {
    return LogRepository(FirebaseFirestore.instance, authService);
  } catch (e) {
     print("LogRepository: Firebase not ready. Using mock/null.");
     return LogRepository(null, authService);
  }
});

class LogRepository {
  final FirebaseFirestore? _firestore;
  final AuthService _authService;

  LogRepository(this._firestore, this._authService);

  Future<void> logEntry({
    required double latitude,
    required double longitude,
    required bool isMock,
    String? note,
    required int hourlyWage,
  }) async {
    if (_firestore == null) {
        print("LogRepository: Dropping log (No Firebase) - $note");
        return;
    }
    
    final userId = _authService.currentUserId;
    if (userId == null) return;

    // 1. Get NTP Time
    DateTime timestamp;
    try {
      timestamp = await NTP.now();
    } catch (e) {
      timestamp = DateTime.now();
    }

    // 2. Generate Hash
    final rawString = '$userId-${timestamp.toIso8601String()}-$latitude-$longitude';
    final bytes = utf8.encode(rawString);
    final digest = sha256.convert(bytes);

    // 3. Save to Firestore
    try {
        await _firestore!.collection('users').doc(userId).collection('logs').add({
          'timestamp': Timestamp.fromDate(timestamp),
          'location': GeoPoint(latitude, longitude),
          'isMock': isMock,
          'hash': digest.toString(),
          'note': note, 
        });
        
        // 4. Update Daily Record
        await _updateDailyRecord(userId, timestamp, latitude, longitude);
        
    } catch (e) {
        print("LogRepository: Firestore Write Error: $e");
    }
  }

  Future<void> _updateDailyRecord(String userId, DateTime timestamp, double lat, double lng) async {
      try {
          // Format Date YYYYMMDD
          final dateStr = "${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}";
          final docRef = _firestore!.collection('users').doc(userId).collection('records').doc(dateStr);
          
          await _firestore!.runTransaction((transaction) async {
              final snapshot = await transaction.get(docRef);
              
              if (!snapshot.exists) {
                  transaction.set(docRef, {
                      'userId': userId,
                      'startTime': Timestamp.fromDate(timestamp),
                      'endTime': Timestamp.fromDate(timestamp),
                      'totalAmount': 375, // 15 mins @ 1500/hr
                      'locations': [GeoPoint(lat, lng)],
                      'date': dateStr
                  });
              } else {
                  final data = snapshot.data() as Map<String, dynamic>;
                  int currentAmount = data['totalAmount'] ?? 0;
                  List<dynamic> locations = data['locations'] ?? [];
                  locations.add(GeoPoint(lat, lng));
                  
                  transaction.update(docRef, {
                      'endTime': Timestamp.fromDate(timestamp),
                      'totalAmount': currentAmount + 375,
                      'locations': locations
                  });
              }
          });
      } catch (e) {
          print("LogRepository: Daily Record Update Error: $e");
      }
  }
  
  Stream<QuerySnapshot> getLogStream() {
      if (_firestore == null) return const Stream.empty();
      
      final userId = _authService.currentUserId;
      if (userId == null) return const Stream.empty();
      
      return _firestore!
          .collection('users')
          .doc(userId)
          .collection('logs')
          .orderBy('timestamp', descending: true)
          .snapshots();
  }
}
