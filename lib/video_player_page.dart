import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:item_rdc/util/drive_util.dart';

class VideoPlayerPage extends StatefulWidget {
  final String url;
  final String title;

  const VideoPlayerPage({super.key, required this.url, required this.title});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  YoutubePlayerController? _youtubeController;
  bool isYoutube = false;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    isYoutube = widget.url.contains('youtube.com') || widget.url.contains('youtu.be');
    
    if (isYoutube) {
      String? videoId = YoutubePlayer.convertUrlToId(widget.url);
      if (videoId != null) {
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
        );
        isInitialized = true;
      }
    } else {
      final streamUrl = DriveUtil.getDirectLink(widget.url);
      // Ajout du User-Agent pour forcer le streaming direct et éviter le téléchargement
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );
      
      _videoPlayerController.initialize().then((_) {
        if (mounted) {
          setState(() {
            _chewieController = ChewieController(
              videoPlayerController: _videoPlayerController,
              autoPlay: true,
              looping: false,
              aspectRatio: _videoPlayerController.value.aspectRatio,
              showControls: true,
            );
            isInitialized = true;
          });
        }
      }).catchError((e) => debugPrint("Error: $e"));
    }
  }

  @override
  void dispose() {
    if (!isYoutube) _videoPlayerController.dispose();
    _chewieController?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.transparent),
      body: Center(
        child: isYoutube
            ? (_youtubeController != null ? YoutubePlayer(controller: _youtubeController!) : const Text("URL YouTube invalide"))
            : (isInitialized && _chewieController != null
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }
}
