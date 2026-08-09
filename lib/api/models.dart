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

/// ---------------------------------------------------------------------------
/// Phase 2 — menus and plans
/// ---------------------------------------------------------------------------
///
/// Macros arrive as **strings**, and are kept as strings all the way to the
/// screen. The server sends them that way on purpose: they are exact decimals,
/// and parsing them into a Dart `double` would reintroduce the binary rounding
/// the server went to some trouble to avoid. The app displays nutrition; it
/// does not recompute it.

@immutable
class Macros {
  const Macros({
    required this.energyKcal,
    required this.proteinG,
    required this.carbohydrateG,
    required this.fatG,
    required this.fibreG,
  });

  factory Macros.fromJson(Map<String, dynamic> json) => Macros(
    energyKcal: json['energy_kcal'] as String? ?? '0',
    proteinG: json['protein_g'] as String? ?? '0',
    carbohydrateG: json['carbohydrate_g'] as String? ?? '0',
    fatG: json['fat_g'] as String? ?? '0',
    fibreG: json['fibre_g'] as String? ?? '0',
  );

  final String energyKcal;
  final String proteinG;
  final String carbohydrateG;
  final String fatG;
  final String fibreG;

  /// "412 kcal · P 22.4 g · C 58.1 g · F 9.2 g"
  String get summary =>
      '$energyKcal kcal · P $proteinG g · C $carbohydrateG g · F $fatG g';
}

@immutable
class MenuDish {
  const MenuDish({
    required this.slot,
    required this.dishName,
    required this.servingGrams,
    required this.macros,
    required this.allergenTags,
  });

  factory MenuDish.fromJson(Map<String, dynamic> json) => MenuDish(
    slot: json['slot'] as String? ?? '',
    dishName: json['dish_name'] as String? ?? '',
    servingGrams: json['serving_grams'] as String? ?? '0',
    macros: Macros.fromJson(
      (json['macros'] as Map<String, dynamic>?) ?? const {},
    ),
    allergenTags: List<String>.from(
      json['allergen_tags'] as List<dynamic>? ?? const [],
    ),
  );

  final String slot;
  final String dishName;
  final String servingGrams;
  final Macros macros;
  final List<String> allergenTags;

  /// "Breakfast", "Mid morning" — the server's slot key, made readable.
  String get slotLabel {
    if (slot.isEmpty) return '';
    final words = slot.split('_');
    final first = words.first;
    return [
      first[0].toUpperCase() + first.substring(1),
      ...words.skip(1),
    ].join(' ');
  }
}

@immutable
class MenuDay {
  const MenuDay({
    required this.dayIndex,
    required this.goalKey,
    required this.macros,
    required this.allergenTags,
    required this.dishes,
  });

  factory MenuDay.fromJson(Map<String, dynamic> json) => MenuDay(
    dayIndex: json['day_index'] as int? ?? 0,
    goalKey: json['goal_key'] as String? ?? '',
    macros: Macros.fromJson(
      (json['macros'] as Map<String, dynamic>?) ?? const {},
    ),
    allergenTags: List<String>.from(
      json['allergen_tags'] as List<dynamic>? ?? const [],
    ),
    dishes: (json['items'] as List<dynamic>? ?? const [])
        .map((item) => MenuDish.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  final int dayIndex;
  final String goalKey;
  final Macros macros;
  final List<String> allergenTags;
  final List<MenuDish> dishes;
}

/// Why a library came back empty.
///
/// The server distinguishes "generated but behind a flag" from "not generated",
/// and so does the app: telling somebody their condition is awaiting clinical
/// review is honest, and telling them the same thing when nothing exists yet
/// would not be.
enum MenuLibraryEmptyReason { none, flagOff, notGenerated }

@immutable
class MenuLibrary {
  const MenuLibrary({
    required this.goalKey,
    required this.days,
    required this.emptyReason,
    required this.isGated,
  });

  final String goalKey;
  final List<MenuDay> days;
  final MenuLibraryEmptyReason emptyReason;
  final bool isGated;

  bool get isEmpty => days.isEmpty;
}

@immutable
class MealPlanSummary {
  const MealPlanSummary({
    required this.id,
    required this.reference,
    required this.goalKey,
    required this.status,
    required this.startsOn,
    required this.endsOn,
  });

  factory MealPlanSummary.fromJson(Map<String, dynamic> json) =>
      MealPlanSummary(
        id: json['id'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        goalKey: json['goal_key'] as String? ?? '',
        status: json['status'] as String? ?? '',
        startsOn: json['starts_on'] as String? ?? '',
        endsOn: json['ends_on'] as String? ?? '',
      );

  final String id;
  final String reference;
  final String goalKey;
  final String status;
  final String startsOn;
  final String endsOn;
}

@immutable
class MealPlanDetail {
  const MealPlanDetail({
    required this.summary,
    required this.macros,
    required this.excludedAllergenTags,
    required this.days,
  });

  factory MealPlanDetail.fromJson(Map<String, dynamic> json) => MealPlanDetail(
    summary: MealPlanSummary.fromJson(json),
    macros: Macros.fromJson(
      (json['macros'] as Map<String, dynamic>?) ?? const {},
    ),
    excludedAllergenTags: List<String>.from(
      json['excluded_allergen_tags'] as List<dynamic>? ?? const [],
    ),
    days: (json['days'] as List<dynamic>? ?? const [])
        .map((day) => MenuDay.fromJson(day as Map<String, dynamic>))
        .toList(growable: false),
  );

  final MealPlanSummary summary;
  final Macros macros;
  final List<String> excludedAllergenTags;
  final List<MenuDay> days;
}
