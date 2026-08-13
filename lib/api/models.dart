/// Wire models for the Phase 1 API.
///
/// These mirror the server's serializers, and mirror their *restraint* too:
/// nothing here can carry a role or a capability the client then acts on as
/// authority. [CurrentUser.capabilities] exists so the UI can hide controls the
/// server would refuse anyway — it is a convenience, never a permission. Every
/// one of those actions is still checked server-side, and a tampered client
/// gains nothing by lying to itself.
library;

import 'package:flutter/foundation.dart';

/// A JWT pair. Held in memory only for now: secure storage is a later phase,
/// and writing tokens to disk without it would be worse than not persisting.
@immutable
class AuthTokens {
  const AuthTokens({required this.access, required this.refresh});

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    access: json['access'] as String? ?? '',
    refresh: json['refresh'] as String? ?? '',
  );

  final String access;
  final String refresh;

  bool get isEmpty => access.isEmpty;
}

@immutable
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isEmailVerified,
    required this.roles,
    required this.capabilities,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
    id: json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    isEmailVerified: json['is_email_verified'] as bool? ?? false,
    roles: List<String>.from(json['roles'] as List<dynamic>? ?? const []),
    capabilities: List<String>.from(
      json['capabilities'] as List<dynamic>? ?? const [],
    ),
  );

  final String id;
  final String email;
  final String fullName;
  final bool isEmailVerified;
  final List<String> roles;
  final List<String> capabilities;

  /// Whether to *show* a control. Never whether to allow the action.
  bool holds(String capability) => capabilities.contains(capability);
}

/// One goal from the catalogue, with the server's availability decision.
///
/// [available] is the server's answer, not a client-side reading of a flag.
/// The app never decides whether a clinical goal may be used; it renders what
/// it was told.
@immutable
class GoalCatalogueEntry {
  const GoalCatalogueEntry({
    required this.key,
    required this.label,
    required this.category,
    required this.available,
    required this.statusIfSelected,
    required this.reason,
    required this.explanation,
  });

  factory GoalCatalogueEntry.fromJson(Map<String, dynamic> json) =>
      GoalCatalogueEntry(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        category: json['category'] as String? ?? '',
        available: json['available'] as bool? ?? false,
        statusIfSelected: json['status_if_selected'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        explanation: json['explanation'] as String? ?? '',
      );

  final String key;
  final String label;
  final String category;
  final bool available;
  final String statusIfSelected;
  final String reason;
  final String explanation;

  bool get awaitsClinicalReview =>
      statusIfSelected == 'clinical_review_required';
}

/// Where the signed-in account stands on one consent purpose.
@immutable
class ConsentSummaryEntry {
  const ConsentSummaryEntry({
    required this.purpose,
    required this.granted,
    required this.decision,
    required this.documentVersion,
    required this.documentStatus,
    required this.isPresentable,
    required this.withdrawable,
  });

  factory ConsentSummaryEntry.fromJson(Map<String, dynamic> json) =>
      ConsentSummaryEntry(
        purpose: json['purpose'] as String? ?? '',
        granted: json['granted'] as bool? ?? false,
        decision: json['decision'] as String?,
        documentVersion: json['document_version'] as int?,
        documentStatus: json['document_status'] as String? ?? '',
        isPresentable: json['is_presentable'] as bool? ?? false,
        withdrawable: json['withdrawable'] as bool? ?? true,
      );

  final String purpose;
  final bool granted;
  final String? decision;
  final int? documentVersion;
  final String documentStatus;

  /// False while the wording is a draft awaiting legal sign-off. The screen
  /// must label the text rather than presenting it as final.
  final bool isPresentable;

  /// False for consent that cannot be withdrawn without closing the account.
  final bool withdrawable;

  /// Human-readable purpose name. Kept here rather than in the widget so the
  /// same wording is used everywhere the purpose is shown.
  String get label => switch (purpose) {
    'data_processing' => 'Processing my data',
    'communications' => 'Product updates and messages',
    'teleconsultation' => 'Consulting a professional',
    'caregiver_sharing' => 'Sharing with my household',
    'health_data' => 'Processing my health data',
    _ => purpose,
  };
}
