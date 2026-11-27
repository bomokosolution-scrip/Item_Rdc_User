import 'package:flutter/material.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/pages/document_viewer_page.dart';
import 'package:item_rdc/widgets/media_tile.dart';

/// Affiche une image en plein écran (zoom possible).
void openImageViewer(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 56,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String chatHm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Image jointe à un message ou à une question d'entraide.
class ChatImage extends StatelessWidget {
  final String url;
  final double maxHeight;
  const ChatImage({super.key, required this.url, this.maxHeight = 220});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openImageViewer(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: CoverImage(
            url: url,
            cacheWidth: 720,
            fallback: Container(
              height: 120,
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_rounded),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bulle de message (messages privés, réponses d'entraide).
class ChatBubble extends StatelessWidget {
  final bool mine;
  final String pseudo;
  final String text;
  final DateTime? time;
  final String type; // text | file | image
  final String fileUrl;
  final String fileName;
  final VoidCallback? onLongPress;

  const ChatBubble({
    super.key,
    required this.mine,
    required this.pseudo,
    required this.text,
    required this.time,
    this.type = 'text',
    this.fileUrl = '',
    this.fileName = '',
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.accent(context);
    final fg = mine ? Colors.white : theme.textTheme.bodyLarge?.color;

    Widget? attachment;
    if (type == 'image' && fileUrl.isNotEmpty) {
      attachment = Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SizedBox(width: 220, child: ChatImage(url: fileUrl)),
      );
    } else if (type == 'file' && fileUrl.isNotEmpty) {
      attachment = Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DocumentViewerPage(
                url: fileUrl,
                title: fileName.isEmpty ? 'Fichier' : fileName,
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (mine ? Colors.white : accent).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(fileIconFor(fileUrl), color: fg),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    fileName.isEmpty ? 'Fichier' : fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: mine ? accent : theme.cardColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine && pseudo.isNotEmpty)
                Text(
                  pseudo,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              if (attachment != null) attachment,
              if (text.isNotEmpty)
                Text(text, style: TextStyle(fontSize: 15, color: fg)),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  time == null ? '…' : chatHm(time!),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: mine ? Colors.white70 : theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
