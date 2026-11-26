part of "home_bloc.dart";

class HomeState extends Equatable {
  final List<Map<String, dynamic>> folders;
  final String message;
  final Status status;
   const HomeState({this.folders =const [],this.message="",this.status=Status.initial});
  HomeState copyWith({
    List<Map<String, dynamic>>? folders,
    Status? status,
    String? message,
  }) {
    return HomeState(
      folders: folders ?? this.folders,
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }
  @override
  List<Object?> get props => [folders,status,message];  
}
