import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  try {
    return AuthService(FirebaseAuth.instance);
  } catch (e) {
    print("AuthService: Firebase not ready. Using mock/null.");
    return AuthService(null);
  }
});

final userIdStreamProvider = StreamProvider<String?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges.map((user) => user?.uid);
});

class AuthService {
  final FirebaseAuth? _auth;

  AuthService(this._auth);

  Stream<User?> get authStateChanges {
    if (_auth == null) return const Stream.empty();
    return _auth!.authStateChanges();
  }

  Future<User?> signInAnonymously() async {
    if (_auth == null) {
      print("AuthService: SignIn ignored (No Firebase)");
      return null;
    }
    try {
      final userCredential = await _auth!.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      print('Auth Error: $e');
      return null;
    }
  }

  String? get currentUserId => _auth?.currentUser?.uid;
}
