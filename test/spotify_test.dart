import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_tablet_ui/screens/music_screen.dart';
import 'package:vehicle_tablet_ui/theme/app_theme.dart';
import 'package:vehicle_tablet_ui/widgets/media/spotify_mini_player.dart';
import 'package:vehicle_tablet_ui/models/spotify_playback_state.dart';
import 'package:vehicle_tablet_ui/services/spotify/spotify_app_launcher.dart';
import 'package:vehicle_tablet_ui/services/spotify/spotify_auth_service.dart';
import 'package:vehicle_tablet_ui/services/spotify/spotify_player_service.dart';
import 'package:vehicle_tablet_ui/services/spotify/spotify_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PKCE', () {
    test('code challenge matches the RFC 7636 example', () {
      expect(
        SpotifyAuthService.codeChallenge(
            'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('code verifier uses the unreserved character set', () {
      final verifier = SpotifyAuthService.generateCodeVerifier();
      expect(verifier, hasLength(64));
      expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(verifier), isTrue);
    });
  });

  group('SpotifyPlaybackState.fromJson', () {
    final fetchedAt = DateTime(2026, 1, 1, 12);
    final state =
        SpotifyPlaybackState.fromJson(_playerJson, receivedAt: fetchedAt);

    test('parses track, context, device and disallows', () {
      final track = state.track!;
      expect(track.name, 'Vampire');
      expect(track.artistLine, 'Olivia Rodrigo');
      expect(track.albumName, 'GUTS');
      expect(track.artworkUrl, 'https://i.scdn.co/640');
      expect(track.thumbnailUrl, 'https://i.scdn.co/64');
      expect(track.duration, const Duration(milliseconds: 219724));
      expect(state.isPlaying, isTrue);
      expect(state.shuffle, isTrue);
      expect(state.repeatMode, SpotifyRepeatMode.context);
      expect(state.context!.typeLabel, 'Playlist');
      expect(state.deviceName, 'Pixel Tablet');
      expect(state.allows(SpotifyAction.skippingPrev), isFalse);
      expect(state.allows(SpotifyAction.skippingNext), isTrue);
    });

    test('extrapolates position while playing and clamps to duration', () {
      expect(
        state.positionAt(fetchedAt.add(const Duration(seconds: 2))),
        const Duration(milliseconds: 12000),
      );
      expect(
        state.positionAt(fetchedAt.add(const Duration(hours: 1))),
        state.track!.duration,
      );
    });
  });

  group('SpotifyService', () {
    late _FakeAuth auth;
    late _FakePlayer player;
    late _FakeLauncher launcher;
    SpotifyService? service;

    SpotifyService create({bool configured = true}) => service = SpotifyService(
          auth: auth,
          player: player,
          launcher: launcher,
          configured: configured,
        );

    setUp(() {
      auth = _FakeAuth();
      player = _FakePlayer();
      launcher = _FakeLauncher();
    });
    tearDown(() => service?.dispose());

    test('is unavailable without a client ID', () async {
      final s = create(configured: false);
      await s.init();
      expect(s.status, SpotifyConnectionStatus.unavailable);
      expect(s.unavailableReason, SpotifyUnavailableReason.notConfigured);
    });

    test('is unavailable when logged out and the app is missing', () async {
      launcher.installed = false;
      final s = create();
      await s.init();
      expect(s.status, SpotifyConnectionStatus.unavailable);
      expect(s.unavailableReason, SpotifyUnavailableReason.appNotInstalled);
    });

    test('is logged out with no stored session', () async {
      final s = create();
      await s.init();
      expect(s.status, SpotifyConnectionStatus.loggedOut);
      expect(s.canControl, isFalse);
    });

    test('restores a stored session and loads playback', () async {
      auth.session = true;
      final s = create();
      await s.init();
      await s.refresh();
      expect(s.status, SpotifyConnectionStatus.connected);
      expect(s.playback!.track!.name, 'Vampire');
      expect(s.canTogglePlay, isTrue);
    });

    test('cancelled sign-in returns to logged out without a message', () async {
      auth.loginError =
          const SpotifyAuthException('cancelled', cancelled: true);
      final s = create();
      await s.init();
      await s.connect();
      expect(s.status, SpotifyConnectionStatus.loggedOut);
      expect(s.message, isNull);
    });

    test('Premium-required command reverts and disables controls', () async {
      auth.session = true;
      player.commandError = const SpotifyPlayerException(
        SpotifyPlayerErrorKind.premiumRequired,
        'Spotify Premium is required to control playback',
      );
      final s = create();
      await s.init();
      await s.refresh();

      await s.togglePlayPause();
      expect(s.playback!.isPlaying, isTrue,
          reason: 'optimistic change reverted');
      expect(s.canControl, isFalse);
      expect(s.message, contains('Premium'));
    });

    test('refused playback read surfaces the reason, then clears', () async {
      auth.session = true;
      player.fetchError = const SpotifyPlayerException(
        SpotifyPlayerErrorKind.restricted,
        'Spotify refused the request: Active premium subscription required',
      );
      final s = create();
      await s.init();
      await s.refresh();
      expect(s.status, SpotifyConnectionStatus.connected);
      expect(s.playback, isNull);
      expect(s.playbackError, contains('premium'));

      player.fetchError = null;
      await s.refresh();
      expect(s.playbackError, isNull);
      expect(s.playback!.track!.name, 'Vampire');
    });

    test('disconnect clears playback', () async {
      auth.session = true;
      final s = create();
      await s.init();
      await s.refresh();
      await s.disconnect();
      expect(s.status, SpotifyConnectionStatus.loggedOut);
      expect(s.playback, isNull);
      expect(auth.session, isFalse);
    });
  });

  group('Music UI renders without overflow', () {
    Future<SpotifyService> service({
      bool configured = true,
      bool session = false,
      bool? installed = true,
    }) async {
      final auth = _FakeAuth()..session = session;
      final launcher = _FakeLauncher()..installed = installed;
      final s = SpotifyService(
        auth: auth,
        player: _FakePlayer(),
        launcher: launcher,
        configured: configured,
      );
      await s.init();
      await s.refresh();
      return s;
    }

    Future<void> pump(
        WidgetTester tester, Widget child, ThemeData theme) async {
      // Body area of a 1280x800 landscape tablet (minus the 10.5% dock).
      tester.view.physicalSize = const Size(1280, 716);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: theme, home: child));
      await tester.pump();
    }

    final cases = <String, Future<SpotifyService> Function()>{
      'not configured': () => service(configured: false),
      'app missing': () => service(installed: false),
      'logged out': () => service(),
      'connected': () => service(session: true),
    };

    for (final entry in cases.entries) {
      for (final dark in [false, true]) {
        final theme = dark ? AppTheme.dark() : AppTheme.light();
        final mode = dark ? 'dark' : 'light';

        testWidgets('music screen: ${entry.key} ($mode)', (tester) async {
          final s = await tester.runAsync(entry.value);
          await pump(tester, MusicScreen(spotify: s!), theme);
          expect(tester.takeException(), isNull);
          s.dispose();
        });

        testWidgets('mini player: ${entry.key} ($mode)', (tester) async {
          final s = await tester.runAsync(entry.value);
          await pump(
            tester,
            Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 118,
                  child: SpotifyMiniPlayer(spotify: s!, onOpen: () {}),
                ),
              ),
            ),
            theme,
          );
          expect(tester.takeException(), isNull);
          s.dispose();
        });
      }
    }
  });
}

