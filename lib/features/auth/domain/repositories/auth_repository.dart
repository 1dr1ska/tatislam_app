import 'package:tatislam_app/features/auth/domain/entities/user_profile.dart';

abstract class AuthRepository {
  Future<UserProfile?> signIn(String email, String password);
  Future<UserProfile?> signUp(String email, String password);
  Future<void> signOut();
  Future<UserProfile?> getCurrentUser();
  Stream<UserProfile?> get authStateChanges;
  Future<UserProfile?> getUserProfile(String userId);
}
