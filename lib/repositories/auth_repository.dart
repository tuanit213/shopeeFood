import '../domain/user/app_user.dart';

abstract interface class AuthRepository {
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
    required String phone,
  });

  Future<AppUser> signIn({required String email, required String password});

  Future<void> signOut();

  AppUser? get currentUser;

  Stream<AppUser?> get authStateChanges;
}
