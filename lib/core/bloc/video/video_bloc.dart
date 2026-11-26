import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
part 'video_events.dart';
part 'video_state.dart';

class VideoBloc extends Bloc<VideoEvents, VideoState> {
  VideoBloc() : super(const VideoState()) {
    on<LoadVideo>(_onLoadVideo);
  }

  Future<void> _onLoadVideo(LoadVideo event, Emitter<VideoState> emit) async {
    await emit.forEach<QuerySnapshot<Map<String, dynamic>>>(
      FirebaseFirestore.instance
          .collection(event.path)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      onData: (snapshot) {
        final List<Map<String, String>> videos = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title']?.toString() ?? '',
            'url': data['url']?.toString() ?? '',
          };
        }).toList();
        return state.copyWith(videos: videos);
      },
      onError: (error, stackTrace) => state, 
    );
  }

  
}
