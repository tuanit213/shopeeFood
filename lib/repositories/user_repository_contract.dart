import '../domain/user/app_user.dart';

abstract interface class UserRepositoryContract {
  Future<AppUser?> getById(String uid);
  Future<void> updateProfile(AppUser user);
}
