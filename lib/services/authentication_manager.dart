import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthenticationManager {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static bool _hasAuthenticatedWithEmailPassword = false;

  static bool get isAuthenticated => _auth.currentUser != null;
  static bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;
  static bool get isRealUser => isAuthenticated && !isAnonymous;
  static bool get canEdit {
    final result = _hasAuthenticatedWithEmailPassword || isRealUser;
    debugPrint(
      'DEBUG AuthManager: canEdit = $result (_hasAuthenticatedWithEmailPassword: $_hasAuthenticatedWithEmailPassword, isRealUser: $isRealUser)',
    );
    return result;
  }

  static Future<void> initializeAuthentication() async {
    try {
      // Check if there's already a signed-in user
      if (_auth.currentUser != null && !_auth.currentUser!.isAnonymous) {
        _hasAuthenticatedWithEmailPassword = true;
        debugPrint('User already signed in - editing enabled');
        return;
      }

      // Otherwise, sign in anonymously for viewing only
      await _auth.signInAnonymously();
      debugPrint('Signed in anonymously - view only mode');
    } catch (e) {
      debugPrint('Authentication initialization failed: $e');
      rethrow;
    }
  }

  static Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      debugPrint('DEBUG AuthManager: Attempting email/password sign-in');
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _hasAuthenticatedWithEmailPassword = true;
      debugPrint(
        'DEBUG AuthManager: Email/password sign-in successful - _hasAuthenticatedWithEmailPassword = $_hasAuthenticatedWithEmailPassword',
      );
      debugPrint('Signed in with email/password - can now edit');
      return credential;
    } catch (e) {
      debugPrint('Email/password sign-in failed: $e');
      rethrow;
    }
  }

  static Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _hasAuthenticatedWithEmailPassword = true;
      debugPrint('Created user and signed in - can now edit');
      return credential;
    } catch (e) {
      debugPrint('User creation failed: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    _hasAuthenticatedWithEmailPassword = false;
    await _auth.signOut();
    // Sign back in anonymously for viewing
    await initializeAuthentication();
  }
}
