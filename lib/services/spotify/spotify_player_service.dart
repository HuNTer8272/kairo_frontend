import '../../models/spotify_playback_state.dart';

enum SpotifyPlayerErrorKind {
  premiumRequired,
  noActiveDevice,
  rateLimited,
  unauthorized,
  restricted,
  network,
  unknown,
}

class SpotifyPlayerException implements Exception {
  const SpotifyPlayerException(this.kind, this.message, {this.retryAfter});

  final SpotifyPlayerErrorKind kind;
  final String message;
  final Duration? retryAfter;

  @override
  String toString() => 'SpotifyPlayerException(${kind.name}): $message';
}

/// Transport-agnostic playback control.
///
/// The Web API implementation is the only one today. A native Android
/// Spotify App Remote implementation could be added behind this interface
/// without touching [SpotifyService] or any widget.
abstract interface class SpotifyPlayerService {
  /// Current playback, or null when nothing is playing on any device.
  Future<SpotifyPlaybackState?> fetchPlayback();

  /// Display name of a playlist/album/artist context, if it can be read.
  Future<String?> fetchContextName(SpotifyPlaybackContext context);

  Future<void> play();
  Future<void> pause();
  Future<void> next();
  Future<void> previous();
  Future<void> seek(Duration position);
  Future<void> setShuffle(bool enabled);
  Future<void> setRepeat(SpotifyRepeatMode mode);

  void dispose();
}
