part of 'auth_bloc.dart';

abstract class AuthEvents extends Equatable {
  final String email;

  const AuthEvents({required this.email});

  @override
  List<Object?> get props => [email];
}

class SignIn extends AuthEvents {
  final String password;

  const SignIn({
    required super.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class DeleteAccount  extends AuthEvents {
  final String password;

  const DeleteAccount({
    required super.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class SignUp extends AuthEvents {
  final String password;

  const SignUp({
    required super.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class Forget extends AuthEvents {
  const Forget({required super.email});

  @override
  List<Object?> get props => [email];
}
class UpdateData extends AuthEvents{
  final Map<String,Object> data;
  final String path,uid;

  const UpdateData({required super.email, required this.data, required this.path, required this.uid});
  
   @override
  List<Object?> get props => [email,path,uid,data];
}




