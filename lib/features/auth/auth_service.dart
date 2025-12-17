import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(FirebaseAuth.instance);
});

final userIdStreamProvider = StreamProvider<String?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges.map((user) => user?.uid);
});

class AuthService {
  final FirebaseAuth _auth;

  AuthService(this._auth);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      // For MVP we just print error, in prod we should log it
      print('Auth Error: $e');
      return null;
    }
  }

  String? get currentUserId => _auth.currentUser?.uid;
}
