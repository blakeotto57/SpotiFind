import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
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

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Generate PKCE code verifier and challenge
  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Step B: Connect (PKCE) and store tokens.
  Future<void> connect() async {
    debugPrint("SpotifyAuth: begin connect");

    try {
      // Clear any old tokens first
      await disconnect();
      
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      
      debugPrint("SpotifyAuth: generated PKCE verifier and challenge");

      // Build authorization URL
      final authUrl = Uri.parse(_authEndpoint).replace(
        queryParameters: {
          'client_id': _clientId,
          'response_type': 'code',
          'redirect_uri': _redirectUrl,
          'code_challenge_method': 'S256',
          'code_challenge': codeChallenge,
          'scope': 'user-read-currently-playing user-read-playback-state user-read-private',
          'show_dialog': 'true',
        },
      );

      debugPrint("SpotifyAuth: calling FlutterWebAuth2.authenticate");
      debugPrint("SpotifyAuth: authUrl=$authUrl");

      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: "spotifind",
      );

      debugPrint("SpotifyAuth: authenticate returned: $result");

      // Extract authorization code from callback URL
      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];
      
      if (code == null || code.isEmpty) {
        throw Exception("No authorization code in callback");
      }

      debugPrint("SpotifyAuth: got authorization code, exchanging for tokens");

      // Exchange authorization code for tokens
      final tokenResponse = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUrl,
          'code_verifier': codeVerifier,
        },
      );

      debugPrint("SpotifyAuth: token exchange response: ${tokenResponse.statusCode}");

      if (tokenResponse.statusCode != 200) {
        debugPrint("SpotifyAuth: token exchange failed: ${tokenResponse.body}");
        throw Exception("Failed to exchange code for tokens: ${tokenResponse.statusCode}");
      }

      final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      final refreshToken = tokenData['refresh_token'] as String?;
      final accessToken = tokenData['access_token'] as String?;
      final expiresIn = tokenData['expires_in'] as int?;

      if (refreshToken == null || refreshToken.isEmpty) {
        throw Exception("No refresh token in token response");
      }

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception("No access token in token response");
      }

      // Store tokens
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      await _storage.write(key: _accessTokenKey, value: accessToken);

      if (expiresIn != null) {
        final expMs = DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);
        await _storage.write(key: _accessExpKey, value: expMs.toString());
      }

      debugPrint("SpotifyAuth: tokens stored successfully");
      
      // Verify which account we connected to
      try {
        await getMe();
      } catch (e) {
        debugPrint("SpotifyAuth: Warning - could not verify account: $e");
      }
    } catch (e) {
      debugPrint("SpotifyAuth: connect error: $e");
      rethrow;
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
  /// If getNewToken is true, forces refresh even if cached token exists
  Future<String> getValidAccessToken({bool forceRefresh = false}) async {
    final rt = await _storage.read(key: _refreshTokenKey);
    if (rt == null || rt.isEmpty) {
      throw Exception("Spotify not connected");
    }

    if (!forceRefresh) {
      final access = await _storage.read(key: _accessTokenKey);
      final expStr = await _storage.read(key: _accessExpKey);
      final expMs = int.tryParse(expStr ?? "");

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final isExpiredSoon = expMs == null ? true : (expMs - nowMs) < 60 * 1000;

      if (access != null && access.isNotEmpty && !isExpiredSoon) {
        debugPrint("[SpotifyAuth] Using cached access token (expires in ${((expMs ?? 0) - nowMs) / 1000 / 60} minutes)");
        return access;
      }
    } else {
      debugPrint("[SpotifyAuth] Forcing token refresh...");
    }

    debugPrint("[SpotifyAuth] Access token expired or missing, refreshing...");
    
    // Refresh the access token using the refresh token
    final refreshResponse = await http.post(
      Uri.parse(_tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'grant_type': 'refresh_token',
        'refresh_token': rt,
      },
    );

    if (refreshResponse.statusCode != 200) {
      debugPrint("[SpotifyAuth] Token refresh failed: ${refreshResponse.statusCode}");
      debugPrint("[SpotifyAuth] Response: ${refreshResponse.body.substring(0, min(500, refreshResponse.body.length))}");
      throw Exception("Spotify token refresh failed: ${refreshResponse.statusCode}");
    }

    final tokenData = jsonDecode(refreshResponse.body) as Map<String, dynamic>;
    final newAccessToken = tokenData['access_token'] as String?;
    final expiresIn = tokenData['expires_in'] as int?;

    if (newAccessToken == null || newAccessToken.isEmpty) {
      throw Exception("No access token in refresh response");
    }

    await _storage.write(key: _accessTokenKey, value: newAccessToken);
    
    if (expiresIn != null) {
      final expMs = DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);
      await _storage.write(key: _accessExpKey, value: expMs.toString());
    }

    debugPrint("[SpotifyAuth] ✓ Got new access token (expires in $expiresIn seconds)");
    return newAccessToken;
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
    final meData = jsonDecode(resp.body) as Map<String, dynamic>;
    final email = meData['email'] as String?;
    final displayName = meData['display_name'] as String?;
    debugPrint("[SpotifyAuth] ✓ Connected as: $displayName ($email)");
    return meData;
  }

  /// Get currently playing track
  Future<Map<String, dynamic>?> getCurrentlyPlaying() async {
    try {
      debugPrint("[SpotifyAuth] Getting valid access token...");
      final token = await getValidAccessToken();
      debugPrint("[SpotifyAuth] Got access token, fetching currently playing...");
      
      final resp = await http.get(
        Uri.parse("https://api.spotify.com/v1/me/player/currently-playing"),
        headers: {"Authorization": "Bearer $token"},
      );

      debugPrint("[SpotifyAuth] Currently-playing response: ${resp.statusCode}");

      // 204 = nothing playing
      if (resp.statusCode == 204) {
        debugPrint("[SpotifyAuth] No track currently playing (204 response)");
        // Try to get device info to help debug
        debugPrint("[SpotifyAuth] Fetching device info...");
        await _getAvailableDevices(token);
        return null;
      }
      if (resp.statusCode != 200) {
        debugPrint("[SpotifyAuth] Error response: ${resp.body}");
        throw Exception("Spotify currently-playing failed: ${resp.statusCode} ${resp.body}");
      }
      
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      debugPrint("[SpotifyAuth] Successfully parsed response");
      return data;
    } catch (e) {
      debugPrint("[SpotifyAuth] Error in getCurrentlyPlaying: $e");
      rethrow;
    }
  }

  /// Helper method to get available devices (for debugging)
  Future<void> _getAvailableDevices(String token) async {
    try {
      final resp = await http.get(
        Uri.parse("https://api.spotify.com/v1/me/player/devices"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final devices = data['devices'] as List?;
        
        if (devices != null && devices.isNotEmpty) {
          debugPrint("[SpotifyAuth] Available devices: ${devices.length}");
          for (final device in devices) {
            final deviceMap = device as Map<String, dynamic>;
            final name = deviceMap['name'] ?? 'Unknown';
            final type = deviceMap['type'] ?? 'Unknown';
            final isActive = deviceMap['is_active'] ?? false;
            debugPrint("[SpotifyAuth] - Device: $name (Type: $type, Active: $isActive)");
          }
        } else {
          debugPrint("[SpotifyAuth] No devices available");
        }
      } else {
        debugPrint("[SpotifyAuth] Failed to get devices: ${resp.statusCode}");
      }
    } catch (e) {
      debugPrint("[SpotifyAuth] Error fetching devices: $e");
    }
  }

  /// Get currently playing by checking all available devices
  /// Since Spotify API only returns playback from the active device,
  /// we use the /me/player endpoint which returns player state regardless
  Future<Map<String, dynamic>?> getCurrentlyPlayingFromAnyDevice() async {
    try {
      final token = await getValidAccessToken();
      debugPrint("[SpotifyAuth] ========== GETTING PLAYBACK FROM /me/player ==========");
      
      // Use the /me/player endpoint which returns current playback context
      final resp = await http.get(
        Uri.parse("https://api.spotify.com/v1/me/player"),
        headers: {"Authorization": "Bearer $token"},
      );

      debugPrint("[SpotifyAuth] /me/player response status: ${resp.statusCode}");

      if (resp.statusCode == 204) {
        debugPrint("[SpotifyAuth] No active playback (204 response)");
        return null;
      }

      if (resp.statusCode != 200) {
        debugPrint("[SpotifyAuth] Failed to get player state: ${resp.statusCode}");
        debugPrint("[SpotifyAuth] Response: ${resp.body.substring(0, min(500, resp.body.length))}");
        return null;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final isPlaying = data['is_playing'] as bool? ?? false;
      final item = data['item'] as Map<String, dynamic>?;
      
      debugPrint("[SpotifyAuth] Is playing: $isPlaying");
      debugPrint("[SpotifyAuth] Has item: ${item != null}");
      
      if (item != null) {
        debugPrint("[SpotifyAuth] Current track: ${item['name']}");
        debugPrint("[SpotifyAuth] Device: ${data['device']?['name']}");
      }
      
      // Return the full player state if we have playback info
      if (isPlaying && item != null) {
        debugPrint("[SpotifyAuth] ✓ Got active playback from /me/player");
        return data;
      } else if (item != null) {
        debugPrint("[SpotifyAuth] ✓ Got item (paused playback) from /me/player");
        return data;
      }

      debugPrint("[SpotifyAuth] No track data available from /me/player");
      return null;
    } catch (e) {
      debugPrint("[SpotifyAuth] ✗ Error in getCurrentlyPlayingFromAnyDevice: $e");
      return null;
    }
  }

  /// Get all devices with their current playback state
  /// Returns a list of maps containing device info and playback data
  Future<List<Map<String, dynamic>>?> getAvailableDevicesWithPlayback() async {
    try {
      final token = await getValidAccessToken();
      debugPrint("[SpotifyAuth] Fetching devices with playback...");
      
      final resp = await http.get(
        Uri.parse("https://api.spotify.com/v1/me/player/devices"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (resp.statusCode != 200) {
        debugPrint("[SpotifyAuth] Failed to get devices: ${resp.statusCode}");
        return null;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final devices = data['devices'] as List?;

      if (devices == null || devices.isEmpty) {
        debugPrint("[SpotifyAuth] No devices available");
        return null;
      }

      debugPrint("[SpotifyAuth] Found ${devices.length} devices");
      
      final result = <Map<String, dynamic>>[];

      // For each device, check if it's active
      for (final device in devices) {
        final deviceMap = device as Map<String, dynamic>;
        final deviceName = deviceMap['name'] ?? 'Unknown';
        final isActive = deviceMap['is_active'] as bool? ?? false;
        
        debugPrint("[SpotifyAuth] Device: $deviceName (Active: $isActive)");
        
        // If this device is active, we can get its playback
        if (isActive) {
          result.add({'device': deviceMap, 'is_active': true});
        }
      }

      return result.isEmpty ? null : result;
    } catch (e) {
      debugPrint("[SpotifyAuth] Error in getAvailableDevicesWithPlayback: $e");
      return null;
    }
  }
}
