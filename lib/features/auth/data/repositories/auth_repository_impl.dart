import 'package:tatislam_app/features/auth/data/datasources/supabase_auth_data_source.dart';
import 'package:tatislam_app/features/auth/domain/entities/user_profile.dart';
import 'package:tatislam_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseAuthDataSource _dataSource;

  AuthRepositoryImpl(this._dataSource);

  @override
  Future<UserProfile?> signIn(String email, String password) {
    return _dataSource.signIn(email, password);
  }

  @override
  Future<UserProfile?> signUp(String email, String password) {
    return _dataSource.signUp(email, password);
  }

  @override
  Future<void> signOut() {
    return _dataSource.signOut();
  }

  @override
  Future<UserProfile?> getCurrentUser() {
    return _dataSource.getCurrentUser();
  }

  @override
  Stream<UserProfile?> get authStateChanges {
    return _dataSource.authStateChanges;
  }

  @override
  Future<UserProfile?> getUserProfile(String userId) {
    return _dataSource.getUserProfile(userId);
  }
}