import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/spotify_playback_state.dart';
import 'spotify_auth_service.dart';
import 'spotify_player_service.dart';

/// [SpotifyPlayerService] backed by the Spotify Web API (`/v1/me/player`).
///
/// Reading playback works for every account. Playback commands require
/// Spotify Premium and an active device (this tablet's Spotify app, a
/// phone, a speaker, ...). Spotify reports both cases as errors, which are
/// mapped to [SpotifyPlayerErrorKind] values.
class SpotifyWebApiPlayerService implements SpotifyPlayerService {
  SpotifyWebApiPlayerService(this._auth, {http.Client? client})
      : _client = client ?? http.Client();

  static final Uri _api = Uri.parse('https://api.spotify.com/v1/');
  static const Duration _timeout = Duration(seconds: 10);

  final SpotifyAuthService _auth;
  final http.Client _client;

  @override
  Future<SpotifyPlaybackState?> fetchPlayback() async {
    final response = await _send(
      'GET',
      'me/player',
      query: {'additional_types': 'track,episode'},
    );
    if (response.statusCode == 204 || response.body.isEmpty) return null;
    return SpotifyPlaybackState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
      receivedAt: DateTime.now(),
    );
  }

  @override
  Future<String?> fetchContextName(SpotifyPlaybackContext context) async {
    // Context URIs look like spotify:playlist:<id>.
    final parts = context.uri.split(':');
    if (parts.length != 3) return null;
    final id = parts[2];
    final path = switch (parts[1]) {
      'playlist' => 'playlists/$id',
      'album' => 'albums/$id',
      'artist' => 'artists/$id',
      'show' => 'shows/$id',
      _ => null,
    };
    if (path == null) return null;
    try {
      final response = await _send(
        'GET',
        path,
        query: parts[1] == 'playlist' ? {'fields': 'name'} : null,
      );
      return (jsonDecode(response.body) as Map<String, dynamic>)['name']
          as String?;
    } on SpotifyPlayerException {
      // Some contexts (e.g. Spotify-owned playlists) are not readable by
      // newer apps; the UI falls back to the context type.
      return null;
    }
  }

  @override
  Future<void> play() => _send('PUT', 'me/player/play');

  @override
  Future<void> pause() => _send('PUT', 'me/player/pause');

  @override
  Future<void> next() => _send('POST', 'me/player/next');

  @override
  Future<void> previous() => _send('POST', 'me/player/previous');

  @override
  Future<void> seek(Duration position) => _send(
        'PUT',
        'me/player/seek',
        query: {'position_ms': '${position.inMilliseconds}'},
      );

  @override
  Future<void> setShuffle(bool enabled) =>
      _send('PUT', 'me/player/shuffle', query: {'state': '$enabled'});

  @override
  Future<void> setRepeat(SpotifyRepeatMode mode) =>
      _send('PUT', 'me/player/repeat', query: {'state': mode.name});

  @override
  void dispose() => _client.close();

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    bool isRetry = false,
  }) async {
    final token = await _auth.accessToken();
    final request = http.Request(
      method,
      _api.resolve(path).replace(queryParameters: query),
    )..headers['Authorization'] = 'Bearer $token';

    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw const SpotifyPlayerException(
        SpotifyPlayerErrorKind.network,
        'Spotify is not responding',
      );
    } on http.ClientException {
      throw const SpotifyPlayerException(
        SpotifyPlayerErrorKind.network,
        'No connection to Spotify',
      );
    }

    if (response.statusCode == 401 && !isRetry) {
      await _auth.refresh();
      return _send(method, path, query: query, isRetry: true);
    }
    if (response.statusCode >= 400) {
      debugPrint('Spotify $method $path -> ${response.statusCode} '
          '${response.body}');
      throw _errorFor(response);
    }
    return response;
  }

  SpotifyPlayerException _errorFor(http.Response response) {
    String? reason;
    String? detail;
    try {
      final error = (jsonDecode(response.body) as Map)['error'];
      if (error is Map) {
        reason = error['reason'] as String?;
        detail = error['message'] as String?;
      }
    } catch (_) {
      // Non-JSON error body; fall through to status-code handling.
    }

    final status = response.statusCode;
    if (status == 429) {
      final seconds = int.tryParse(response.headers['retry-after'] ?? '');
      return SpotifyPlayerException(
        SpotifyPlayerErrorKind.rateLimited,
        'Spotify is busy. Try again in a moment.',
        retryAfter: Duration(seconds: seconds ?? 5),
      );
    }
    if (status == 401) {
      return const SpotifyPlayerException(
        SpotifyPlayerErrorKind.unauthorized,
        'Spotify session expired',
      );
    }
    if (reason == 'PREMIUM_REQUIRED') {
      return const SpotifyPlayerException(
        SpotifyPlayerErrorKind.premiumRequired,
        'Spotify Premium is required to control playback',
      );
    }
    if (reason == 'NO_ACTIVE_DEVICE') {
      return const SpotifyPlayerException(
        SpotifyPlayerErrorKind.noActiveDevice,
        'No active Spotify device. Start playback in Spotify first.',
      );
    }
    if (status == 403) {
      // Development Mode apps are refused outright when the app owner has
      // no Premium or the user is not on the app's allowlist.
      return SpotifyPlayerException(
        SpotifyPlayerErrorKind.restricted,
        detail == null || detail.isEmpty
            ? 'Spotify refused the request (403)'
            : 'Spotify refused the request: $detail',
      );
    }
    return SpotifyPlayerException(
      SpotifyPlayerErrorKind.unknown,
      detail == null || detail.isEmpty
          ? 'Spotify request failed ($status)'
          : 'Spotify request failed ($status): $detail',
    );
  }
}
