import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:bloc/bloc.dart';
import '../../../util/status.dart';
part "home_events.dart";
part "home_state.dart";
class HomeBloc extends Bloc<HomeEvents,HomeState> {
  HomeBloc():super(const HomeState()){
    on<LoadData>(_loadData);
    on<ListenFolders>(_listenFolders);      
}

void _loadData(LoadData event,Emitter<HomeState> emit)async{

    emit(state.copyWith(status: Status.loading));
    final snapshot = await FirebaseFirestore.instance.collection(event.path).get();
    final data = snapshot.docs.map((e)=>e.data()).toList();
    emit(state.copyWith(folders: List<Map<String,dynamic>>.from(data),status: .success));
  }
  Future<void> _listenFolders(ListenFolders event, Emitter<HomeState> emit) async {
    await emit.forEach<QuerySnapshot<Map<String, dynamic>>>(
      FirebaseFirestore.instance.collection(event.path).snapshots(),
      onData: (snapshot) {
        final data = snapshot.docs.map((e) {
          final map = Map<String, dynamic>.from(e.data());
          map['id'] = e.id;
          return map;
        }).toList();
        return state.copyWith(folders: data, status: Status.success);
      },
      onError: (error, stackTrace) => state.copyWith(
        message: error.toString(),
        status: Status.fail,
      ),
    );
  }
  
}

















