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
    } catch (e) {
        print("LogRepository: Firestore Write Error: $e");
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
