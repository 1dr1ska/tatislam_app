import 'package:tatislam_app/features/auth/domain/entities/user_profile.dart';
import 'package:tatislam_app/features/auth/domain/repositories/auth_repository.dart';

class SignIn {
  final AuthRepository repository;

  SignIn(this.repository);

  Future<UserProfile?> call(String email, String password) {
    return repository.signIn(email, password);
  }
}
