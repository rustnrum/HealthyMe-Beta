import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jose/jose.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sign in with ChatGPT open-source public-client PKCE authorization.
/// No shared secrets, API keys, health information, or access tokens are logged.
/// Account data lives in Android encrypted secure storage, not SharedPreferences.
class ChatGptConnectionService {
  const ChatGptConnectionService();
  static const _secure = FlutterSecureStorage();
  static const _key = 'salus_siwc_account_v1';
  static const _host = 'salus_siwc_host_v1';
  static const _issuer = 'https://auth.openai.com';
  static const _resource = 'https://api.openai.com/v1';
  static final _rand = Random.secure();

  static String randomToken([int count = 32]) =>
      base64Url.encode(List<int>.generate(count, (_) => _rand.nextInt(256)))
          .replaceAll('=', '');

  static String pkceChallenge(String verifier) =>
      base64Url.encode(sha256.convert(utf8.encode(verifier)).bytes)
          .replaceAll('=', '');

  Future<Map<String, dynamic>?> account() async {
    final value = await _secure.read(key: _key);
    if (value == null) return null;
    try { return Map<String, dynamic>.from(jsonDecode(value) as Map); }
    catch (_) { return null; }
  }

  Future<void> disconnect() => _secure.delete(key: _key);

  Future<String> _hostId() async {
    final saved = await _secure.read(key: _host);
    if (saved != null && saved.startsWith('urn:uuid:')) return saved;
    final bytes = List<int>.generate(16, (_) => _rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    final id = 'urn:uuid:${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _secure.write(key: _host, value: id);
    return id;
  }

  /// System browser + 127.0.0.1 redirect, per OpenAI OSS client guide.
  /// Every attempt uses one-time state/nonce and a fresh S256 PKCE verifier.
  Future<Map<String, dynamic>> connect() async {
    if (!Platform.isAndroid) throw StateError('Sign in is available on Android.');
    final previous = await account();
    final hostId = await _hostId();
    final verifier = randomToken(64);
    final state = randomToken();
    final nonce = randomToken();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirect = 'http://127.0.0.1:${server.port}/auth/callback';
    final clientId = previous?['client_id']?.toString() ?? 'dynamic_agent_client';
    final params = <String, String>{
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirect,
      'scope': 'openid profile email offline_access resource.invoke chatgpt.tokens.use.direct',
      'resource': _resource,
      'state': state,
      'nonce': nonce,
      'code_challenge_method': 'S256',
      'code_challenge': pkceChallenge(verifier),
      'ext_agent_host_id': hostId,
    };
    if (previous == null) {
      params['agent_name_hint'] = 'Salus';
    } else if ((previous['id_token'] ?? '').toString().isNotEmpty) {
      params['id_token_hint'] = previous['id_token'].toString();
    }
    final endpoint = Uri.parse('$_issuer/api/accounts/authorize')
        .replace(queryParameters: params);
    try {
      final launched = await launchUrl(endpoint, mode: LaunchMode.externalApplication);
      if (!launched) throw StateError('Could not open the ChatGPT sign-in page.');
      final callback = await server.firstWhere(
        (request) => request.uri.path == '/auth/callback',
      ).timeout(const Duration(minutes: 4));
      final values = callback.uri.queryParameters;
      callback.response.headers.contentType = ContentType.html;
      callback.response.write('<html><body style="background:#081319;color:white;'
          'font-family:sans-serif;text-align:center;padding:45px">'
          '<h2>Return to Salus</h2><p>You can close this browser tab.</p></body></html>');
      await callback.response.close();
      if (values['state'] != state) throw StateError('Sign-in state verification failed.');
      if (values['error'] != null) {
        throw StateError('ChatGPT authorization was declined: ${values['error']}');
      }
      final code = values['code'];
      if (code == null || code.isEmpty) throw StateError('No authorization code returned.');
      final issued = values['client_id'] ?? (previous?['client_id']?.toString());
      if (issued == null || !issued.startsWith('oaiapp_')) {
        throw StateError('ChatGPT did not issue an application client ID.');
      }
      if (previous != null && issued != previous['client_id']) {
        throw StateError('The authorized ChatGPT client was not the selected account.');
      }
      final tokens = await _tokenRequest({
        'grant_type': 'authorization_code',
        'client_id': issued,
        'code': code,
        'code_verifier': verifier,
        'redirect_uri': redirect,
        'resource': _resource,
      });
      final idToken = tokens['id_token']?.toString() ?? '';
      final identity = await _verifyIdentity(idToken, issued, nonce);
      if (previous != null && identity['sub'] != previous['sub']) {
        throw StateError('The account does not match the previously connected user.');
      }
      final scopes = tokens['scope']?.toString().split(' ') ?? const <String>[];
      final result = <String, dynamic>{
        'client_id': issued,
        'sub': identity['sub'],
        'email': identity['email'] ?? '',
        'name': identity['name'] ?? '',
        'id_token': idToken,
        'access_token': tokens['access_token'],
        'refresh_token': tokens['refresh_token'],
        'scope': scopes.join(' '),
        'saved_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        'expires_in': tokens['expires_in'] ?? 3600,
      };
      await _secure.write(key: _key, value: jsonEncode(result));
      return result;
    } finally {
      await server.close(force: true);
    }
  }

  static Map<String, dynamic> _decodeJson(String body) {
    final result = jsonDecode(body);
    if (result is! Map) throw const FormatException('Unexpected authorization response.');
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> _tokenRequest(Map<String, String> fields) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.postUrl(Uri.parse('$_issuer/api/accounts/oauth/token'));
      request.headers.contentType = ContentType('application', 'x-www-form-urlencoded');
      request.write(fields.entries.map((e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&'));
      final response = await request.close().timeout(const Duration(seconds: 20));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw StateError('ChatGPT authorization failed (${response.statusCode}). Reconnect your account.');
      }
      return _decodeJson(body);
    } finally { client.close(force: true); }
  }

  /// Trust ID claims only after a verified RS256 signature using OpenAI JWKS.
  Future<Map<String, dynamic>> _verifyIdentity(
      String compact, String clientId, String nonce) async {
    final parts = compact.split('.');
    if (parts.length != 3) throw StateError('Invalid ChatGPT identity token.');
    final header = _decodeJson(utf8.decode(base64Url.decode(base64Url.normalize(parts.first))));
    if (header['alg'] != 'RS256' || (header['kid'] ?? '').toString().isEmpty) {
      throw StateError('Unsupported ChatGPT identity signature.');
    }
    final web = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await web.getUrl(Uri.parse('$_issuer/.well-known/jwks.json'));
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw StateError('ChatGPT signing keys unavailable.');
      final jwks = _decodeJson(await response.transform(utf8.decoder).join());
      final keys = jwks['keys'];
      if (keys is! List) throw StateError('Invalid ChatGPT signing keys.');
      final matching = keys.whereType<Map>().where((j) => j['kid'] == header['kid'] &&
          j['kty'] == 'RSA').toList();
      if (matching.isEmpty) throw StateError('Unknown ChatGPT signing key.');
      final store = JsonWebKeyStore()..addKey(JsonWebKey.fromJson(
          Map<String, dynamic>.from(matching.first)));
      final verified = await JsonWebSignature.fromCompactSerialization(compact).verify(store);
      if (!verified) throw StateError('ChatGPT identity signature verification failed.');
      final claims = _decodeJson(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final aud = claims['aud'];
      if (claims['iss'] != _issuer ||
          !(aud == clientId || (aud is List && aud.contains(clientId))) ||
          claims['nonce'] != nonce ||
          (claims['exp'] is! num) || (claims['exp'] as num).toInt() <= now ||
          (claims['sub'] ?? '').toString().isEmpty) {
        throw StateError('ChatGPT identity claims failed verification.');
      }
      return claims;
    } finally { web.close(force: true); }
  }

  Future<String> accessToken() async {
    var record = await account();
    if (record == null) throw StateError('Connect your ChatGPT account in Salus AI first.');
    final scopes = (record['scope'] ?? '').toString().split(' ');
    if (!scopes.contains('chatgpt.tokens.use.direct')) {
      throw StateError('This account did not authorize ChatGPT plan usage. Reconnect and grant AI access.');
    }
    final saved = record['saved_at'] is num ? (record['saved_at'] as num).toInt() : 0;
    final life = record['expires_in'] is num ? (record['expires_in'] as num).toInt() : 3600;
    final expired = DateTime.now().millisecondsSinceEpoch > saved + (life - 100) * 1000;
    if (expired) {
      final refresh = record['refresh_token']?.toString();
      if (refresh == null || refresh.isEmpty) {
        throw StateError('ChatGPT session expired. Sign in again.');
      }
      final tokens = await _tokenRequest({
        'grant_type': 'refresh_token',
        'client_id': record['client_id'].toString(),
        'refresh_token': refresh,
        'resource': _resource,
      });
      record = {...record,
        'access_token': tokens['access_token'],
        'refresh_token': tokens['refresh_token'] ?? refresh,
        'scope': tokens['scope'] ?? record['scope'],
        'expires_in': tokens['expires_in'] ?? 3600,
        'saved_at': DateTime.now().millisecondsSinceEpoch,
      };
      await _secure.write(key: _key, value: jsonEncode(record));
    }
    final token = record['access_token']?.toString() ?? '';
    if (token.isEmpty) throw StateError('ChatGPT access token unavailable. Sign in again.');
    return token;
  }
}
