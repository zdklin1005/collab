import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Representation of a music track for 24-hr Insta Notes
class SpotifyTrack {
  const SpotifyTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.albumArtUrl,
    required this.spotifyUrl,
    this.previewAudioUrl,
    this.isPlaying = false,
  });

  final String id;
  final String title;
  final String artist;
  final String? albumArtUrl;
  final String spotifyUrl;
  final String? previewAudioUrl;
  final bool isPlaying;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'albumArtUrl': albumArtUrl,
        'spotifyUrl': spotifyUrl,
        'previewAudioUrl': previewAudioUrl,
        'isPlaying': isPlaying,
      };

  factory SpotifyTrack.fromMap(Map<String, dynamic> map) => SpotifyTrack(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        artist: map['artist'] as String? ?? '',
        albumArtUrl: map['albumArtUrl'] as String?,
        spotifyUrl: map['spotifyUrl'] as String? ?? '',
        previewAudioUrl: map['previewAudioUrl'] as String?,
        isPlaying: map['isPlaying'] as bool? ?? false,
      );
}

/// SpotifyService provides real-time currently-playing sync via Spotify Web API OAuth,
/// native Android Spotify broadcast listening, track searching, and curated travel vibes.
class SpotifyService {
  SpotifyService({http.Client? client}) : _client = client ?? http.Client() {
    _initNativeListener();
  }
  static SpotifyService instance = SpotifyService();

  final http.Client _client;

  static const MethodChannel _nativeChannel =
      MethodChannel('com.localquest.app/spotify_receiver');

  final _trackChangeController = StreamController<SpotifyTrack>.broadcast();
  Stream<SpotifyTrack> get onTrackChanged => _trackChangeController.stream;

  SpotifyTrack? _latestTrack;
  SpotifyTrack? get latestTrack => _latestTrack;

  String? _liveSyncUserId;
  bool _isLiveSyncEnabled = false;
  bool get isLiveSyncEnabled => _isLiveSyncEnabled;

  void setLiveSync(String? userId, bool enabled) {
    _liveSyncUserId = userId;
    _isLiveSyncEnabled = enabled;
  }

