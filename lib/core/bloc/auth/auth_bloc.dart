import "package:bloc/bloc.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "../../../util/status.dart";
import "package:equatable/equatable.dart";
part 'auth_events.dart';
part "auth_state.dart";
class AuthBloc extends Bloc<AuthEvents,AuthState> {
  AuthBloc():super(AuthState()){
    on<SignIn>(_signIn);
    on<SignUp>(_signUp);
    on<Forget>(_forget);
    on<UpdateData>(_updateData);
    on<DeleteAccount>(_deleteAccount);
  }
  void _signIn(SignIn event,Emitter<AuthState> emit)async{
    try{
        emit(state.copyWith(status: .loading,));
    await  FirebaseAuth.instance.signInWithEmailAndPassword(email: event.email,password: event.password);
  emit(state.copyWith(status: .success,message: "Login successful"));
    }catch(error){
      emit(state.copyWith(status: .fail,message: error.toString()));
    }
  }
  void _signUp(SignUp event,Emitter<AuthState> emit)async{
    try{
      emit(state.copyWith(status: .loading,));
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: event.email,password: event.password);
      emit(state.copyWith(status: .success,message: "Signup successful"));
    }catch(error){
      emit(state.copyWith(status: .fail,message: error.toString()));
    }
  }
  void _forget(Forget event,Emitter<AuthState> emit)async{
    try{
      emit(state.copyWith(status: .loading,));
      await FirebaseAuth.instance.sendPasswordResetEmail(email: event.email);
      emit(state.copyWith(status: .success,message: "Reset email successful"));
    }catch(error){
      emit(state.copyWith(status: .fail,message: error.toString()));
    }
  }
  void _updateData(UpdateData event,Emitter<AuthState> emit)async{
    try{
      emit(state.copyWith(status: .loading,));
      await FirebaseFirestore.instance.collection(event.path).doc(event.uid).update(event.data);
      emit(state.copyWith(status: .success,message: "Information update succesfull"));
    }catch(error){
      emit(state.copyWith(status: .fail,message: error.toString()));
    }
  }
  void _deleteAccount(DeleteAccount event, Emitter<AuthState> emit) async{
    emit(state.copyWith(status: .loading));
    var user =  FirebaseAuth.instance.currentUser;
    if(user==null){
      emit(state.copyWith(status: .fail,message: "User is not logged in"));
      return;
    }
    final credential =  EmailAuthProvider.credential(email: event.email,password: event.password);
    user.reauthenticateWithCredential(credential);
    await user.delete();
    emit(state.copyWith(status: .success,message: "Account delete sucxessfull"));
    
  }
}




















