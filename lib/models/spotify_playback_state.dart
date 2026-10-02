import 'spotify_track.dart';

/// Overall state of the Spotify integration, as shown by the UI.
enum SpotifyConnectionStatus { unavailable, loggedOut, connecting, connected }

/// Why Spotify is [SpotifyConnectionStatus.unavailable].
enum SpotifyUnavailableReason {
  /// The app was built without a Spotify client ID.
  notConfigured,

  /// The Spotify app is not installed on this device.
  appNotInstalled,
}

enum SpotifyRepeatMode {
  off,
  context,
  track;

  static SpotifyRepeatMode fromApi(String? value) => switch (value) {
        'context' => context,
        'track' => track,
        _ => off,
      };

  /// Cycle order used by the repeat button: off → context → track → off.
  SpotifyRepeatMode get next => values[(index + 1) % values.length];
}

/// Keys of the Web API's `actions.disallows` object.
abstract final class SpotifyAction {
  static const pausing = 'pausing';
  static const resuming = 'resuming';
  static const seeking = 'seeking';
  static const skippingNext = 'skipping_next';
  static const skippingPrev = 'skipping_prev';
  static const togglingShuffle = 'toggling_shuffle';
  static const togglingRepeatContext = 'toggling_repeat_context';
  static const togglingRepeatTrack = 'toggling_repeat_track';
}

/// What the current item is playing from (playlist, album, ...).
class SpotifyPlaybackContext {
  const SpotifyPlaybackContext({required this.type, required this.uri});

  final String type;
  final String uri;

  String get typeLabel => switch (type) {
        'playlist' => 'Playlist',
        'album' => 'Album',
        'artist' => 'Artist',
        'show' => 'Podcast',
        'collection' => 'Liked Songs',
        _ => 'Spotify',
      };
}

/// Snapshot of the user's Spotify player (`GET /me/player`).
class SpotifyPlaybackState {
  const SpotifyPlaybackState({
    required this.track,
    required this.isPlaying,
    required this.progress,
    required this.fetchedAt,
    this.shuffle = false,
    this.repeatMode = SpotifyRepeatMode.off,
    this.context,
    this.deviceName,
    this.deviceRestricted = false,
    this.disallows = const {},
  });

  /// Null when something without metadata is playing (e.g. an ad).
  final SpotifyTrack? track;
  final bool isPlaying;

  /// Position at [fetchedAt]; use [positionAt] for the live position.
  final Duration progress;
  final DateTime fetchedAt;
  final bool shuffle;
  final SpotifyRepeatMode repeatMode;
  final SpotifyPlaybackContext? context;
  final String? deviceName;

  /// Restricted devices do not accept Web API commands.
  final bool deviceRestricted;
  final Set<String> disallows;

  bool allows(String action) =>
      !deviceRestricted && !disallows.contains(action);

  /// Extrapolates the playback position between polls.
  Duration positionAt(DateTime now) {
    if (!isPlaying) return progress;
    final position = progress + now.difference(fetchedAt);
    final duration = track?.duration ?? Duration.zero;
    if (duration > Duration.zero && position > duration) return duration;
    return position;
  }

  SpotifyPlaybackState copyWith({
    bool? isPlaying,
    Duration? progress,
    DateTime? fetchedAt,
    bool? shuffle,
    SpotifyRepeatMode? repeatMode,
  }) {
    return SpotifyPlaybackState(
      track: track,
      isPlaying: isPlaying ?? this.isPlaying,
      progress: progress ?? this.progress,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      context: context,
      deviceName: deviceName,
      deviceRestricted: deviceRestricted,
      disallows: disallows,
    );
  }

  factory SpotifyPlaybackState.fromJson(
    Map<String, dynamic> json, {
    required DateTime receivedAt,
  }) {
    final item = json['item'];
    final device = json['device'] as Map<String, dynamic>?;
    final context = json['context'] as Map<String, dynamic>?;
    final actions = json['actions'] as Map<String, dynamic>?;
    final disallows =
        actions?['disallows'] as Map<String, dynamic>? ?? const {};

    return SpotifyPlaybackState(
      track: item is Map<String, dynamic> ? SpotifyTrack.fromJson(item) : null,
      isPlaying: json['is_playing'] == true,
      progress:
          Duration(milliseconds: (json['progress_ms'] as num?)?.toInt() ?? 0),
      fetchedAt: receivedAt,
      shuffle: json['shuffle_state'] == true,
      repeatMode: SpotifyRepeatMode.fromApi(json['repeat_state'] as String?),
      context: context == null
          ? null
          : SpotifyPlaybackContext(
              type: context['type'] as String? ?? '',
              uri: context['uri'] as String? ?? '',
            ),
      deviceName: device?['name'] as String?,
      deviceRestricted: device?['is_restricted'] == true,
      disallows: {
        for (final entry in disallows.entries)
          if (entry.value == true) entry.key,
      },
    );
  }
}
