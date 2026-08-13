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

/// ---------------------------------------------------------------------------
/// Phase 3 — intake tracking and the daily calorie engine
/// ---------------------------------------------------------------------------
///
/// Macros stay strings here too, and for one more reason on top of the Phase 2
/// one: [DailySummary.remaining] can be **negative**. The server sends the
/// signed figure because going over budget is a fact worth showing, and the app
/// renders the string it was given rather than deciding what to do with a sign.

/// How a planned dish was counted, and why.
///
/// The server decides this; the app renders the decision. There is no client
/// logic that infers "skipped" from an absent event, because the absence of a
/// log is not the same as a statement that a meal was missed.
enum AttributionBasis {
  outstanding,
  eaten,
  partial,
  skipped,
  fasting,
  fastingWindow,
  replaced;

  static AttributionBasis fromJson(String? raw) => switch (raw) {
    'eaten' => AttributionBasis.eaten,
    'partial' => AttributionBasis.partial,
    'skipped' => AttributionBasis.skipped,
    'fasting' => AttributionBasis.fasting,
    'fasting_window' => AttributionBasis.fastingWindow,
    'replaced' => AttributionBasis.replaced,
    _ => AttributionBasis.outstanding,
  };

  /// Short copy for the tracker row. Kept here rather than in the widget so
  /// the same words are used wherever a basis is shown.
  String get label => switch (this) {
    AttributionBasis.outstanding => 'Not logged yet',
    AttributionBasis.eaten => 'Eaten',
    AttributionBasis.partial => 'Partly eaten',
    AttributionBasis.skipped => 'Skipped',
    AttributionBasis.fasting => 'Fasting',
    AttributionBasis.fastingWindow => 'In a fasting window',
    AttributionBasis.replaced => 'Replaced',
  };
}

/// One planned dish on the day, with what the member's events made of it.
@immutable
class PlannedItem {
  const PlannedItem({
    required this.planItemId,
    required this.slot,
    required this.dishName,
    required this.servingGrams,
    required this.plannedMacros,
    required this.countedMacros,
    required this.fraction,
    required this.basis,
  });

  factory PlannedItem.fromJson(Map<String, dynamic> json) => PlannedItem(
    planItemId: json['plan_item'] as String? ?? '',
    slot: json['slot'] as String? ?? '',
    dishName: json['dish_name'] as String? ?? '',
    servingGrams: json['serving_grams'] as String? ?? '0',
    plannedMacros: Macros.fromJson(
      (json['planned_macros'] as Map<String, dynamic>?) ?? const {},
    ),
    countedMacros: Macros.fromJson(
      (json['counted_macros'] as Map<String, dynamic>?) ?? const {},
    ),
    fraction: json['fraction'] as String? ?? '1',
    basis: AttributionBasis.fromJson(json['basis'] as String?),
  );

  final String planItemId;
  final String slot;
  final String dishName;
  final String servingGrams;
  final Macros plannedMacros;
  final Macros countedMacros;
  final String fraction;
  final AttributionBasis basis;

  bool get isLogged => basis != AttributionBasis.outstanding;

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

/// Food logged that the plan did not contain.
@immutable
class UnplannedItem {
  const UnplannedItem({
    required this.eventId,
    required this.eventType,
    required this.label,
    required this.macros,
    required this.isEstimate,
  });

  factory UnplannedItem.fromJson(Map<String, dynamic> json) => UnplannedItem(
    eventId: json['event'] as String? ?? '',
    eventType: json['event_type'] as String? ?? '',
    label: json['label'] as String? ?? '',
    macros: Macros.fromJson(
      (json['macros'] as Map<String, dynamic>?) ?? const {},
    ),
    isEstimate: json['is_estimate'] as bool? ?? false,
  );

  final String eventId;
  final String eventType;
  final String label;
  final Macros macros;
  final bool isEstimate;
}

@immutable
class Hydration {
  const Hydration({
    required this.targetMl,
    required this.consumedMl,
    required this.remainingMl,
    required this.isTargetMet,
  });

