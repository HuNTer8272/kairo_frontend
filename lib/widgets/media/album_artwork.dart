import 'package:flutter/material.dart';

/// Square cover art with a neutral placeholder while loading or when the
/// item has no image.
class AlbumArtwork extends StatelessWidget {
  const AlbumArtwork({
    super.key,
    required this.url,
    required this.size,
    this.radius = 8,
  });

  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: size * 0.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: url == null
            ? placeholder
            : Image.network(
                url!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => placeholder,
                frameBuilder: (context, child, frame, synchronous) {
                  if (synchronous) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 220),
                    child: child,
                  );
                },
              ),
      ),
    );
  }
}
