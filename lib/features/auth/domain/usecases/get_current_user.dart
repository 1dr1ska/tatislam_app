import 'package:tatislam_app/features/auth/domain/entities/user_profile.dart';
import 'package:tatislam_app/features/auth/domain/repositories/auth_repository.dart';

class GetCurrentUser {
  final AuthRepository repository;

  GetCurrentUser(this.repository);

  Future<UserProfile?> call() {
    return repository.getCurrentUser();
  }
}