  void _initNativeListener() {
    if (kIsWeb || !Platform.isAndroid) return;
    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPlaybackChanged') {
        try {
          final data = Map<dynamic, dynamic>.from(call.arguments as Map? ?? {});
          final track = data['track'] as String? ?? '';
          final artist = data['artist'] as String? ?? '';
          final trackId = data['trackId'] as String? ?? '';
          final playing = data['playing'] as bool? ?? true;

          if (track.isNotEmpty) {
            String spotifyUrl =
                'https://open.spotify.com/search/${Uri.encodeComponent('$artist $track')}';
            if (trackId.startsWith('spotify:track:')) {
              final idOnly = trackId.replaceFirst('spotify:track:', '');
              spotifyUrl = 'https://open.spotify.com/track/$idOnly';
            }

            String? albumArtUrl;
            try {
              final searchResults = await searchTracks('$track $artist');
              if (searchResults.isNotEmpty) {
                albumArtUrl = searchResults.first.albumArtUrl;
                if (!spotifyUrl.contains('/track/')) {
                  spotifyUrl = searchResults.first.spotifyUrl;
                }
              }
            } catch (_) {}

            final newTrack = SpotifyTrack(
              id: trackId.isNotEmpty ? trackId : track.hashCode.toString(),
              title: track,
              artist: artist,
              albumArtUrl: albumArtUrl,
              spotifyUrl: spotifyUrl,
              isPlaying: playing,
            );

            _latestTrack = newTrack;
            _trackChangeController.add(newTrack);

            if (_isLiveSyncEnabled &&
                _liveSyncUserId != null &&
                _liveSyncUserId!.isNotEmpty) {
              await _updateUserLiveNote(_liveSyncUserId!, newTrack);
            }
          }
        } catch (e) {
          debugPrint('Error handling native onPlaybackChanged: $e');
        }
      } else if (call.method == 'onSpotifyAuthCallback') {
        try {
          final uriStr = call.arguments as String?;
          if (uriStr != null && uriStr.isNotEmpty) {
            await _handleAuthCallbackUri(uriStr);
          }
        } catch (e) {
          debugPrint('Error handling native onSpotifyAuthCallback: $e');
        }
      }
    });
  }

  Completer<bool>? _authCompleter;
  String? _authUserId;
  String? _usedRedirectUri;

  Future<void> _handleAuthCallbackUri(String uriStr) async {
    try {
      final uri = Uri.parse(uriStr);
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];
      if (code != null && code.isNotEmpty) {
        final success = await exchangeAuthCode(
          code,
          _authUserId,
          _usedRedirectUri ?? defaultRedirectUri,
        );
        if (_authCompleter != null && !_authCompleter!.isCompleted) {
          _authCompleter!.complete(success);
        }
      } else if (error != null) {
        debugPrint('Spotify OAuth error: $error');
        if (_authCompleter != null && !_authCompleter!.isCompleted) {
          _authCompleter!.complete(false);
        }
      }
    } catch (e) {
      debugPrint('Error handling auth callback URI: $e');
    }
  }

  Future<void> _updateUserLiveNote(String uid, SpotifyTrack track) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc('status');
      final doc = await docRef.get();
      if (doc.exists) {
        final existingData = doc.data() ?? {};
        final existingText = existingData['text'] as String? ?? '';
        await docRef.set({
          'text': existingText,
          'songTitle': track.title,
          'songArtist': track.artist,
          'albumArtUrl': track.albumArtUrl,
          'spotifyUrl': track.spotifyUrl,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error auto-syncing live Spotify note: $e');
    }
  }

  /// Manually check local broadcast and trigger track change if updated
  Future<SpotifyTrack?> checkLocalBroadcast() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final broadcast = await _nativeChannel
          .invokeMethod<Map<dynamic, dynamic>>('getLatestBroadcast');
      if (broadcast != null) {
        final track = broadcast['track'] as String? ?? '';
        final artist = broadcast['artist'] as String? ?? '';
        final trackId = broadcast['trackId'] as String? ?? '';
        final isPlaying = broadcast['playing'] as bool? ?? true;

        if (track.isNotEmpty) {
          if (_latestTrack == null ||
              _latestTrack!.title != track ||
              _latestTrack!.artist != artist) {
            String spotifyUrl =
                'https://open.spotify.com/search/${Uri.encodeComponent('$artist $track')}';
            if (trackId.startsWith('spotify:track:')) {
              final idOnly = trackId.replaceFirst('spotify:track:', '');
              spotifyUrl = 'https://open.spotify.com/track/$idOnly';
            }

            String? albumArtUrl;
            try {
              final searchResults = await searchTracks('$track $artist');
              if (searchResults.isNotEmpty) {
                albumArtUrl = searchResults.first.albumArtUrl;
                if (!spotifyUrl.contains('/track/')) {
                  spotifyUrl = searchResults.first.spotifyUrl;
                }
              }
            } catch (_) {}

            final newTrack = SpotifyTrack(
              id: trackId.isNotEmpty ? trackId : track.hashCode.toString(),
              title: track,
              artist: artist,
              albumArtUrl: albumArtUrl,
              spotifyUrl: spotifyUrl,
              isPlaying: isPlaying,
            );

            _latestTrack = newTrack;
            _trackChangeController.add(newTrack);

            if (_isLiveSyncEnabled &&
                _liveSyncUserId != null &&
                _liveSyncUserId!.isNotEmpty) {
              await _updateUserLiveNote(_liveSyncUserId!, newTrack);
            }

            return newTrack;
          }
          return _latestTrack;
        }
      }
    } catch (_) {}
    return null;
  }

  // Registered Spotify Developer App credentials
  static const String clientId = 'f7ebb503ee4d4265b1dee2884042a53e';
  static const String clientSecret = '7b7545ff84f6411d90249147671fd6e8';
  static const String appRedirectUri = 'localquest://callback';
  static const String loopbackRedirectUri = 'http://127.0.0.1:8888/callback';

  static String get defaultRedirectUri =>
      (!kIsWeb && Platform.isAndroid) ? appRedirectUri : loopbackRedirectUri;
  static String get redirectUri => defaultRedirectUri;

  static const String _prefAccessToken = 'spotify_user_access_token';
  static const String _prefRefreshToken = 'spotify_user_refresh_token';
  static const String _prefExpiresAt = 'spotify_user_expires_at';
  static const String _prefConnectedUserId = 'spotify_connected_user_id';

  Future<List<SpotifyTrack>> Function(String query)? mockSearchTracks;
  Future<SpotifyTrack?> Function()? mockFetchCurrentlyPlaying;
  Future<bool> Function()? mockAuthenticateWithSpotify;

  /// Check if the user has an active authenticated Spotify session
  Future<bool> isUserConnected([String? userId]) async {
    return isSpotifyLinked(userId);
  }

  /// Disconnect Spotify account, clear stored tokens, active track and broadcast
  Future<void> disconnectUser([String? userId]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefAccessToken);
    await prefs.remove(_prefRefreshToken);
    await prefs.remove(_prefExpiresAt);
    await prefs.remove(_prefConnectedUserId);
    if (userId != null && userId.isNotEmpty) {
      await prefs.remove('${_prefAccessToken}_$userId');
    }
    _latestTrack = null;
    setLiveSync(null, false);
    if (userId != null && userId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notes')
            .doc('status')
            .delete();
      } catch (e) {
        debugPrint('Error clearing Firestore note on disconnect: $e');
      }
    }
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod('clearBroadcast');
      } catch (_) {}
    }
  }

  /// Check whether a Spotify user account is currently linked
  Future<bool> isSpotifyLinked([String? userId]) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_prefAccessToken);
    if (token == null || token.isEmpty) return false;
    if (userId != null && userId.isNotEmpty) {
      final connectedUid = prefs.getString(_prefConnectedUserId);
      if (connectedUid != null && connectedUid != userId) {
        return false;
      }
      if (connectedUid == null) {
        return false;
      }
    }
    return true;
  }

  /// Retrieve a valid user access token, automatically refreshing if expired
  Future<String?> getValidUserAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_prefAccessToken);
    final refreshToken = prefs.getString(_prefRefreshToken);
    final expiresAt = prefs.getInt(_prefExpiresAt) ?? 0;

    if (token == null || token.isEmpty) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    // If token is still valid for > 60 seconds, use it
    if (expiresAt > now + 60000) {
      return token;
    }

    // Refresh token if expired
    if (refreshToken != null && refreshToken.isNotEmpty) {
      final refreshed = await _refreshAccessToken(refreshToken);
      if (refreshed != null) return refreshed;
    }

    return token;
  }

  /// Refresh expired user access token
  Future<String?> _refreshAccessToken(String refreshToken) async {
    try {
      final authHeader = base64Encode(utf8.encode('$clientId:$clientSecret'));
      final uri = Uri.parse('https://accounts.spotify.com/api/token');
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Basic $authHeader',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newToken = data['access_token'] as String?;
        final expiresIn = data['expires_in'] as int? ?? 3600;
        final newExpiresAt = DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);

        if (newToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefAccessToken, newToken);
          await prefs.setInt(_prefExpiresAt, newExpiresAt);
          if (data['refresh_token'] != null) {
            await prefs.setString(_prefRefreshToken, data['refresh_token'] as String);
          }
          return newToken;
        }
      }
    } catch (e) {
      debugPrint('Error refreshing Spotify token: $e');
    }
    return null;
  }

  /// Exchange authorization code from Spotify OAuth redirect for access & refresh tokens
  Future<bool> exchangeAuthCode(
    String code, [
    String? userId,
    String? customRedirectUri,
  ]) async {
    try {
      final cleanCode = code.trim();
      final targetRedirect = customRedirectUri ?? defaultRedirectUri;
      final authHeader = base64Encode(utf8.encode('$clientId:$clientSecret'));
      final uri = Uri.parse('https://accounts.spotify.com/api/token');
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Basic $authHeader',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': cleanCode,
          'redirect_uri': targetRedirect,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;
        final expiresIn = data['expires_in'] as int? ?? 3600;
        final expiresAt =
            DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);

        if (accessToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefAccessToken, accessToken);
          if (refreshToken != null) {
            await prefs.setString(_prefRefreshToken, refreshToken);
          }
          await prefs.setInt(_prefExpiresAt, expiresAt);
          if (userId != null && userId.isNotEmpty) {
            await prefs.setString(_prefConnectedUserId, userId);
          }
          return true;
        }
      } else {
        debugPrint(
            'Token exchange failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error exchanging Spotify auth code: $e');
    }
    return false;
  }

  /// Save direct Spotify access token (manual developer connect or test token)
  Future<void> saveManualAccessToken(String token, [String? userId]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefAccessToken, token.trim());
    await prefs.setInt(_prefExpiresAt,
        DateTime.now().millisecondsSinceEpoch + (3600 * 1000));
    if (userId != null && userId.isNotEmpty) {
      await prefs.setString(_prefConnectedUserId, userId);
    }
  }

  String? lastPlaybackStatus;

  /// Connect user with Spotify OAuth using deep link on Android, with local loopback listener fallback
  Future<bool> authenticateWithSpotify([String? userId]) async {
    if (mockAuthenticateWithSpotify != null) {
      return mockAuthenticateWithSpotify!();
    }

    // If already linked, avoid launching the browser unnecessarily
    if (await isSpotifyLinked(userId)) {
      return true;
    }

    _authUserId = userId;
    _usedRedirectUri = defaultRedirectUri;
    final completer = Completer<bool>();
    _authCompleter = completer;

    HttpServer? server;
    StreamSubscription<HttpRequest>? sub;

    // Check if initial deep link callback is already pending on Android
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final pendingUri =
            await _nativeChannel.invokeMethod<String>('getInitialAuthCallback');
        if (pendingUri != null && pendingUri.isNotEmpty) {
          await _handleAuthCallbackUri(pendingUri);
          if (completer.isCompleted) {
            return await completer.future;
          }
        }
      } catch (_) {}
    }

    // Also start loopback HTTP server as a listener/fallback
    try {
      server =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 8888, shared: true);
      sub = server.listen((HttpRequest request) async {
        if (request.uri.path == '/favicon.ico') {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        final code = request.uri.queryParameters['code'];
        final error = request.uri.queryParameters['error'];

        request.response.headers.contentType = ContentType.html;
        if (code != null) {
          request.response.write('''
            <!DOCTYPE html>
            <html>
            <head><meta charset="utf-8"><title>Connected</title>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
              body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; text-align: center; padding: 48px 20px; background: #121212; color: #fff; }
              .card { max-width: 380px; margin: 0 auto; background: #1e1e1e; padding: 32px 24px; border-radius: 20px; box-shadow: 0 12px 32px rgba(0,0,0,0.6); }
              .icon { font-size: 52px; margin-bottom: 16px; color: #1DB954; }
              h2 { margin: 0 0 10px; color: #1DB954; font-size: 22px; }
              p { color: #b3b3b3; font-size: 14px; line-height: 1.5; margin: 0; }
              .btn { display: inline-block; margin-top: 20px; padding: 12px 24px; background: #1DB954; color: #fff; text-decoration: none; border-radius: 12px; font-weight: 700; font-size: 14px; }
            </style>
            </head>
            <body>
              <div class="card">
                <div class="icon">✓</div>
                <h2>Spotify Connected!</h2>
                <p>You can now switch back to LocalQuest. Your currently playing music will sync automatically.</p>
                <a class="btn" href="javascript:window.close();">Return to LocalQuest</a>
              </div>
              <script>
                setTimeout(function() {
                  window.close();
                }, 2000);
              </script>
            </body>
            </html>
          ''');
          await request.response.close();
          final success =
              await exchangeAuthCode(code, userId, loopbackRedirectUri);
          if (!completer.isCompleted) {
            completer.complete(success);
          }
        } else if (error != null) {
          request.response.write(
              'Spotify connection cancelled or failed: $error');
          await request.response.close();
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        }
      });
    } catch (e) {
      debugPrint('Could not bind loopback server on port 8888: $e');
    }

    final authUri = Uri.parse(
      'https://accounts.spotify.com/authorize?'
      'client_id=$clientId&'
      'response_type=code&'
      'redirect_uri=${Uri.encodeComponent(_usedRedirectUri ?? defaultRedirectUri)}&'
      'scope=${Uri.encodeComponent('user-read-currently-playing user-read-playback-state user-read-recently-played')}',
    );

    await launchUrl(authUri, mode: LaunchMode.externalApplication);

    try {
      return await completer.future.timeout(const Duration(minutes: 2));
    } catch (e) {
      debugPrint('OAuth timeout or cancelled: $e');
      return false;
    } finally {
      await sub?.cancel();
      await server?.close(force: true);
      _authCompleter = null;
    }
  }

  /// Helper to convert Spotify track JSON map to SpotifyTrack model
  SpotifyTrack? _parseTrack(Map<String, dynamic>? item, {bool isPlaying = true}) {
    if (item == null) return null;
    final title = item['name'] as String? ?? '';
    if (title.isEmpty) return null;
    final artistsList = (item['artists'] as List<dynamic>?)
            ?.map((a) => a['name'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .toList() ??
        [];
    final artist = artistsList.join(', ');
    final album = item['album'] as Map<String, dynamic>?;
    final images = album?['images'] as List<dynamic>?;
    final albumArtUrl = (images != null && images.isNotEmpty)
        ? images[0]['url'] as String?
        : null;
    final externalUrls = item['external_urls'] as Map<String, dynamic>?;
    final spotifyUrl = externalUrls?['spotify'] as String? ??
        'https://open.spotify.com/search/${Uri.encodeComponent('$artist $title')}';

    return SpotifyTrack(
      id: item['id'] as String? ?? title.hashCode.toString(),
      title: title,
      artist: artist,
      albumArtUrl: albumArtUrl,
      spotifyUrl: spotifyUrl,
      isPlaying: isPlaying,
    );
  }

  /// Deep link to open the native Spotify App on the phone
  Future<bool> openSpotifyApp() async {
    try {
      final uri = Uri.parse('spotify:');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (_) {}
    try {
      final webUri = Uri.parse('https://open.spotify.com');
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Real-time fetch of user's actively playing song via native Android Spotify broadcast
  /// or Spotify Web API OAuth (with automatic fallback to full player state and recently played tracks).
  Future<SpotifyTrack?> fetchCurrentlyPlaying() async {
    if (mockFetchCurrentlyPlaying != null) {
      return mockFetchCurrentlyPlaying!();
    }

    // 1. Check Native Android Broadcast Receiver (100% Free - Works without Spotify Premium!)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final broadcast = await _nativeChannel
            .invokeMethod<Map<dynamic, dynamic>>('getLatestBroadcast');
        if (broadcast != null) {
          final title = broadcast['track'] as String? ?? '';
          final artist = broadcast['artist'] as String? ?? '';
          final trackId = broadcast['trackId'] as String? ?? '';
          final isPlaying = broadcast['playing'] as bool? ?? true;
          final timestamp = broadcast['timestamp'] as int? ?? 0;

          final now = DateTime.now().millisecondsSinceEpoch;
          // If song was broadcasted within the last 60 minutes or currently playing
          if (title.isNotEmpty && (now - timestamp < 60 * 60 * 1000 || isPlaying)) {
            String spotifyUrl =
                'https://open.spotify.com/search/${Uri.encodeComponent('$artist $title')}';
            if (trackId.startsWith('spotify:track:')) {
              final idOnly = trackId.replaceFirst('spotify:track:', '');
              spotifyUrl = 'https://open.spotify.com/track/$idOnly';
            }

            // Search open catalog for high-resolution album artwork (300x300)
            String? albumArtUrl;
            final searchResults = await searchTracks('$title $artist');
            if (searchResults.isNotEmpty) {
              albumArtUrl = searchResults.first.albumArtUrl;
              if (!spotifyUrl.contains('/track/')) {
                spotifyUrl = searchResults.first.spotifyUrl;
              }
            }

            lastPlaybackStatus = 'Synced real-time song from Spotify!';
            return SpotifyTrack(
              id: trackId.isNotEmpty ? trackId : title.hashCode.toString(),
              title: title,
              artist: artist,
              albumArtUrl: albumArtUrl,
              spotifyUrl: spotifyUrl,
              isPlaying: isPlaying,
            );
          }
        }
      } catch (e) {
        debugPrint('Native Spotify broadcast check: $e');
      }
    }

    // 2. Secondary: Spotify Web API (For Web, iOS, or linked Android accounts)
    final token = await getValidUserAccessToken();
    if (token == null) {
      lastPlaybackStatus =
          'No song detected playing on Spotify. Start a song in Spotify and tap Sync again!';
      return null;
    }

    try {
      // 1. Primary: currently-playing endpoint
      final uri = Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 8));

      // 403: Developer mode restriction or Spotify Premium requirement
      if (response.statusCode == 403) {
        if (response.body.toLowerCase().contains('premium')) {
          lastPlaybackStatus =
              'Spotify Web API requires Spotify Premium for live player sync. Use "Search Song" below to share any song for free!';
        } else {
          lastPlaybackStatus =
              'Spotify Developer Mode: Add your Spotify email under "User Management" in Spotify Developer Dashboard.';
        }
        debugPrint(lastPlaybackStatus);
        return null;
      }

      // 401: Unauthorized (refresh token and retry once)
      if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        final refreshToken = prefs.getString(_prefRefreshToken);
        if (refreshToken != null && refreshToken.isNotEmpty) {
          final newToken = await _refreshAccessToken(refreshToken);
          if (newToken != null) {
            return await fetchCurrentlyPlaying();
          }
        }
      }

      // 200: Successfully returned active track
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final item = data['item'] as Map<String, dynamic>?;
        final track = _parseTrack(item, isPlaying: data['is_playing'] as bool? ?? true);
        if (track != null) {
          lastPlaybackStatus = 'Active track found';
          return track;
        }
      }

      // 2. Secondary fallback: Full Player endpoint (locates active device)
      final playerUri = Uri.parse('https://api.spotify.com/v1/me/player');
      final playerRes = await _client.get(
        playerUri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 6));

      if (playerRes.statusCode == 200 && playerRes.body.isNotEmpty) {
        final data = jsonDecode(playerRes.body) as Map<String, dynamic>;
        final item = data['item'] as Map<String, dynamic>?;
        final track = _parseTrack(item, isPlaying: data['is_playing'] as bool? ?? true);
        if (track != null) {
          lastPlaybackStatus = 'Player track found';
          return track;
        }
      }

      // 3. Tertiary fallback: Recently played track (if playback paused or phone disconnected)
      final recentUri = Uri.parse('https://api.spotify.com/v1/me/player/recently-played?limit=1');
      final recentRes = await _client.get(
        recentUri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 6));

      if (recentRes.statusCode == 200 && recentRes.body.isNotEmpty) {
        final data = jsonDecode(recentRes.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          final firstItem = items[0] as Map<String, dynamic>?;
          final trackItem = firstItem?['track'] as Map<String, dynamic>?;
          final track = _parseTrack(trackItem, isPlaying: true);
          if (track != null) {
            lastPlaybackStatus = 'Recently played track synced';
            return track;
          }
        }
      }

      final anyBody = '${response.body} ${playerRes.body} ${recentRes.body}'.toLowerCase();
      if (response.statusCode == 403 || playerRes.statusCode == 403 || recentRes.statusCode == 403) {
        if (anyBody.contains('premium')) {
          lastPlaybackStatus =
              'Spotify requires Spotify Premium for live player sync. Tap "Search Song" below to share any track for free!';
        } else {
          lastPlaybackStatus =
              'Spotify Developer Mode: Add your Spotify email under "User Management" in Spotify Developer Dashboard.';
        }
        return null;
      }

      if (response.statusCode == 204 || playerRes.statusCode == 204) {
        lastPlaybackStatus =
            'Spotify playback is idle. Open Spotify, tap Next/Pause to sync Spotify Connect, or enable "Device Broadcast Status" in Spotify Settings.';
      } else {
        lastPlaybackStatus = 'No track found (Status: ${response.statusCode}).';
      }
    } catch (e) {
      debugPrint('Error fetching currently playing track: $e');
      lastPlaybackStatus = 'Connection error: $e';
    }
    return null;
  }

  /// Curated quick-select tracks for tourists exploring Penang
  List<SpotifyTrack> getCuratedPenangVibes() {
    return const [
      SpotifyTrack(
        id: 'penang_1',
        title: 'Golden Hour',
        artist: 'JVKE',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/bf/16/be/bf16be0c-54be-9cfc-084e-397394c8e718/196925184852_Cover.jpg/300x300bb.jpg',
        spotifyUrl: 'https://open.spotify.com/search/JVKE%20Golden%20Hour',
      ),
      SpotifyTrack(
        id: 'penang_2',
        title: 'Sunflower',
        artist: 'Post Malone & Swae Lee',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/05/85/74/0585743c-6238-d621-396a-a8c6fb20e980/18UMGIM72688.rgb.jpg/300x300bb.jpg',
        spotifyUrl: 'https://open.spotify.com/search/Post%20Malone%20Sunflower',
      ),
      SpotifyTrack(
        id: 'penang_3',
        title: 'Levitating',
        artist: 'Dua Lipa',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/91/9f/8e/919f8e43-8557-ca1a-514d-65a882cbfa56/190295286101.jpg/300x300bb.jpg',
        spotifyUrl: 'https://open.spotify.com/search/Dua%20Lipa%20Levitating',
      ),
      SpotifyTrack(
        id: 'penang_4',
        title: 'Viva La Vida',
        artist: 'Coldplay',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/85/87/15/8587151e-dca2-b0a3-d0ea-127e997f7481/5099921211459.jpg/300x300bb.jpg',
        spotifyUrl: 'https://open.spotify.com/search/Coldplay%20Viva%20La%20Vida',
      ),
      SpotifyTrack(
        id: 'penang_5',
        title: 'Here Comes the Sun',
        artist: 'The Beatles',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/06/f0/a6/06f0a6d5-455b-c290-7d35-f09c25f4838a/00602567713470.rgb.jpg/300x300bb.jpg',
        spotifyUrl: 'https://open.spotify.com/search/The%20Beatles%20Here%20Comes%20the%20Sun',
      ),
      SpotifyTrack(
        id: 'penang_6',
        title: 'Midnight City',
        artist: 'M83',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/58/01/f9/5801f9b3-ec84-93ec-dbd0-37747e4526d7/3700551722891_cover.jpg/300x300bb.jpg',
        spotifyUrl: 'https://open.spotify.com/search/M83%20Midnight%20City',
      ),
    ];
  }

  /// Search for music tracks with high-res album covers and Spotify deep links
  Future<List<SpotifyTrack>> searchTracks(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return getCuratedPenangVibes();
    if (mockSearchTracks != null) return mockSearchTracks!(cleanQuery);

    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(cleanQuery)}&entity=song&limit=15',
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];

        final tracks = <SpotifyTrack>[];
        for (final item in results) {
          if (item is! Map<String, dynamic>) continue;
          final title = item['trackName'] as String? ?? '';
          final artist = item['artistName'] as String? ?? '';
          if (title.isEmpty || artist.isEmpty) continue;

          final rawArt = item['artworkUrl100'] as String?;
          final art = rawArt?.replaceAll('100x100bb', '300x300bb');
          final spotifySearch =
              'https://open.spotify.com/search/${Uri.encodeComponent('$artist $title')}';

          tracks.add(
            SpotifyTrack(
              id: (item['trackId'] ?? title.hashCode).toString(),
              title: title,
              artist: artist,
              albumArtUrl: art,
              spotifyUrl: spotifySearch,
              previewAudioUrl: item['previewUrl'] as String?,
            ),
          );
        }

        if (tracks.isNotEmpty) return tracks;
      }
    } catch (e) {
      debugPrint('Error searching tracks: $e');
    }

    return getCuratedPenangVibes()
        .where((t) =>
            t.title.toLowerCase().contains(cleanQuery.toLowerCase()) ||
            t.artist.toLowerCase().contains(cleanQuery.toLowerCase()))
        .toList();
  }

  /// Open track in the native Spotify app or Spotify web player
  Future<bool> launchSpotify(String? spotifyUrl) async {
    final targetUrl = (spotifyUrl != null && spotifyUrl.isNotEmpty)
        ? spotifyUrl
        : 'https://open.spotify.com';

    final uri = Uri.parse(targetUrl);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch Spotify: $e');
      try {
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        return false;
      }
    }
  }
}