final Map<String, dynamic> _playerJson = {
  'device': {'name': 'Pixel Tablet', 'is_restricted': false},
  'shuffle_state': true,
  'repeat_state': 'context',
  'context': {'type': 'playlist', 'uri': 'spotify:playlist:abc'},
  'progress_ms': 10000,
  'is_playing': true,
  'actions': {
    'disallows': {'skipping_prev': true, 'resuming': false},
  },
  'item': {
    'type': 'track',
    'uri': 'spotify:track:1',
    'name': 'Vampire',
    'duration_ms': 219724,
    'artists': [
      {'name': 'Olivia Rodrigo'},
    ],
    'album': {
      'name': 'GUTS',
      'images': [
        {'url': 'https://i.scdn.co/64', 'width': 64},
        {'url': 'https://i.scdn.co/640', 'width': 640},
        {'url': 'https://i.scdn.co/300', 'width': 300},
      ],
    },
  },
};

class _FakeAuth implements SpotifyAuthService {
  bool session = false;
  SpotifyAuthException? loginError;

  @override
  Future<bool> hasSession() async => session;

  @override
  Future<void> login() async {
    if (loginError != null) throw loginError!;
    session = true;
  }

  @override
  Future<String> accessToken() async => 'token';

  @override
  Future<void> refresh() async {}

  @override
  Future<void> logout() async => session = false;

  @override
  void dispose() {}
}

class _FakePlayer implements SpotifyPlayerService {
  SpotifyPlayerException? commandError;
  SpotifyPlayerException? fetchError;

  Future<void> _command() async {
    if (commandError != null) throw commandError!;
  }

  @override
  Future<SpotifyPlaybackState?> fetchPlayback() async {
    if (fetchError != null) throw fetchError!;
    return SpotifyPlaybackState.fromJson(_playerJson,
        receivedAt: DateTime.now());
  }

  @override
  Future<String?> fetchContextName(SpotifyPlaybackContext context) async =>
      'Road Trip';

  @override
  Future<void> play() => _command();

  @override
  Future<void> pause() => _command();

  @override
  Future<void> next() => _command();

  @override
  Future<void> previous() => _command();

  @override
  Future<void> seek(Duration position) => _command();

  @override
  Future<void> setShuffle(bool enabled) => _command();

  @override
  Future<void> setRepeat(SpotifyRepeatMode mode) => _command();

  @override
  void dispose() {}
}

class _FakeLauncher implements SpotifyAppLauncher {
  bool? installed = true;

  @override
  Future<bool?> isInstalled() async => installed;

  @override
  Future<bool> openApp() async => true;

  @override
  Future<bool> openStore() async => true;
}
