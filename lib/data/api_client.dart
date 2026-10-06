import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart';
import 'local_store.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, [this.message]);

  final int statusCode;

  /// Backend error code, e.g. `invite_not_found`, or `network_error`.
  final String code;
  final String? message;

  bool get isUnauthorized => statusCode == 401;

  /// Indonesian message suitable for showing to the user.
  String get userMessage => switch (code) {
        'invite_not_found' => 'Kode undangan tidak ditemukan atau sudah kedaluwarsa.',
        'own_invite' => 'Itu kode undanganmu sendiri. Kirim kode ini ke pasanganmu.',
        'already_paired' => 'Akun ini sudah terhubung dengan pasangan.',
        'not_paired' => 'Kamu belum terhubung dengan pasangan.',
        'invalid_google_token' => 'Login Google gagal diverifikasi server.',
        'network_error' => 'Tidak bisa terhubung ke server. Periksa koneksi internet.',
        'too_many_requests' => 'Terlalu banyak permintaan, coba lagi sebentar.',
        _ => message ?? 'Terjadi kesalahan ($statusCode).',
      };

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}

class ApiClient {
  ApiClient({this._store = const LocalStore(), http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final LocalStore _store;
  final http.Client _http;

  static const _timeout = Duration(seconds: 20);

  Future<dynamic> _send(String method, String path, {Object? body, bool auth = true}) async {
    final headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (auth) {
      final token = await _store.readToken();
      if (token == null) throw const ApiException(401, 'unauthorized');
      headers['Authorization'] = 'Bearer $token';
    }

    final request = http.Request(method, Uri.parse('${AppConfig.apiBaseUrl}$path'))
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      // The timeout covers the whole exchange, including reading the body.
      response = await _http.send(request).then(http.Response.fromStream).timeout(_timeout);
    } on Exception catch (e) {
      debugPrint('API $method $path failed: $e');
      throw ApiException(0, 'network_error', e.toString());
    }
    if (response.statusCode >= 400) debugPrint('API $method $path -> ${response.statusCode} ${response.body}');

    final decoded = response.body.isEmpty ? null : _tryDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    final err = decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
    throw ApiException(
      response.statusCode,
      err['error'] as String? ?? 'http_${response.statusCode}',
      err['message'] as String?,
    );
  }

  static Object? _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  /// Exchanges a Google ID token for our JWT and stores it.
  Future<AppUser> signInWithGoogle(String idToken) async {
    final json = await _send('POST', '/auth/google', body: {'idToken': idToken}, auth: false)
        as Map<String, dynamic>;
    await _store.writeToken(json['token'] as String);
    return AppUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<Session> me() async => Session.fromMeJson(await _send('GET', '/me') as Map<String, dynamic>);

  Future<Invite> createInvite() async =>
      Invite.fromJson(await _send('POST', '/invites') as Map<String, dynamic>);

  /// Returns the `{ couple, partner, partnerStatus }` payload.
  Future<Map<String, dynamic>> acceptInvite(String code) async =>
      await _send('POST', '/invites/accept', body: {'code': code.trim().toUpperCase()})
          as Map<String, dynamic>;

  Future<void> unpair() => _send('DELETE', '/couple');

  Future<void> putStatus(DeviceStatus status) => _send('PUT', '/status', body: status.toUploadJson());

  /// Returns the Pusher auth payload (`{ "auth": "key:signature" }`).
  Future<Map<String, dynamic>> pusherAuth({required String socketId, required String channelName}) async =>
      await _send('POST', '/pusher/auth', body: {'socket_id': socketId, 'channel_name': channelName})
          as Map<String, dynamic>;
}
