import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/session.dart';
import '../../models/user_profile.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Retries [fn] up to [maxAttempts] times with exponential backoff
  /// when Firestore throws an `unavailable` error.
  Future<T> _withRetry<T>(Future<T> Function() fn, {int maxAttempts = 3}) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } on FirebaseException catch (e) {
        attempt++;
        final isRetryable = e.code == 'unavailable' || e.code == 'deadline-exceeded';
        if (!isRetryable || attempt >= maxAttempts) {
          debugPrint('[FirestoreService] Non-retryable or max attempts reached: ${e.code}');
          rethrow;
        }
        final delay = Duration(milliseconds: 500 * (1 << attempt)); // 1s, 2s, 4s
        debugPrint('[FirestoreService] Retrying after $delay (attempt $attempt)...');
        await Future.delayed(delay);
      }
    }
  }

  // Collection
  CollectionReference? get _userSessions {
    final uid = currentUserId;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('sessions');
  }

  // Firestore
  Future<void> saveSession(Session session) async {
    final docRef = _userSessions?.doc(); // generate
    if (docRef != null) {
      await docRef.set({
        'start_time': session.startTime,
        'duration_seconds': session.durationSeconds,
        'engagement_score': session.engagementScore,
        'study_mode': session.studyMode,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  // sessions
  Future<List<Session>> getSessions() async {
    final collection = _userSessions;
    if (collection == null) return [];

    final snapshot =
        await collection.orderBy('start_time', descending: true).get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return Session(
        id: null, // Firestore
        startTime: data['start_time'],
        durationSeconds: data['duration_seconds'],
        engagementScore: data['engagement_score'],
        studyMode: data['study_mode'],
      );
    }).toList();
  }

  // sessions
  Stream<List<Session>> getSessionsStream() {
    final collection = _userSessions;
    if (collection == null) return Stream.value([]);

    return collection
        .orderBy('start_time', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Session(
          id: null,
          startTime: data['start_time'],
          durationSeconds: data['duration_seconds'],
          engagementScore: data['engagement_score'],
        );
      }).toList();
    });
  }

  // Guardian Management
  Future<void> setGuardian(String name, String email) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'guardian_name': name,
      'guardian_email': email,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getGuardian() async {
    final uid = currentUserId;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    
    final data = doc.data() as Map<String, dynamic>;
    if (data['guardian_email'] != null && data['guardian_email'].toString().isNotEmpty) {
      return {
        'name': data['guardian_name'],
        'email': data['guardian_email'],
      };
    }
    return null;
  }

  Future<void> removeGuardian() async {
    final uid = currentUserId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'guardian_name': FieldValue.delete(),
      'guardian_email': FieldValue.delete(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }


  // ── Parent / Student Role Management ──────────────────────────────────────

  /// Saves or updates the user's profile (role, email) in Firestore.
  Future<void> saveUserProfile(UserProfile profile) async {
    await _withRetry(() => _db.collection('users').doc(profile.uid).set(
          profile.toMap(),
          SetOptions(merge: true),
        ));
  }

  /// Updates ONLY the role field for the currently logged-in user.
  Future<void> setUserRole(UserRole role) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _withRetry(() => _db.collection('users').doc(uid).set({
      'role': role.name,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)));
  }

  /// Saves the FCM token for the student device so the Cloud Function can send pushes to it.
  Future<void> setStudentFCMToken(String token) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _withRetry(() => _db.collection('users').doc(uid).set({
      'student_fcm_token': token,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)));
  }

  /// Fetches the profile for the currently logged-in user.
  Future<UserProfile?> getUserProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    try {
      final doc = await _withRetry(() => _db.collection('users').doc(uid).get());
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      if (!data.containsKey('role')) return null;
      return UserProfile.fromMap({...data, 'uid': doc.id});
    } on FirebaseException catch (e) {
      debugPrint('[FirestoreService] getUserProfile failed: ${e.code}');
      return null;
    }
  }

  /// Real-time stream of the current user's profile.
  Stream<UserProfile?> getUserProfileStream() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(null);
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      if (!data.containsKey('role')) return null;
      return UserProfile.fromMap({...data, 'uid': doc.id});
    });
  }

  /// Parent: look up a student account by email.
  /// Returns the student uid if found, or throws an exception with specific details.
  Future<String?> findStudentByEmail(String email) async {
    final parentEmail = _auth.currentUser?.email;
    if (parentEmail == null) throw Exception("You must be logged in.");

    final query = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
        
    if (query.docs.isEmpty) return null;
    
    final doc = query.docs.first;
    final data = query.docs.first.data();
    
    // Check if the user is indeed a student
    if (data['role'] != 'student') {
      throw Exception("This email is registered as a Parent account, not a Student.");
    }

    final guardianEmail = data['guardian_email'] as String?;
    if (guardianEmail == null || guardianEmail.trim().toLowerCase() != parentEmail.trim().toLowerCase()) {
      throw Exception("The student must first set YOUR email in their 'Guardian Account' settings.");
    }
    
    return doc.id;
  }

  /// Links a parent to a student by saving the student's uid to the parent's profile.
  Future<void> linkParentToStudent(String studentUid) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'linked_student_id': studentUid,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Unlinks a student from the parent's profile.
  Future<void> unlinkStudent() async {
    final uid = currentUserId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'linked_student_id': FieldValue.delete(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // ── Remote Session Control ─────────────────────────────────────────────────

  /// Parent: writes a remote start command to the student's command doc.
  Future<void> sendRemoteStartCommand(
      String studentUid, int durationMinutes, List<String> blockedApps) async {
    await _db.collection('remote_commands').doc(studentUid).set({
      'action': 'start',
      'duration_minutes': durationMinutes,
      'blocked_apps': blockedApps,
      'issued_at': FieldValue.serverTimestamp(),
      'command_id': DateTime.now().millisecondsSinceEpoch, // Unique ID for this command instance
      'handled': false,
      'status': 'pending', // pending → started (set by student phone)
    });
  }

  /// Parent: streams the command document to watch for student acknowledgement.
  Stream<Map<String, dynamic>?> watchCommandStatus(String studentUid) {
    return _db
        .collection('remote_commands')
        .doc(studentUid)
        .snapshots()
        .map((snap) => snap.exists ? snap.data() : null);
  }

  /// Student: streams their own remote command document.
  Stream<Map<String, dynamic>?> getRemoteCommandStream() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(null);
    return _db
        .collection('remote_commands')
        .doc(uid)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      return snap.data();
    });
  }

  /// Student: marks the remote command as handled and sets status to 'started'.
  Future<void> markCommandHandled() async {
    final uid = currentUserId;
    if (uid == null) return;
    await _db
        .collection('remote_commands')
        .doc(uid)
        .set({'handled': true, 'status': 'started'}, SetOptions(merge: true));
  }

  /// Parent: fetch the linked student's sessions list.
  Future<List<Session>> getStudentSessions(String studentUid) async {
    final snapshot = await _db
        .collection('users')
        .doc(studentUid)
        .collection('sessions')
        .orderBy('start_time', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Session(
        id: null,
        startTime: data['start_time'] ?? '',
        durationSeconds: data['duration_seconds'] ?? 0,
        engagementScore:
            (data['engagement_score'] ?? 0.0).toDouble(),
        studyMode: data['study_mode'],
      );
    }).toList();
  }

  /// Returns the email stored in any user doc by uid.
  Future<String?> getUserDocEmail(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    return data?['email'] as String?;
  }
}
