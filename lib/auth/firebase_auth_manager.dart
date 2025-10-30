import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around [FirebaseAuth] that exposes the pieces of
/// anonymous authentication the app uses.
class FirebaseAuthManager {
  FirebaseAuthManager({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isSignedIn => currentUser != null;

  Future<User?> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    return credential.user;
  }

  Future<void> signOut() => _auth.signOut();
}
