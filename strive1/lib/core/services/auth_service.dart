import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_profile.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );
  final FirestoreService _firestoreService = FirestoreService();

  // Local role management (to distinguish parent vs student device on same account)
  static const String _roleKey = 'device_user_role';

  Future<void> saveLocalRole(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role.name);
  }

  Future<UserRole?> getLocalRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleName = prefs.getString(_roleKey);
    if (roleName == null) return null;
    return UserRole.values.firstWhere(
      (e) => e.name == roleName,
      orElse: () => UserRole.student,
    );
  }

  Future<void> clearLocalRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
  }

  // Current
  User? get currentUser => _auth.currentUser;

  // Changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Authentication
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // cancelled
      }

      // details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      rethrow;
    }
  }

  Future<void> patchLegacyProfile(User user) async {
    final existingProfile = await _firestoreService.getUserProfile();
    if (existingProfile != null &&
        existingProfile.email.isEmpty &&
        user.email != null &&
        user.email!.isNotEmpty) {
      await _firestoreService.saveUserProfile(UserProfile(
        uid: existingProfile.uid,
        email: user.email!.trim().toLowerCase(),
        role: existingProfile.role,
      ));
    }
  }

  Future<void> ensureProfileExists(User user, UserRole selectedRole) async {
    // Check if the user already has a profile (to prevent overwriting their role on every login)
    final existingProfile = await _firestoreService.getUserProfile();
    if (existingProfile == null) {
      await _firestoreService.saveUserProfile(UserProfile(
        uid: user.uid,
        email: user.email?.trim().toLowerCase() ?? "",
        role: selectedRole,
      ));
    } else {
      // Patch legacy accounts that don't have the email field saved in Firestore
      if (existingProfile.email.isEmpty && user.email != null && user.email!.isNotEmpty) {
        await _firestoreService.saveUserProfile(UserProfile(
          uid: existingProfile.uid,
          email: user.email!.trim().toLowerCase(),
          role: existingProfile.role,
        ));
      }
    }
  }

  // Email
  Future<UserCredential?> signUpWithEmail(
      String email, String password, UserRole role) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    if (cred.user != null) {
      final profile = UserProfile(
        uid: cred.user!.uid,
        email: email.trim().toLowerCase(),
        role: role,
      );
      await _firestoreService.saveUserProfile(profile);
    }
    return cred;
  }

  // Email
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    if (cred.user != null) {
      // we check for existing profile to patch missing email for legacy users
      final existingProfile = await _firestoreService.getUserProfile();
      if (existingProfile != null && existingProfile.email.isEmpty && cred.user!.email != null) {
        await _firestoreService.saveUserProfile(UserProfile(
          uid: existingProfile.uid,
          email: cred.user!.email!.trim().toLowerCase(),
          role: existingProfile.role,
        ));
      }
    }
    return cred;
  }

  // Password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Sign
  Future<void> signOut() async {
    await clearLocalRole(); // Reset device role on logout
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
