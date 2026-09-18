import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/user/app_user.dart';
import '../repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  AppUser? _cachedUser;

  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : auth = auth ?? FirebaseAuth.instance,
      firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      firestore.collection('users');

  @override
  AppUser? get currentUser => _cachedUser;

  @override
  Stream<AppUser?> get authStateChanges =>
      auth.authStateChanges().asyncMap((firebaseUser) async {
        if (firebaseUser == null) {
          _cachedUser = null;
          return null;
        }
        final snapshot = await _users.doc(firebaseUser.uid).get();
        final profile = snapshot.data();
        if (profile == null) return null;
        return _cachedUser = AppUser.fromJson(
          _normalizeProfile(profile, firebaseUser.uid),
        );
      });

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
    required String phone,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw FirebaseAuthException(code: 'user-null');
    }

    final now = DateTime.now().toUtc();
    final profile = AppUser.customer(
      uid: firebaseUser.uid,
      displayName: displayName,
      phone: phone,
      email: firebaseUser.email ?? email,
      now: now,
    );
    try {
      await _users.doc(firebaseUser.uid).set({
        ...profile.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await firebaseUser.updateDisplayName(profile.displayName);
    } catch (_) {
      await firebaseUser.delete();
      rethrow;
    }
    _cachedUser = profile;
    return profile;
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw FirebaseAuthException(code: 'user-null');
    }
    final snapshot = await _users.doc(firebaseUser.uid).get();
    final profile = snapshot.data();
    if (profile == null) {
      final now = DateTime.now().toUtc();
      _cachedUser = AppUser.customer(
        uid: firebaseUser.uid,
        displayName: firebaseUser.displayName ?? '',
        phone: '',
        email: firebaseUser.email ?? email,
        now: now,
      );
      return _cachedUser!;
    }
    return _cachedUser = AppUser.fromJson(
      _normalizeProfile(profile, firebaseUser.uid),
    );
  }

  @override
  Future<void> signOut() async {
    _cachedUser = null;
    await auth.signOut();
  }

  Map<String, dynamic> _normalizeProfile(
    Map<String, dynamic> profile,
    String uid,
  ) {
    DateTime? date(Object? value) => value is Timestamp ? value.toDate() : null;
    return {
      ...profile,
      'uid': uid,
      'createdAt': date(profile['createdAt']) ?? profile['createdAt'],
      'updatedAt': date(profile['updatedAt']) ?? profile['updatedAt'],
    };
  }
}
