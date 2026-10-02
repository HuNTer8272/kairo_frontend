import 'package:flutter/material.dart';

import '../../models/spotify_playback_state.dart';
import '../../services/spotify/spotify_service.dart';
import 'album_artwork.dart';
import 'spotify_progress_builder.dart';

/// Contents of the home-screen music card: now-playing row, a thin
/// progress line and the transport row. Layout mirrors the original static
/// card; tapping anywhere outside the buttons opens the Music screen.
class SpotifyMiniPlayer extends StatelessWidget {
  const SpotifyMiniPlayer({
    super.key,
    required this.spotify,
    required this.onOpen,
  });

  final SpotifyService spotify;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: spotify,
      builder: (context, _) {
        final playback = spotify.playback;
        final track = playback?.track;
        final playing = playback?.isPlaying ?? false;
        final (title, subtitle) = _labels(playback);

        return Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onOpen,
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  onTap: onOpen,
                  leading: track == null
                      ? CircleAvatar(
                          backgroundColor: const Color(0xFF2E2B32),
                          child: Icon(_statusIcon, color: Colors.white),
                        )
                      : AlbumArtwork(
                          url: track.thumbnailUrl,
                          size: 40,
                          radius: 6,
                        ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _trailing(),
                ),
                if (track != null)
                  _ProgressLine(playback: playback)
                else
                  const Divider(height: 1),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        tooltip: 'Previous',
                        onPressed: spotify.can(SpotifyAction.skippingPrev)
                            ? spotify.skipPrevious
                            : null,
                        icon: const Icon(Icons.skip_previous_rounded),
                      ),
                      IconButton(
                        tooltip: playing ? 'Pause' : 'Play',
                        onPressed: spotify.canTogglePlay
                            ? spotify.togglePlayPause
                            : null,
                        icon: Icon(playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                      ),
                      IconButton(
                        tooltip: 'Next',
                        onPressed: spotify.can(SpotifyAction.skippingNext)
                            ? spotify.skipNext
                            : null,
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                      IconButton(
                        tooltip: 'Open player',
                        onPressed: onOpen,
                        icon: const Icon(Icons.tune_rounded),
                      ),
                      const IconButton(
                        onPressed: null,
                        icon: Icon(Icons.search_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData get _statusIcon => switch (spotify.status) {
        SpotifyConnectionStatus.unavailable => Icons.music_off_rounded,
        _ => Icons.music_note_rounded,
      };

  (String, String) _labels(SpotifyPlaybackState? playback) {
    switch (spotify.status) {
      case SpotifyConnectionStatus.unavailable:
        return spotify.unavailableReason ==
                SpotifyUnavailableReason.appNotInstalled
            ? ('Spotify', 'App not installed')
            : ('Spotify', 'Not configured');
      case SpotifyConnectionStatus.loggedOut:
        return ('Spotify', 'Not connected');
      case SpotifyConnectionStatus.connecting:
        return ('Spotify', 'Connecting…');
      case SpotifyConnectionStatus.connected:
        final track = playback?.track;
        if (track == null) {
          final error = spotify.playbackError;
          return error == null
              ? ('Nothing playing', 'Spotify')
              : ('Spotify unavailable', error);
        }
        final artist = track.artistLine;
        return (
          track.name,
          playback!.isPlaying ? artist : '$artist · Paused',
        );
    }
  }

  Widget? _trailing() {
    const style = ButtonStyle(visualDensity: VisualDensity.compact);
    switch (spotify.status) {
      case SpotifyConnectionStatus.loggedOut:
        return TextButton(
          style: style,
          onPressed: spotify.connect,
          child: const Text('Connect Spotify'),
        );
      case SpotifyConnectionStatus.unavailable
          when spotify.unavailableReason ==
              SpotifyUnavailableReason.appNotInstalled:
        return TextButton(
          style: style,
          onPressed: spotify.installSpotify,
          child: const Text('Install'),
        );
      case SpotifyConnectionStatus.connecting:
        return const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      default:
        return null;
    }
  }
}

/// A 2 px track-progress line that takes the place of the card's divider.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.playback});

  final SpotifyPlaybackState? playback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SpotifyProgressBuilder(
      playback: playback,
      builder: (context, position, duration) {
        final fraction = duration.inMilliseconds == 0
            ? 0.0
            : (position.inMilliseconds / duration.inMilliseconds)
                .clamp(0.0, 1.0);
        return SizedBox(
          height: 2,
          child: ColoredBox(
            color: scheme.outlineVariant,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction,
                heightFactor: 1,
                child: ColoredBox(color: scheme.primary),
              ),
            ),
          ),
        );
      },
    );
  }
}
