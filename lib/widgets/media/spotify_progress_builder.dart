import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../models/spotify_playback_state.dart';

/// Rebuilds [builder] twice a second while playing so progress advances
/// smoothly between Spotify polls, without rebuilding the rest of the UI.
class SpotifyProgressBuilder extends StatefulWidget {
  const SpotifyProgressBuilder({
    super.key,
    required this.playback,
    required this.builder,
  });

  final SpotifyPlaybackState? playback;
  final Widget Function(
    BuildContext context,
    Duration position,
    Duration duration,
  ) builder;

  @override
  State<SpotifyProgressBuilder> createState() => _SpotifyProgressBuilderState();
}

class _SpotifyProgressBuilderState extends State<SpotifyProgressBuilder> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(SpotifyProgressBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    final playing = widget.playback?.isPlaying ?? false;
    if (playing && _ticker == null) {
      _ticker = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => setState(() {}),
      );
    } else if (!playing) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = widget.playback;
    return widget.builder(
      context,
      playback?.positionAt(DateTime.now()) ?? Duration.zero,
      playback?.track?.duration ?? Duration.zero,
    );
  }
}
