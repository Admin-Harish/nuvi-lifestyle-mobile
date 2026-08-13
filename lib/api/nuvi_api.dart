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

  /// The menu library for one goal. Read-only.
  ///
  /// A gated goal returns an empty library with a reason — the server decides
  /// that, and the app renders the decision rather than inferring it from a
  /// flag it should not be able to see.
  Future<MenuLibrary> menuLibrary({required String goalKey});

  Future<List<MealPlanSummary>> mealPlans();

  Future<MealPlanDetail> mealPlan({required String id});

  // --- Phase 3: tracking ---

  /// One member's reconciled day: target, consumed, remaining, hydration.
  Future<DailySummary> dailySummary({
    required String memberId,
    required String date,
  });

  /// A household's day as per-member totals.
  ///
  /// The server sends totals only — no dish names, no labels. The app cannot
  /// show one member's food on this screen because it is never sent it.
  Future<HouseholdDailySummary> householdDailySummary({
    required String householdId,
    required String date,
  });

  /// Log something. [idempotencyKey] is required rather than optional: a retry
  /// without one silently creates a second meal, and a caller that has to pass
  /// the argument has to think about it.
  Future<IntakeEvent> logIntake({
    required String memberId,
    required String eventType,
    required String occurredAt,
    required String idempotencyKey,
    String label,
    String? planItemId,
    String? portionFraction,
    Map<String, String>? macros,
    int waterMl,
  });

  /// Set the day's water target. The consumed total is the server's to compute
  /// from the logged events; there is no call that sets it directly.
  Future<void> setWaterTarget({
    required String memberId,
    required String date,
    required int targetMl,
  });

  /// The member profiles this account may see. Already scoped server-side, so
  /// the list is the answer rather than something to filter.
  Future<List<MembershipRef>> memberships();
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

  @override
  Future<MenuLibrary> menuLibrary({required String goalKey}) async {
    // Two calls: the summary carries *why* a library is empty, which the list
    // alone cannot express — an empty page and a gated goal look identical
    // otherwise, and they are not the same thing to tell somebody.
    final summary =
        await _send('GET', 'menu-library/summary/?goal=$goalKey')
            as Map<String, dynamic>;
    final listing =
        await _send('GET', 'menu-library/?goal=$goalKey')
            as Map<String, dynamic>;

    final rows = listing['results'] as List<dynamic>? ?? const [];
    final reason = switch (summary['empty_because'] as String?) {
      'flag_off' => MenuLibraryEmptyReason.flagOff,
      'not_generated' => MenuLibraryEmptyReason.notGenerated,
      _ => MenuLibraryEmptyReason.none,
    };

    return MenuLibrary(
      goalKey: goalKey,
      days: rows
          .map((row) => MenuDay.fromJson(row as Map<String, dynamic>))
          .toList(growable: false),
      emptyReason: reason,
      isGated: summary['is_gated'] as bool? ?? false,
    );
  }

  @override
  Future<List<MealPlanSummary>> mealPlans() async {
    final payload = await _send('GET', 'meal-plans/') as Map<String, dynamic>;
    final rows = payload['results'] as List<dynamic>? ?? const [];
    return rows
        .map((row) => MealPlanSummary.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<MealPlanDetail> mealPlan({required String id}) async {
    final payload = await _send('GET', 'meal-plans/$id/');
    return MealPlanDetail.fromJson(payload as Map<String, dynamic>);
  }

  @override
  Future<DailySummary> dailySummary({
    required String memberId,
    required String date,
  }) async {
    final payload = await _send(
      'GET',
      'daily-summary/?member=$memberId&date=$date',
    );
    return DailySummary.fromJson(payload as Map<String, dynamic>);
  }

  @override
  Future<HouseholdDailySummary> householdDailySummary({
    required String householdId,
    required String date,
  }) async {
    final payload = await _send(
      'GET',
      'household-daily-summary/?household=$householdId&date=$date',
    );
    return HouseholdDailySummary.fromJson(payload as Map<String, dynamic>);
  }

  @override
  Future<IntakeEvent> logIntake({
    required String memberId,
    required String eventType,
    required String occurredAt,
    required String idempotencyKey,
    String label = '',
    String? planItemId,
    String? portionFraction,
    Map<String, String>? macros,
    int waterMl = 0,
  }) async {
    final payload = await _send(
      'POST',
      'intake-events/',
      body: {
        'member': memberId,
        'event_type': eventType,
        'occurred_at': occurredAt,
        'idempotency_key': idempotencyKey,
        if (label.isNotEmpty) 'label': label,
        'plan_item': ?planItemId,
        'portion_fraction': ?portionFraction,
        'macros': ?macros,
        if (waterMl > 0) 'water_ml': waterMl,
      },
    );
    return IntakeEvent.fromJson(payload as Map<String, dynamic>);
  }

  @override
  Future<void> setWaterTarget({
    required String memberId,
    required String date,
    required int targetMl,
  }) async {
    await _send(
      'POST',
      'hydration/set-target/',
      body: {'member': memberId, 'local_date': date, 'target_ml': targetMl},
    );
  }

  @override
  Future<List<MembershipRef>> memberships() async {
    final payload = await _send('GET', 'members/');
    // The endpoint is unpaginated today and paginated tomorrow; accept both
    // rather than break on the day somebody adds a pagination class.
    final rows = payload is Map<String, dynamic>
        ? (payload['results'] as List<dynamic>? ?? const [])
        : (payload as List<dynamic>? ?? const []);
    return rows
        .map((row) => MembershipRef.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
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
