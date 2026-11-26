part of "video_bloc.dart";

class VideoState extends Equatable {
  final List<Map<String,String>> videos;
  const VideoState({this.videos = const []});
  VideoState copyWith({List<Map<String,String>>? videos})=>VideoState(videos: videos??this.videos);
  @override
  List<Object?> get props => [videos];
}