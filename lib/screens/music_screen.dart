import 'package:flutter/material.dart';

import '../models/spotify_playback_state.dart';
import '../services/spotify/spotify_service.dart';
import '../widgets/common/message_banner.dart';
import '../widgets/media/album_artwork.dart';
import '../widgets/media/spotify_progress_builder.dart';

/// Opens from the music icon in the bottom dock and from the home music
/// card. Spotify is the content source; the layout follows the rest of the
/// cockpit UI rather than Spotify's own app.
class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key, required this.spotify});

  final SpotifyService spotify;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: ListenableBuilder(
        listenable: spotify,
        builder: (context, _) {
          final message = spotify.message;
          return Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  // Top inset clears the status bar, as in the settings panel.
                  padding: const EdgeInsets.fromLTRB(56, 72, 56, 28),
                  child: _buildBody(),
                ),
              ),
              if (message != null)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 20,
                  child: Center(
                    child: MessageBanner(
                      message: message,
                      onDismiss: spotify.clearMessage,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    switch (spotify.status) {
      case SpotifyConnectionStatus.unavailable:
        if (spotify.unavailableReason ==
            SpotifyUnavailableReason.appNotInstalled) {
          return _StatusPanel(
            icon: Icons.download_rounded,
            title: 'Spotify is not installed',
            message: 'Install Spotify on this tablet to play music here. '
                'You can also connect your account to control Spotify on '
                'another device.',
            primaryLabel: 'Install Spotify',
            onPrimary: spotify.installSpotify,
            secondaryLabel: 'Connect anyway',
            onSecondary: spotify.connect,
          );
        }
        return const _StatusPanel(
          icon: Icons.music_off_rounded,
          title: 'Spotify is not configured',
          message: 'This build has no Spotify client ID. Rebuild with '
              '--dart-define-from-file=dart_defines.json.',
        );
      case SpotifyConnectionStatus.loggedOut:
        return _StatusPanel(
          icon: Icons.music_note_rounded,
          title: 'Connect Spotify',
          message: 'Sign in with your Spotify account to see and control '
              'what is playing.',
          primaryLabel: 'Connect Spotify',
          onPrimary: spotify.connect,
        );
      case SpotifyConnectionStatus.connecting:
        return const _StatusPanel(
          busy: true,
          title: 'Connecting to Spotify',
          message: 'Finish signing in on the Spotify page.',
        );
      case SpotifyConnectionStatus.connected:
        final playback = spotify.playback;
        if (playback?.track == null) {
          final installed = spotify.isAppInstalled != false;
          final error = spotify.playbackError;
          return Stack(
            children: [
              if (error != null)
                _StatusPanel(
                  icon: Icons.error_outline_rounded,
                  title: 'Can\'t read Spotify playback',
                  message: error,
                  primaryLabel: 'Retry',
                  onPrimary: spotify.refresh,
                )
              else
                _StatusPanel(
                  icon: Icons.music_note_rounded,
                  title: 'Nothing playing',
                  message: installed
                      ? 'Start something in Spotify and it will appear here.'
                      : 'Start Spotify on your phone or another device, '
                          'or install it on this tablet.',
                  primaryLabel: installed ? 'Open Spotify' : 'Install Spotify',
                  onPrimary:
                      installed ? spotify.openSpotify : spotify.installSpotify,
                ),
              Positioned(
                top: 0,
                right: 0,
                child: _SourceBadge(onDisconnect: spotify.disconnect),
              ),
            ],
          );
        }
        return _NowPlaying(spotify: spotify, playback: playback!);
    }
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.spotify, required this.playback});

  final SpotifyService spotify;
  final SpotifyPlaybackState playback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final track = playback.track!;
    final playContext = playback.context;
    final sourceName = spotify.contextName ?? track.albumName;

    return LayoutBuilder(
      builder: (context, constraints) {
        final artSize = constraints.maxHeight < constraints.maxWidth * 0.42
            ? constraints.maxHeight
            : constraints.maxWidth * 0.42;

        return Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 30,
                    offset: Offset(0, 14),
                    color: Color(0x22000000),
                  ),
                ],
              ),
              child: AlbumArtwork(
                url: track.artworkUrl,
                size: artSize,
                radius: 14,
              ),
            ),
            const SizedBox(width: 56),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playContext == null
                                  ? 'NOW PLAYING'
                                  : 'PLAYING FROM '
                                      '${playContext.typeLabel.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.3,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            if (sourceName != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                sourceName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      _SourceBadge(onDisconnect: spotify.disconnect),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    track.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    track.artistLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SeekBar(
                    playback: playback,
                    enabled: spotify.can(SpotifyAction.seeking),
                    onSeek: spotify.seek,
                  ),
                  const SizedBox(height: 16),
                  _TransportControls(spotify: spotify, playback: playback),
                  const Spacer(),
                  if (playback.deviceName != null)
                    Row(
                      children: [
                        Icon(
                          Icons.speaker_rounded,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Playing on ${playback.deviceName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({
    required this.playback,
    required this.enabled,
    required this.onSeek,
  });

  final SpotifyPlaybackState playback;
  final bool enabled;
  final ValueChanged<Duration> onSeek;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  /// Position under the user's finger while dragging, in milliseconds.
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timeStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return SpotifyProgressBuilder(
      playback: widget.playback,
      builder: (context, position, duration) {
        final max = duration.inMilliseconds <= 0
            ? 1.0
            : duration.inMilliseconds.toDouble();
        final value =
            (_dragValue ?? position.inMilliseconds.toDouble()).clamp(0.0, max);

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 4),
              child: Slider(
                value: value,
                max: max,
                padding: EdgeInsets.zero,
                onChangeStart: (v) => setState(() => _dragValue = v),
                onChanged: widget.enabled
                    ? (v) => setState(() => _dragValue = v)
                    : null,
                onChangeEnd: (v) {
                  widget.onSeek(Duration(milliseconds: v.round()));
                  setState(() => _dragValue = null);
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(Duration(milliseconds: value.round())),
                  style: timeStyle,
                ),
                Text(_formatDuration(duration), style: timeStyle),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({required this.spotify, required this.playback});

  final SpotifyService spotify;
  final SpotifyPlaybackState playback;

  @override
  Widget build(BuildContext context) {
    final repeat = playback.repeatMode;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ToggleButton(
          icon: Icons.shuffle_rounded,
          tooltip: playback.shuffle ? 'Shuffle on' : 'Shuffle off',
          selected: playback.shuffle,
          onPressed: spotify.can(SpotifyAction.togglingShuffle)
              ? spotify.toggleShuffle
              : null,
        ),
        const SizedBox(width: 28),
        IconButton(
          tooltip: 'Previous',
          iconSize: 40,
          onPressed: spotify.can(SpotifyAction.skippingPrev)
              ? spotify.skipPrevious
              : null,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        const SizedBox(width: 20),
        SizedBox.square(
          dimension: 72,
          child: IconButton.filled(
            tooltip: playback.isPlaying ? 'Pause' : 'Play',
            iconSize: 38,
            onPressed: spotify.canTogglePlay ? spotify.togglePlayPause : null,
            icon: Icon(playback.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded),
          ),
        ),
        const SizedBox(width: 20),
        IconButton(
          tooltip: 'Next',
          iconSize: 40,
          onPressed:
              spotify.can(SpotifyAction.skippingNext) ? spotify.skipNext : null,
          icon: const Icon(Icons.skip_next_rounded),
        ),
        const SizedBox(width: 28),
        _ToggleButton(
          icon: repeat == SpotifyRepeatMode.track
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          tooltip: switch (repeat) {
            SpotifyRepeatMode.off => 'Repeat off',
            SpotifyRepeatMode.context => 'Repeat all',
            SpotifyRepeatMode.track => 'Repeat track',
          },
          selected: repeat != SpotifyRepeatMode.off,
          onPressed: spotify.canCycleRepeat ? spotify.cycleRepeat : null,
        ),
      ],
    );
  }
}

/// Shuffle/repeat button: accent icon on a soft accent fill when active.
class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      isSelected: selected,
      onPressed: onPressed,
      icon: Icon(icon),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          return states.contains(WidgetState.selected)
              ? scheme.primaryContainer
              : null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          return states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant;
        }),
      ),
    );
  }
}

/// Small "Spotify" source indicator with a disconnect action.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.onDisconnect});

  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Spotify',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          IconButton(
            tooltip: 'Disconnect Spotify',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed: onDisconnect,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }
}

/// Centered state message, styled like the other cockpit empty states.
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    this.icon,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
  });

  final IconData? icon;
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(34),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Icon(icon, size: 42, color: scheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
          ),
          if (primaryLabel != null || secondaryLabel != null) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (primaryLabel != null)
                  FilledButton(
                    onPressed: onPrimary,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      child: Text(primaryLabel!),
                    ),
                  ),
                if (secondaryLabel != null) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString();
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    return '${d.inHours}:${minutes.padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}
