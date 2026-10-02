import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import 'spotify_config.dart';

class SpotifyAuthException implements Exception {
  const SpotifyAuthException(
    this.message, {
    this.cancelled = false,
    this.sessionExpired = false,
  });

  final String message;

  /// The user closed the sign-in page.
  final bool cancelled;

  /// The stored session is gone or revoked; the user must sign in again.
  final bool sessionExpired;

  @override
  String toString() => 'SpotifyAuthException: $message';
}

/// Spotify sign-in using Authorization Code with PKCE.
///
/// Only the refresh token is persisted, in the platform keystore via
/// flutter_secure_storage. The access token is kept in memory and renewed
/// on demand.
class SpotifyAuthService {
  SpotifyAuthService({FlutterSecureStorage? storage, http.Client? client})
      : _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client();

  static final Uri _authorizeUrl =
      Uri.parse('https://accounts.spotify.com/authorize');
  static final Uri _tokenUrl =
      Uri.parse('https://accounts.spotify.com/api/token');
  static const String _refreshTokenKey = 'spotify_refresh_token';
  static const Duration _timeout = Duration(seconds: 15);

  final FlutterSecureStorage _storage;
  final http.Client _client;

  String? _accessToken;
  DateTime _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _refreshing;

  Future<bool> hasSession() async =>
      await _storage.read(key: _refreshTokenKey) != null;

  /// Opens Spotify's sign-in page in a browser tab and completes the
  /// code exchange.
  Future<void> login() async {
    final verifier = generateCodeVerifier();
    final state = generateCodeVerifier(length: 16);
    final url = _authorizeUrl.replace(queryParameters: {
      'client_id': SpotifyConfig.clientId,
      'response_type': 'code',
      'redirect_uri': SpotifyConfig.redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': codeChallenge(verifier),
      'scope': SpotifyConfig.scopes.join(' '),
      'state': state,
    });

    final String callback;
    try {
      callback = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: SpotifyConfig.callbackScheme,
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') {
        throw const SpotifyAuthException('Sign-in cancelled', cancelled: true);
      }
      throw SpotifyAuthException('Sign-in failed: ${e.message ?? e.code}');
    }

    final params = Uri.parse(callback).queryParameters;
    if (params['state'] != state) {
      throw const SpotifyAuthException('Sign-in response did not match');
    }
    final error = params['error'];
    if (error != null) {
      throw SpotifyAuthException(error == 'access_denied'
          ? 'Spotify access was declined'
          : 'Sign-in failed: $error');
    }
    final code = params['code'];
    if (code == null) {
      throw const SpotifyAuthException('Sign-in failed: no code returned');
    }

    await _requestToken({
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': SpotifyConfig.redirectUri,
      'code_verifier': verifier,
    });
  }

  /// A valid access token, refreshing it first if it is about to expire.
  Future<String> accessToken() async {
    final token = _accessToken;
    if (token != null &&
        DateTime.now()
            .isBefore(_expiresAt.subtract(const Duration(seconds: 60)))) {
      return token;
    }
    await refresh();
    return _accessToken!;
  }

  /// Forces a token refresh. Concurrent callers share one request.
  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) {
      throw const SpotifyAuthException('Not signed in', sessionExpired: true);
    }
    await _requestToken({
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    });
  }

  Future<void> _requestToken(Map<String, String> body) async {
    final response = await _client.post(_tokenUrl,
        body: {...body, 'client_id': SpotifyConfig.clientId}).timeout(_timeout);

    if (response.statusCode != 200) {
      final isRefresh = body['grant_type'] == 'refresh_token';
      if (isRefresh &&
          (response.statusCode == 400 || response.statusCode == 401)) {
        // invalid_grant: the refresh token was revoked or has expired.
        await logout();
        throw const SpotifyAuthException(
          'Spotify session expired',
          sessionExpired: true,
        );
      }
      throw SpotifyAuthException(
          'Spotify sign-in failed (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = json['access_token'] as String;
    _expiresAt = DateTime.now()
        .add(Duration(seconds: (json['expires_in'] as num).toInt()));
    // Spotify may rotate the refresh token; keep the newest one.
    final refreshToken = json['refresh_token'] as String?;
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<void> logout() async {
    _accessToken = null;
    _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);
    await _storage.delete(key: _refreshTokenKey);
  }

  void dispose() => _client.close();

  static const _verifierChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  @visibleForTesting
  static String generateCodeVerifier({int length = 64, Random? random}) {
    final rng = random ?? Random.secure();
    return String.fromCharCodes(List.generate(
      length,
      (_) => _verifierChars.codeUnitAt(rng.nextInt(_verifierChars.length)),
    ));
  }

  @visibleForTesting
  static String codeChallenge(String verifier) => base64Url
      .encode(sha256.convert(ascii.encode(verifier)).bytes)
      .replaceAll('=', '');
}
