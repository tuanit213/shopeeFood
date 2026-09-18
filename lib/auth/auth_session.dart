import '../domain/user/app_user.dart';
import '../repositories/auth_repository.dart';
import 'firebase_auth_repository.dart';

abstract final class AuthSession {
  static final AuthRepository _repository = FirebaseAuthRepository();

  static AppUser? get currentUser => _repository.currentUser;
  static Stream<AppUser?> get changes => _repository.authStateChanges;

  static Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
    required String phone,
  }) => _repository.signUp(
    email: email,
    password: password,
    displayName: displayName,
    phone: phone,
  );

  static Future<AppUser> signIn({
    required String email,
    required String password,
  }) => _repository.signIn(email: email, password: password);

  static Future<void> signOut() => _repository.signOut();
}
