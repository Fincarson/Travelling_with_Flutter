import '../../domain/entities/user.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl(this.remoteDataSource);

  Future<User> login(String email, String password) async {
    final json = await remoteDataSource.login(email, password);
    return UserModel.fromJson(json);
  }
}