  factory Hydration.fromJson(Map<String, dynamic> json) => Hydration(
    targetMl: json['target_ml'] as int? ?? 0,
    consumedMl: json['consumed_ml'] as int? ?? 0,
    remainingMl: json['remaining_ml'] as int? ?? 0,
    isTargetMet: json['is_target_met'] as bool? ?? false,
  );

  final int targetMl;
  final int consumedMl;
  final int remainingMl;
  final bool isTargetMet;

  /// 0.0–1.0 for the progress bar. Clamped: drinking past the target fills the
  /// bar rather than overflowing it.
  double get fraction {
    if (targetMl <= 0) return 0;
    return (consumedMl / targetMl).clamp(0.0, 1.0);
  }
}

/// One member's reconciled day.
@immutable
class DailySummary {
  const DailySummary({
    required this.memberId,
    required this.date,
    required this.planReference,
    required this.goalKey,
    required this.hasPlan,
    required this.target,
    required this.consumed,
    required this.remaining,
    required this.projected,
    required this.includesEstimates,
    required this.hydration,
    required this.planned,
    required this.unplanned,
    required this.disclaimer,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) => DailySummary(
    memberId: json['member'] as String? ?? '',
    date: json['date'] as String? ?? '',
    planReference: json['plan_reference'] as String? ?? '',
    goalKey: json['goal_key'] as String? ?? '',
    hasPlan: json['has_plan'] as bool? ?? false,
    target: Macros.fromJson(
      (json['target'] as Map<String, dynamic>?) ?? const {},
    ),
    consumed: Macros.fromJson(
      (json['consumed'] as Map<String, dynamic>?) ?? const {},
    ),
    remaining: Macros.fromJson(
      (json['remaining'] as Map<String, dynamic>?) ?? const {},
    ),
    projected: Macros.fromJson(
      (json['projected'] as Map<String, dynamic>?) ?? const {},
    ),
    includesEstimates: json['includes_estimates'] as bool? ?? false,
    hydration: Hydration.fromJson(
      (json['hydration'] as Map<String, dynamic>?) ?? const {},
    ),
    planned: (json['planned'] as List<dynamic>? ?? const [])
        .map((row) => PlannedItem.fromJson(row as Map<String, dynamic>))
        .toList(growable: false),
    unplanned: (json['unplanned'] as List<dynamic>? ?? const [])
        .map((row) => UnplannedItem.fromJson(row as Map<String, dynamic>))
        .toList(growable: false),
    disclaimer: json['disclaimer'] as String? ?? '',
  );

  final String memberId;
  final String date;
  final String planReference;
  final String goalKey;
  final bool hasPlan;
  final Macros target;
  final Macros consumed;
  final Macros remaining;
  final Macros projected;
  final bool includesEstimates;
  final Hydration hydration;
  final List<PlannedItem> planned;
  final List<UnplannedItem> unplanned;
  final String disclaimer;

  /// Whether the day has gone past its target. Read from the sign of the
  /// server's own figure — the app does not subtract anything itself.
  bool get isOverBudget => remaining.energyKcal.startsWith('-');
}

/// One member's totals inside a household view.
///
/// Note what this class *cannot* hold: there is no dish list and no label
/// field, because the server does not send them. The isolation is the server's,
/// and the model shape records it rather than trusting the UI to look away.
@immutable
class HouseholdMemberTotals {
  const HouseholdMemberTotals({
    required this.memberId,
    required this.memberReference,
    required this.displayName,
    required this.hasPlan,
    required this.target,
    required this.consumed,
    required this.remaining,
    required this.includesEstimates,
    required this.hydration,
  });

