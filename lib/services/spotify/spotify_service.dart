import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../models/spotify_playback_state.dart';
import 'spotify_app_launcher.dart';
import 'spotify_auth_service.dart';
import 'spotify_config.dart';
import 'spotify_player_service.dart';
import 'spotify_web_api_player_service.dart';

enum _Session { loggedOut, connecting, connected }

/// The single object widgets talk to for Spotify.
///
/// Owns the connection lifecycle (logged out → connecting → connected),
/// polls playback while the app is in the foreground, and exposes playback
/// commands with optimistic updates. Widgets never see tokens or HTTP.
class SpotifyService extends ChangeNotifier {
  SpotifyService({
    SpotifyAuthService? auth,
    SpotifyPlayerService? player,
    SpotifyAppLauncher? launcher,
    bool? configured,
  })  : _auth = auth ?? SpotifyAuthService(),
        _launcher = launcher ?? const SpotifyAppLauncher(),
        _configured = configured ?? SpotifyConfig.isConfigured {
    _player = player ?? SpotifyWebApiPlayerService(_auth);
  }

  static const Duration _pollInterval = Duration(seconds: 3);
  static const Duration _followUpDelay = Duration(milliseconds: 600);
  static const String _offlineMessage = 'Spotify is offline. Retrying…';
  static const String _expiredMessage =
      'Spotify session expired. Connect again.';

  final SpotifyAuthService _auth;
  final SpotifyAppLauncher _launcher;
  final bool _configured;
  late final SpotifyPlayerService _player;

  _Session _session = _Session.loggedOut;
  bool? _appInstalled;
  bool _premiumRequired = false;
  SpotifyPlaybackState? _playback;
  String? _contextUri;
  String? _contextName;
  String? _message;
  String? _playbackError;

  Timer? _pollTimer;
  Timer? _followUpTimer;
  AppLifecycleListener? _lifecycle;
  DateTime? _rateLimitedUntil;
  bool _fetching = false;
  int _commandsInFlight = 0;
  bool _disposed = false;

  SpotifyConnectionStatus get status {
    if (!_configured) return SpotifyConnectionStatus.unavailable;
    return switch (_session) {
      _Session.connecting => SpotifyConnectionStatus.connecting,
      _Session.connected => SpotifyConnectionStatus.connected,
      _Session.loggedOut => _appInstalled == false
          ? SpotifyConnectionStatus.unavailable
          : SpotifyConnectionStatus.loggedOut,
    };
  }

  SpotifyUnavailableReason? get unavailableReason {
    if (status != SpotifyConnectionStatus.unavailable) return null;
    return _configured
        ? SpotifyUnavailableReason.appNotInstalled
        : SpotifyUnavailableReason.notConfigured;
  }

  /// Null when the platform cannot tell.
  bool? get isAppInstalled => _appInstalled;

  SpotifyPlaybackState? get playback => _playback;

  /// Resolved playlist/album name for the current context, if readable.
  String? get contextName => _contextName;

  /// Latest user-facing notice (errors, Premium requirement, ...).
  String? get message => _message;

  /// Why the last playback read failed while connected; null once a read
  /// succeeds. Distinguishes "Spotify refused us" from "nothing playing".
  String? get playbackError => _playbackError;

  bool get canControl =>
      status == SpotifyConnectionStatus.connected &&
      _playback?.track != null &&
      !_premiumRequired;

  bool can(String action) => canControl && _playback!.allows(action);

  bool get canTogglePlay => can(_playback?.isPlaying == true
      ? SpotifyAction.pausing
      : SpotifyAction.resuming);

  bool get canCycleRepeat =>
      can(SpotifyAction.togglingRepeatContext) ||
      can(SpotifyAction.togglingRepeatTrack);

  Future<void> init() async {
    _lifecycle = AppLifecycleListener(
      onResume: _onResume,
      onHide: _stopPolling,
    );
    if (!_configured) return _notify();

    _appInstalled = await _launcher.isInstalled();
    try {
      if (!await _auth.hasSession()) return _notify();
    } catch (_) {
      return _notify();
    }

    _session = _Session.connecting;
    _notify();
    try {
      await _auth.accessToken();
      _onConnected();
    } on SpotifyAuthException catch (e) {
      _session = _Session.loggedOut;
      _message = e.sessionExpired ? _expiredMessage : e.message;
      _notify();
    } catch (_) {
      // Offline at startup: keep the stored session, polling retries.
      _session = _Session.connected;
      _message = _offlineMessage;
      _startPolling();
      _notify();
    }
  }

  Future<void> connect() async {
    if (!_configured || _session != _Session.loggedOut) return;
    _session = _Session.connecting;
    _message = null;
    _notify();
    try {
      await _auth.login();
      _onConnected();
    } on SpotifyAuthException catch (e) {
      _session = _Session.loggedOut;
      _message = e.cancelled ? null : e.message;
      _notify();
    } catch (_) {
      _session = _Session.loggedOut;
      _message = 'Could not reach Spotify. Check the connection and try again.';
      _notify();
    }
  }

  Future<void> disconnect() async {
    _stopPolling();
    _resetPlayer();
    _session = _Session.loggedOut;
    _message = null;
    _notify();
    await _auth.logout();
  }

  void clearMessage() {
    if (_message == null) return;
    _message = null;
    _notify();
  }

  Future<void> openSpotify() => _launch(_launcher.openApp);
  Future<void> installSpotify() => _launch(_launcher.openStore);

