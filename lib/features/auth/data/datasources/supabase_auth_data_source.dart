import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tatislam_app/features/auth/data/models/user_profile_model.dart';

class SupabaseAuthDataSource {
  final SupabaseClient _client;

  SupabaseAuthDataSource(this._client);

  Future<UserProfileModel?> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        return await getUserProfile(response.user!.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  Future<UserProfileModel?> signUp(String email, String password) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Wait a bit for the trigger to create the profile
        await Future.delayed(const Duration(milliseconds: 500));
        final profile = await getUserProfile(response.user!.id);
        // If we got a basic profile, update it with the email from the response
        if (profile != null && profile.email.isEmpty) {
          return profile.copyWith(email: email);
        }
        return profile;
      }
      return null;
    } catch (e) {
      throw Exception(
        'Failed to create user: Database error creating new user',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  Future<UserProfileModel?> getCurrentUser() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        return await getUserProfile(user.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get current user: $e');
    }
  }

  Stream<UserProfileModel?> get authStateChanges {
    return _client.auth.onAuthStateChange.asyncMap((data) async {
      final user = data.session?.user;
      if (user != null) {
        try {
          return await getUserProfile(user.id);
        } catch (e) {
          return null;
        }
      }
      return null;
    });
  }

  Future<UserProfileModel?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return UserProfileModel.fromJson(response);
    } catch (e) {
      // If profile doesn't exist, create a basic profile model
      final now = DateTime.now();
      return UserProfileModel(
        id: userId,
        email: '', // Email will be updated when we have it
        role: 'user',
        createdAt: now,
        updatedAt: now,
      );
    }
  }
}