  factory HouseholdMemberTotals.fromJson(Map<String, dynamic> json) =>
      HouseholdMemberTotals(
        memberId: json['member'] as String? ?? '',
        memberReference: json['member_reference'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        hasPlan: json['has_plan'] as bool? ?? false,
        target: Macros.fromJson(
          (json['target'] as Map<String, dynamic>?) ?? const {},
        ),
        consumed: Macros.fromJson(
          (json['consumed'] as Map<String, dynamic>?) ?? const {},
        ),
        remaining: Macros.fromJson(
          (json['remaining'] as Map<String, dynamic>?) ?? const {},
        ),
        includesEstimates: json['includes_estimates'] as bool? ?? false,
        hydration: Hydration.fromJson(
          (json['hydration'] as Map<String, dynamic>?) ?? const {},
        ),
      );

  final String memberId;
  final String memberReference;
  final String displayName;
  final bool hasPlan;
  final Macros target;
  final Macros consumed;
  final Macros remaining;
  final bool includesEstimates;
  final Hydration hydration;
}

@immutable
class HouseholdDailySummary {
  const HouseholdDailySummary({
    required this.householdId,
    required this.date,
    required this.memberCount,
    required this.target,
    required this.consumed,
    required this.waterTargetMl,
    required this.waterConsumedMl,
    required this.members,
    required this.disclaimer,
  });

  factory HouseholdDailySummary.fromJson(Map<String, dynamic> json) {
    final totals = (json['totals'] as Map<String, dynamic>?) ?? const {};
    return HouseholdDailySummary(
      householdId: json['household'] as String? ?? '',
      date: json['date'] as String? ?? '',
      memberCount: json['member_count'] as int? ?? 0,
      target: Macros.fromJson(
        (totals['target'] as Map<String, dynamic>?) ?? const {},
      ),
      consumed: Macros.fromJson(
        (totals['consumed'] as Map<String, dynamic>?) ?? const {},
      ),
      waterTargetMl: totals['water_target_ml'] as int? ?? 0,
      waterConsumedMl: totals['water_consumed_ml'] as int? ?? 0,
      members: (json['members'] as List<dynamic>? ?? const [])
          .map(
            (row) =>
                HouseholdMemberTotals.fromJson(row as Map<String, dynamic>),
          )
          .toList(growable: false),
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }

  final String householdId;
  final String date;
  final int memberCount;
  final Macros target;
  final Macros consumed;
  final int waterTargetMl;
  final int waterConsumedMl;
  final List<HouseholdMemberTotals> members;
  final String disclaimer;
}

/// One logged event, as the server echoes it back.
@immutable
class IntakeEvent {
  const IntakeEvent({
    required this.id,
    required this.memberId,
    required this.eventType,
    required this.occurredAt,
    required this.localDate,
    required this.label,
    required this.macros,
    required this.isEstimate,
    required this.waterMl,
  });

  factory IntakeEvent.fromJson(Map<String, dynamic> json) => IntakeEvent(
    id: json['id'] as String? ?? '',
    memberId: json['member'] as String? ?? '',
    eventType: json['event_type'] as String? ?? '',
    occurredAt: json['occurred_at'] as String? ?? '',
    localDate: json['local_date'] as String? ?? '',
    label: json['label'] as String? ?? '',
    macros: Macros.fromJson(
      (json['macros'] as Map<String, dynamic>?) ?? const {},
    ),
    isEstimate: json['is_estimate'] as bool? ?? false,
    waterMl: json['water_ml'] as int? ?? 0,
  );

  final String id;
  final String memberId;
  final String eventType;
  final String occurredAt;
  final String localDate;
  final String label;
  final Macros macros;
  final bool isEstimate;
  final int waterMl;
}

/// The signed-in account's own member profile, and the household it sits in.
///
/// The tracker needs a *member* id, and a user is not a member: a caregiver has
/// an account and may hold several member profiles, and a five-year-old has a
/// member profile and no account at all. This is the smallest shape that lets
/// the app ask "whose day am I showing?" without inventing an answer.
@immutable
class MembershipRef {
  const MembershipRef({
    required this.memberId,
    required this.householdId,
    required this.displayName,
    required this.reference,
  });

  factory MembershipRef.fromJson(Map<String, dynamic> json) => MembershipRef(
    memberId: json['id'] as String? ?? '',
    householdId: json['household'] as String? ?? '',
    displayName: json['display_name'] as String? ?? '',
    reference: json['reference'] as String? ?? '',
  );

  final String memberId;
  final String householdId;
  final String displayName;
  final String reference;
}
