import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:ntp/ntp.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_service.dart';

final logRepositoryProvider = Provider<LogRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  return LogRepository(FirebaseFirestore.instance, authService);
});

class LogRepository {
  final FirebaseFirestore _firestore;
  final AuthService _authService;

  LogRepository(this._firestore, this._authService);

  Future<void> logEntry({
    required double latitude,
    required double longitude,
    required bool isMock,
    String? note,
  }) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    // 1. Get NTP Time (Network Time Protocol) to prevent tampering
    DateTime timestamp;
    try {
      timestamp = await NTP.now();
    } catch (e) {
      // Fallback if NTP fails (though less secure)
      timestamp = DateTime.now();
    }

    // 2. Generate Hash (SHA-256)
    // Data signature: userId + timestamp (ISO) + lat + lng
    final rawString = '$userId-${timestamp.toIso8601String()}-$latitude-$longitude';
    final bytes = utf8.encode(rawString);
    final digest = sha256.convert(bytes);

    // 3. Save to Firestore
    await _firestore.collection('users').doc(userId).collection('logs').add({
      'timestamp': Timestamp.fromDate(timestamp),
      'location': GeoPoint(latitude, longitude),
      'isMock': isMock,
      'hash': digest.toString(),
      'note': note, // e.g., "IN", "OUT", "STRESS"
    });
  }
  
  Stream<QuerySnapshot> getLogStream() {
      final userId = _authService.currentUserId;
      if (userId == null) return const Stream.empty();
      
      return _firestore
          .collection('users')
          .doc(userId)
          .collection('logs')
          .orderBy('timestamp', descending: true)
          .snapshots();
  }
}
