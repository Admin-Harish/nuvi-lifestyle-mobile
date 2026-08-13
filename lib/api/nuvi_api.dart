/// The API surface the app talks to.
///
/// [NuviApi] is an interface so widget tests can drive the screens against a
/// fake without a socket. [HttpNuviApi] is the real implementation, built on
/// `dart:io`'s HttpClient so no package dependency is added for it.
///
/// One deliberate omission: there is no method that takes a role or a
/// capability. The client cannot ask to be treated as a clinician, because
/// there is no call that would carry the claim.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'models.dart';

/// Anything the API refused, with the message it gave.
///
/// The auth screens deliberately do **not** show [detail] for credential
/// failures — the server returns one generic message for every such failure,
/// and rendering per-field errors would reintroduce, in the UI, the account
/// enumeration the API was careful to avoid.
class ApiException implements Exception {
  ApiException(this.statusCode, this.detail);

  final int statusCode;
  final String detail;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isThrottled => statusCode == 429;

  @override
  String toString() => 'ApiException($statusCode): $detail';
}

abstract class NuviApi {
  /// Create an account. Succeeds identically whether or not the address was
  /// already taken — the server will not say, and neither will this.
  Future<void> register({
    required String email,
    required String password,
    String fullName,
  });

  Future<void> verifyEmail({required String email, required String code});

  Future<AuthTokens> login({required String email, required String password});

  /// Always completes. The server does not report whether the address exists.
  Future<void> requestPasswordReset({required String email});

  Future<CurrentUser> currentUser();

  Future<List<GoalCatalogueEntry>> goalCatalogue();

  Future<List<ConsentSummaryEntry>> consentSummary();

  Future<void> recordConsent({
    required String purpose,
    required String decision,
  });
}

class HttpNuviApi implements NuviApi {
  HttpNuviApi({required this.config, HttpClient? client})
    : _client = client ?? HttpClient() {
    _client.connectionTimeout = config.apiTimeout;
  }

  final AppConfig config;
  final HttpClient _client;

  String? _accessToken;

  /// Set after a successful login. In memory only.
  @visibleForTesting
  set accessToken(String? value) => _accessToken = value;

  @override
  Future<void> register({
    required String email,
    required String password,
    String fullName = '',
  }) async {
    await _send(
      'POST',
      'auth/register/',
      body: {'email': email, 'password': password, 'full_name': fullName},
    );
  }

  @override
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    await _send(
      'POST',
      'auth/verify-email/',
      body: {'email': email, 'code': code},
    );
  }

  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final payload = await _send(
      'POST',
      'auth/login/',
      body: {'email': email, 'password': password},
    );
    final tokens = AuthTokens.fromJson(payload as Map<String, dynamic>);
    _accessToken = tokens.access;
    return tokens;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _send('POST', 'auth/password-reset/', body: {'email': email});
  }

  @override
  Future<CurrentUser> currentUser() async {
    final payload = await _send('GET', 'accounts/me/');
    return CurrentUser.fromJson(payload as Map<String, dynamic>);
  }

  @override
  Future<List<GoalCatalogueEntry>> goalCatalogue() async {
    final payload = await _send('GET', 'goal-catalogue/');
    final rows = (payload as Map<String, dynamic>)['goals'] as List<dynamic>;
    return rows
        .map((row) => GoalCatalogueEntry.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<ConsentSummaryEntry>> consentSummary() async {
    final payload = await _send('GET', 'consent/');
    final rows = (payload as Map<String, dynamic>)['consents'] as List<dynamic>;
    return rows
        .map((row) => ConsentSummaryEntry.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<void> recordConsent({
    required String purpose,
    required String decision,
  }) async {
    await _send(
      'POST',
      'consent/',
      body: {'purpose': purpose, 'decision': decision},
    );
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final request = await _client.openUrl(method, config.apiUri(path));
    request.headers.contentType = ContentType.json;
    if (_accessToken != null) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $_accessToken',
      );
    }
    if (body != null) {
      request.write(jsonEncode(body));
    }

    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    final decoded = text.isEmpty ? null : jsonDecode(text);

    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, _detailFrom(decoded));
    }
    return decoded;
  }

  String _detailFrom(Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String) return detail;
    }
    return 'Something went wrong. Please try again.';
  }
}
