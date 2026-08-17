import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Current User ───────────────────────────────────────────
  User? get currentUser => _auth.currentUser;

  // ─── Auth State Stream ───────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── Register ───────────────────────────────────────────────
  Future<UserModel?> register({
    required String email,
    required String password,
    required String role,
    String? name,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (name != null && name.isNotEmpty) {
        try {
          await cred.user?.updateDisplayName(name);
        } catch (_) {}
      }

      final user = UserModel(
        uid: cred.user!.uid,
        email: email,
        role: role,
      );

      final userMap = user.toMap();
      if (name != null && name.isNotEmpty) {
        userMap['name'] = name;
      }
      if (role == 'ngo') {
        userMap['status'] = 'pending';
      }
      if (role == 'donor') {
        userMap['verified'] = false;
      }

      // Save user to Firestore
      await _db
          .collection('users')
          .doc(cred.user!.uid)
          .set(userMap);

      if (role == 'ngo' && name != null && name.isNotEmpty) {
        await _db.collection('ngos').doc(cred.user!.uid).set({
          'id': cred.user!.uid,
          'name': name,
          'email': email,
        }, SetOptions(merge: true));
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Login ───────────────────────────────────────────────────
  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final doc = await _db
          .collection('users')
          .doc(cred.user!.uid)
          .get();

      if (!doc.exists) throw 'User data not found';

      final data = doc.data()!;

      // ── Ban check ──────────────────────────────────────────────
      if (data['banned'] == true) {
        await _auth.signOut(); // Force sign-out immediately
        throw 'Your account has been suspended. Please contact support.';
      }

      await _db.collection('users').doc(cred.user!.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      return UserModel.fromMap(data);
    } on FirebaseAuthException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Get User Role ───────────────────────────────────────────
  Future<String?> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['role'];
  }

  // ─── Forgot Password ─────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Logout ──────────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ─── Error Handler ───────────────────────────────────────────
  String _handleError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'Account already exists with this email';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      default:
        return 'Something went wrong. Please try again';
    }
  }
}