  /// Fetches the current playback state once.
  Future<void> refresh() async {
    if (_session != _Session.connected || _fetching || _commandsInFlight > 0) {
      return;
    }
    final limitedUntil = _rateLimitedUntil;
    if (limitedUntil != null && DateTime.now().isBefore(limitedUntil)) return;

    _fetching = true;
    try {
      final playback = await _player.fetchPlayback();
      if (_session != _Session.connected) return;
      _playback = playback;
      _playbackError = null;
      if (_message == _offlineMessage) _message = null;
      _updateContext(playback?.context);
    } on SpotifyAuthException catch (e) {
      if (e.sessionExpired) _expireSession();
    } on SpotifyPlayerException catch (e) {
      switch (e.kind) {
        case SpotifyPlayerErrorKind.unauthorized:
          _expireSession();
        case SpotifyPlayerErrorKind.rateLimited:
          _rateLimitedUntil = DateTime.now().add(e.retryAfter!);
        case SpotifyPlayerErrorKind.network:
          _message = _offlineMessage;
        case SpotifyPlayerErrorKind.premiumRequired:
          _premiumRequired = true;
          _playbackError = e.message;
        default:
          _playbackError = e.message;
      }
    } catch (e, stack) {
      debugPrint('Spotify playback read failed: $e\n$stack');
      _playbackError = 'Could not read Spotify playback';
    } finally {
      _fetching = false;
      _notify();
    }
  }

  // Playback commands ------------------------------------------------------

  Future<void> togglePlayPause() {
    final playing = _playback?.isPlaying ?? false;
    return _command(
      playing ? _player.pause : _player.play,
      optimistic: (s) {
        final now = DateTime.now();
        return s.copyWith(
          isPlaying: !playing,
          progress: s.positionAt(now),
          fetchedAt: now,
        );
      },
    );
  }

  Future<void> skipNext() => _command(_player.next);

  Future<void> skipPrevious() => _command(_player.previous);

  Future<void> seek(Duration position) => _command(
        () => _player.seek(position),
        optimistic: (s) =>
            s.copyWith(progress: position, fetchedAt: DateTime.now()),
      );

  Future<void> toggleShuffle() {
    final enabled = !(_playback?.shuffle ?? false);
    return _command(
      () => _player.setShuffle(enabled),
      optimistic: (s) => s.copyWith(shuffle: enabled),
    );
  }

  Future<void> cycleRepeat() {
    final mode = (_playback?.repeatMode ?? SpotifyRepeatMode.off).next;
    return _command(
      () => _player.setRepeat(mode),
      optimistic: (s) => s.copyWith(repeatMode: mode),
    );
  }

  Future<void> _command(
    Future<void> Function() action, {
    SpotifyPlaybackState Function(SpotifyPlaybackState state)? optimistic,
  }) async {
    if (!canControl) return;
    final before = _playback;
    if (optimistic != null && before != null) {
      _playback = optimistic(before);
      _notify();
    }

    _commandsInFlight++;
    try {
      await action();
      if (_message != null) _message = null;
    } on SpotifyPlayerException catch (e) {
      _playback = before;
      switch (e.kind) {
        case SpotifyPlayerErrorKind.unauthorized:
          _expireSession();
        case SpotifyPlayerErrorKind.premiumRequired:
          _premiumRequired = true;
          _message = e.message;
        default:
          _message = e.message;
      }
    } on SpotifyAuthException catch (e) {
      _playback = before;
      if (e.sessionExpired) {
        _expireSession();
      } else {
        _message = e.message;
      }
    } catch (_) {
      _playback = before;
      _message = 'No connection to Spotify';
    } finally {
      _commandsInFlight--;
    }
    _notify();

    // Spotify applies commands asynchronously; re-read shortly after.
    _followUpTimer?.cancel();
    _followUpTimer = Timer(_followUpDelay, () => refresh());
  }

  // Internals --------------------------------------------------------------

  void _onConnected() {
    _session = _Session.connected;
    _message = null;
    _premiumRequired = false;
    _startPolling();
    _notify();
    refresh();
  }

  void _expireSession() {
    _stopPolling();
    _resetPlayer();
    _session = _Session.loggedOut;
    _message = _expiredMessage;
    _auth.logout();
  }

  void _resetPlayer() {
    _playback = null;
    _contextUri = null;
    _contextName = null;
    _premiumRequired = false;
    _rateLimitedUntil = null;
    _playbackError = null;
  }

  void _updateContext(SpotifyPlaybackContext? context) {
    if (context?.uri == _contextUri) return;
    _contextUri = context?.uri;
    _contextName = null;
    if (context != null) _loadContextName(context);
  }

  Future<void> _loadContextName(SpotifyPlaybackContext context) async {
    String? name;
    try {
      name = await _player.fetchContextName(context);
    } catch (_) {
      // Name is decorative; the UI falls back to the context type.
    }
    if (_contextUri != context.uri) return;
    _contextName = name;
    _notify();
  }

  Future<void> _onResume() async {
    if (!_configured) return;
    final installed = await _launcher.isInstalled();
    if (installed != _appInstalled) {
      _appInstalled = installed;
      _notify();
    }
    if (_session == _Session.connected) {
      _startPolling();
      refresh();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => refresh());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _followUpTimer?.cancel();
  }

  Future<void> _launch(Future<bool> Function() open) async {
    try {
      if (await open()) return;
    } catch (_) {
      // Reported below.
    }
    _message = 'Could not open Spotify on this device';
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopPolling();
    _lifecycle?.dispose();
    _player.dispose();
    _auth.dispose();
    super.dispose();
  }
}
