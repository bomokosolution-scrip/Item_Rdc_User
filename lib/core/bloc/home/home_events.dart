part of "home_bloc.dart";

abstract class HomeEvents extends Equatable {
  const HomeEvents();
  @override
  List<Object?> get props => [];
}
class LoadData extends HomeEvents{
  final String path;
  const LoadData(this.path);
    @override
  List<Object?> get props => [path];
}
class AddFolderInFirebase extends HomeEvents{
  final  String names;
  final String path;
  const AddFolderInFirebase(this.names,this.path);
    @override
  List<Object?> get props => [names,path];
}

class AddItemsInFolder extends HomeEvents{
   final String docId,names,urls,path;
   const AddItemsInFolder({required this.names,required this.docId,required this.urls,required this.path});
      @override
  List<Object?> get props => [names,docId,urls,path];

}
class DeleteFolder extends HomeEvents {
  
  final String docId,path;

  const DeleteFolder(this.docId,this.path);

  @override
  List<Object?> get props => [docId,path];
}
class DeleteItem extends HomeEvents {
  final String docId,path;
  final Map item;

  const DeleteItem({required this.docId, required this.item,required this.path});

  @override
  List<Object?> get props => [docId, item,path];
}

class ListenFolders extends HomeEvents {
  final String path;

  const ListenFolders(this.path);

  @override
  List<Object?> get props => [path];
}







