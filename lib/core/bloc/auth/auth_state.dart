part of "auth_bloc.dart";
class AuthState extends Equatable {
  final Status status;
  final String message;
  const AuthState({this.message ="",this.status=.initial});
  AuthState copyWith({Status? status,String? message})
  =>AuthState(status: status??this.status,message: message??this.message);
  @override
  List<Object?> get props => [status,message];
}