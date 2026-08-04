import 'package:tatislam_app/features/auth/domain/entities/user_profile.dart';
import 'package:tatislam_app/features/auth/domain/repositories/auth_repository.dart';

class SignUp {
  final AuthRepository _repository;

  SignUp(this._repository);

  Future<UserProfile?> call(String email, String password) async {
    return await _repository.signUp(email, password);
  }
}
