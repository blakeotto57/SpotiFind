import 'dart:convert';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class SpotifyAuthService {
  SpotifyAuthService._();
  static final SpotifyAuthService instance = SpotifyAuthService._();

  static const _clientId = "f8fe29ba24914b89aa94121926506b53";
  static const _redirectUrl = "spotifind://callback";

  // Spotify endpoints
  static const _authEndpoint = "https://accounts.spotify.com/authorize";
  static const _tokenEndpoint = "https://accounts.spotify.com/api/token";

  static const _refreshTokenKey = "spotify_refresh_token";
  static const _accessTokenKey = "spotify_access_token";
  static const _accessExpKey = "spotify_access_exp";

  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Step B: Connect (PKCE) and store tokens.
  Future<void> connect() async {
    final req = AuthorizationTokenRequest(
      _clientId,
      _redirectUrl,
      // Scopes for "currently playing"
      scopes: const [
        "user-read-currently-playing",
        "user-read-playback-state",
      ],
      serviceConfiguration: const AuthorizationServiceConfiguration(
        authorizationEndpoint: _authEndpoint,
        tokenEndpoint: _tokenEndpoint,
      ),
      // Optional params:
      // - show_dialog forces consent screen (useful while testing)
      additionalParameters: const {"show_dialog": "true"},
    );

    final res = await _appAuth.authorizeAndExchangeCode(req);
    if (res == null) throw Exception("Spotify auth cancelled");

    if (res.refreshToken == null || res.refreshToken!.isEmpty) {
      throw Exception(
        "No refresh token returned. In Spotify Dashboard, ensure this exact redirect URI is allowlisted.",
      );
    }

    await _storage.write(key: _refreshTokenKey, value: res.refreshToken);
    await _storage.write(key: _accessTokenKey, value: res.accessToken);

    final exp = res.accessTokenExpirationDateTime?.millisecondsSinceEpoch;
    if (exp != null) {
      await _storage.write(key: _accessExpKey, value: exp.toString());
    }
  }

  Future<bool> isConnected() async {
    final rt = await _storage.read(key: _refreshTokenKey);
    return rt != null && rt.isNotEmpty;
  }

  Future<void> disconnect() async {
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _accessExpKey);
  }

  /// Returns a valid access token, refreshing if needed.
  Future<String> getValidAccessToken() async {
    final rt = await _storage.read(key: _refreshTokenKey);
    if (rt == null || rt.isEmpty) {
      throw Exception("Spotify not connected");
    }

    final access = await _storage.read(key: _accessTokenKey);
    final expStr = await _storage.read(key: _accessExpKey);
    final expMs = int.tryParse(expStr ?? "");

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final isExpiredSoon = expMs == null ? true : (expMs - nowMs) < 60 * 1000;

    if (access != null && access.isNotEmpty && !isExpiredSoon) {
      return access;
    }

    final tokenRes = await _appAuth.token(TokenRequest(
      _clientId,
      _redirectUrl,
      refreshToken: rt,
      serviceConfiguration: const AuthorizationServiceConfiguration(
        authorizationEndpoint: _authEndpoint,
        tokenEndpoint: _tokenEndpoint,
      ),
    ));

    if (tokenRes?.accessToken == null) {
      throw Exception("Spotify token refresh failed");
    }

    await _storage.write(key: _accessTokenKey, value: tokenRes!.accessToken);
    final exp = tokenRes.accessTokenExpirationDateTime?.millisecondsSinceEpoch;
    if (exp != null) {
      await _storage.write(key: _accessExpKey, value: exp.toString());
    }
    return tokenRes.accessToken!;
  }

  /// Optional helper: get Spotify profile (/me) for displayName + avatar
  Future<Map<String, dynamic>> getMe() async {
    final token = await getValidAccessToken();
    final resp = await http.get(
      Uri.parse("https://api.spotify.com/v1/me"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (resp.statusCode != 200) {
      throw Exception("Spotify /me failed: ${resp.statusCode} ${resp.body}");
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Get currently playing track
  Future<Map<String, dynamic>?> getCurrentlyPlaying() async {
    final token = await getValidAccessToken();
    final resp = await http.get(
      Uri.parse("https://api.spotify.com/v1/me/player/currently-playing"),
      headers: {"Authorization": "Bearer $token"},
    );

    // 204 = nothing playing
    if (resp.statusCode == 204) return null;
    if (resp.statusCode != 200) {
      throw Exception("Spotify currently-playing failed: ${resp.statusCode} ${resp.body}");
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
