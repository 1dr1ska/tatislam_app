import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/core/services/supabase_service.dart';
import 'package:tatislam_app/features/auth/data/datasources/supabase_auth_data_source.dart';
import 'package:tatislam_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:tatislam_app/features/auth/domain/entities/user_profile.dart';
import 'package:tatislam_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:tatislam_app/features/auth/domain/usecases/get_current_user.dart';
import 'package:tatislam_app/features/auth/domain/usecases/sign_in.dart';
import 'package:tatislam_app/features/auth/domain/usecases/sign_up.dart';
import 'package:tatislam_app/features/auth/domain/usecases/sign_out.dart';

// Data Source Provider
final authDataSourceProvider = Provider<SupabaseAuthDataSource>((ref) {
  return SupabaseAuthDataSource(SupabaseService.client);
});

// Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dataSource = ref.read(authDataSourceProvider);
  return AuthRepositoryImpl(dataSource);
});

// Use Cases Providers
final signInProvider = Provider<SignIn>((ref) {
  final repository = ref.read(authRepositoryProvider);
  return SignIn(repository);
});

final signUpProvider = Provider<SignUp>((ref) {
  final repository = ref.read(authRepositoryProvider);
  return SignUp(repository);
});

final signOutProvider = Provider<SignOut>((ref) {
  final repository = ref.read(authRepositoryProvider);
  return SignOut(repository);
});

final getCurrentUserProvider = Provider<GetCurrentUser>((ref) {
  final repository = ref.read(authRepositoryProvider);
  return GetCurrentUser(repository);
});

// Auth State Provider
final authStateProvider = StreamProvider<UserProfile?>((ref) {
  final repository = ref.read(authRepositoryProvider);
  return repository.authStateChanges;
});

// Current User Provider
final currentUserProvider = FutureProvider<UserProfile?>((ref) {
  ref.watch(authStateProvider);
  final getCurrentUser = ref.read(getCurrentUserProvider);
  return getCurrentUser();
});

// Admin Check Provider - returns false during loading to prevent blocking
final isAdminProvider = Provider<bool>((ref) {
  try {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) => user?.isAdmin ?? false,
      loading: () => false, // Return false during loading to prevent blocking
      error: (_, _) => false,
    );
  } catch (e) {
    // If any error occurs, return false to prevent blocking
    return false;
  }
});
