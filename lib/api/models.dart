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

// ---------------------------------------------------------------------------
// Phase 4 — pantry, grocery reconciliation, reminders, progress, recovery
//
// Every quantity below is a String, for the reason `Macros` already documents:
// the server sends exact decimals and the app renders them. Parsing to a double
// would reintroduce the binary rounding the server was careful to avoid, and a
// pantry that reads 0.30000000000000004 kg is one nobody trusts.
// ---------------------------------------------------------------------------

class PantryItem {
  const PantryItem({
    required this.id,
    required this.displayName,
    required this.quantityOnHand,
    required this.unit,
    this.label = '',
    this.expiresOn,
    this.bestBeforeOn,
    this.daysUntilDate,
    this.isUseSoon = false,
    this.isArchived = false,
  });

  factory PantryItem.fromJson(Map<String, dynamic> json) => PantryItem(
    id: json['id'] as String? ?? '',
    displayName: json['display_name'] as String? ?? '',
    quantityOnHand: json['quantity_on_hand'] as String? ?? '0',
    unit: json['unit'] as String? ?? 'g',
    label: json['label'] as String? ?? '',
    expiresOn: json['expires_on'] as String?,
    bestBeforeOn: json['best_before_on'] as String?,
    daysUntilDate: json['days_until_date'] as int?,
    isUseSoon: json['is_use_soon'] as bool? ?? false,
    isArchived: json['is_archived'] as bool? ?? false,
  );

  final String id;
  final String displayName;
  final String quantityOnHand;
  final String unit;
  final String label;
  final String? expiresOn;
  final String? bestBeforeOn;

  /// Negative when the date has passed. Null when the item carries no date.
  final int? daysUntilDate;
  final bool isUseSoon;
  final bool isArchived;

  /// The date worth showing, expiry taking precedence over quality.
  String? get soonestDate => expiresOn ?? bestBeforeOn;
}

/// One member's share of one grocery. Never merged with another member's.
class GroceryMemberLine {
  const GroceryMemberLine({
    required this.memberId,
    required this.memberReference,
    required this.grams,
    this.goalKey = '',
    this.excludedAllergenTags = const [],
  });

  factory GroceryMemberLine.fromJson(Map<String, dynamic> json) =>
      GroceryMemberLine(
        memberId: json['member'] as String? ?? '',
        memberReference: json['member_reference'] as String? ?? '',
        grams: json['grams'] as String? ?? '0',
        goalKey: json['goal_key'] as String? ?? '',
        excludedAllergenTags:
            (json['excluded_allergen_tags'] as List<dynamic>? ?? const [])
                .map((tag) => tag as String)
                .toList(growable: false),
      );

  final String memberId;
  final String memberReference;
  final String grams;
  final String goalKey;
  final List<String> excludedAllergenTags;
}

/// A pantry item that could not be converted to a weight, and why not.
class UnconvertibleStock {
  const UnconvertibleStock({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.reason,
  });

  factory UnconvertibleStock.fromJson(Map<String, dynamic> json) =>
      UnconvertibleStock(
        name: json['name'] as String? ?? '',
        quantity: json['quantity'] as String? ?? '0',
        unit: json['unit'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
      );

  final String name;
  final String quantity;
  final String unit;
  final String reason;
}

/// One grocery: what the plans need, what the cupboard holds, what is missing.
class ReconciledGrocery {
  const ReconciledGrocery({
    required this.canonicalKey,
    required this.name,
    required this.requiredGrams,
    required this.onHandGrams,
    required this.netToBuyGrams,
    required this.surplusGrams,
    this.isFullyStocked = false,
    this.members = const [],
    this.unconvertible = const [],
  });

  factory ReconciledGrocery.fromJson(
    Map<String, dynamic> json,
  ) => ReconciledGrocery(
    canonicalKey: json['canonical_key'] as String? ?? '',
    name: json['name'] as String? ?? '',
    requiredGrams: json['required_grams'] as String? ?? '0',
    onHandGrams: json['on_hand_grams'] as String? ?? '0',
    netToBuyGrams: json['net_to_buy_grams'] as String? ?? '0',
    surplusGrams: json['surplus_grams'] as String? ?? '0',
    isFullyStocked: json['is_fully_stocked'] as bool? ?? false,
    members: (json['members'] as List<dynamic>? ?? const [])
        .map((row) => GroceryMemberLine.fromJson(row as Map<String, dynamic>))
        .toList(growable: false),
    unconvertible: (json['unconvertible'] as List<dynamic>? ?? const [])
        .map((row) => UnconvertibleStock.fromJson(row as Map<String, dynamic>))
        .toList(growable: false),
  );

  final String canonicalKey;
  final String name;
  final String requiredGrams;
  final String onHandGrams;
  final String netToBuyGrams;
  final String surplusGrams;
  final bool isFullyStocked;

  /// Per-member requirement lines. Rendered separately, never summed — two
  /// members' shares stop being interchangeable the moment one of them has an
  /// allergy the other does not.
  final List<GroceryMemberLine> members;
  final List<UnconvertibleStock> unconvertible;
}

class GroceryReconciliation {
  const GroceryReconciliation({
    required this.householdId,
    required this.start,
    required this.end,
    required this.disclaimer,
    this.groceries = const [],
    this.useSoon = const [],
  });

  factory GroceryReconciliation.fromJson(
    Map<String, dynamic> json,
  ) => GroceryReconciliation(
    householdId: json['household'] as String? ?? '',
    start: json['start'] as String? ?? '',
    end: json['end'] as String? ?? '',
    disclaimer: json['disclaimer'] as String? ?? '',
    groceries: (json['groceries'] as List<dynamic>? ?? const [])
        .map((row) => ReconciledGrocery.fromJson(row as Map<String, dynamic>))
        .toList(growable: false),
    useSoon: (json['use_soon'] as List<dynamic>? ?? const [])
        .map((row) => (row as Map<String, dynamic>)['name'] as String? ?? '')
        .toList(growable: false),
  );

  final String householdId;
  final String start;
  final String end;
  final String disclaimer;
  final List<ReconciledGrocery> groceries;
  final List<String> useSoon;

  List<ReconciledGrocery> get toBuy =>
      groceries.where((g) => g.netToBuyGrams != '0.0').toList(growable: false);

  List<ReconciledGrocery> get alreadyCovered =>
      groceries.where((g) => g.isFullyStocked).toList(growable: false);
}

class ReminderSchedule {
  const ReminderSchedule({
    required this.id,
    required this.memberId,
    required this.kind,
    required this.sendAtLocal,
    this.slot = '',
    this.isEnabled = false,
    this.approvedBy = '',
    this.requiresApprovalToEnable = true,
  });

  factory ReminderSchedule.fromJson(Map<String, dynamic> json) =>
      ReminderSchedule(
        id: json['id'] as String? ?? '',
        memberId: json['member'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        sendAtLocal: json['send_at_local'] as String? ?? '',
        slot: json['slot'] as String? ?? '',
        isEnabled: json['is_enabled'] as bool? ?? false,
        approvedBy: json['approved_by'] as String? ?? '',
        requiresApprovalToEnable:
            json['requires_approval_to_enable'] as bool? ?? true,
      );

  final String id;
  final String memberId;
  final String kind;
  final String sendAtLocal;
  final String slot;
  final bool isEnabled;
  final String approvedBy;

  /// The server says so on every row. The app renders the decision rather than
  /// deciding for itself whether an approver is needed.
  final bool requiresApprovalToEnable;
}

class ProgressTrends {
  const ProgressTrends({
    required this.adherence,
    required this.hydrationConsistency,
    required this.mealRegularity,
    required this.loggingConsistency,
    required this.macroConsistency,
  });

  factory ProgressTrends.fromJson(Map<String, dynamic> json) => ProgressTrends(
    adherence: json['adherence'] as String? ?? '0',
    hydrationConsistency: json['hydration_consistency'] as String? ?? '0',
    mealRegularity: json['meal_regularity'] as String? ?? '0',
    loggingConsistency: json['logging_consistency'] as String? ?? '0',
    macroConsistency: json['macro_consistency'] as String? ?? '0',
  );

  final String adherence;
  final String hydrationConsistency;
  final String mealRegularity;
  final String loggingConsistency;
  final String macroConsistency;
}

class MemberProgress {
  const MemberProgress({
    required this.memberId,
    required this.memberReference,
    required this.start,
    required this.end,
    required this.trends,
    required this.disclaimer,
    this.daysInWindow = 0,
    this.daysLogged = 0,
    this.isRepresentative = false,
    this.loggingStreakDays = 0,
    this.longestLoggingStreakDays = 0,
  });

  factory MemberProgress.fromJson(Map<String, dynamic> json) => MemberProgress(
    memberId: json['member'] as String? ?? '',
    memberReference: json['member_reference'] as String? ?? '',
    start: json['start'] as String? ?? '',
    end: json['end'] as String? ?? '',
    trends: ProgressTrends.fromJson(
      json['trends'] as Map<String, dynamic>? ?? const {},
    ),
    disclaimer: json['disclaimer'] as String? ?? '',
    daysInWindow: json['days_in_window'] as int? ?? 0,
    daysLogged: json['days_logged'] as int? ?? 0,
    isRepresentative: json['is_representative'] as bool? ?? false,
    loggingStreakDays: json['logging_streak_days'] as int? ?? 0,
    longestLoggingStreakDays: json['longest_logging_streak_days'] as int? ?? 0,
  );

  final String memberId;
  final String memberReference;
  final String start;
  final String end;
  final ProgressTrends trends;
  final String disclaimer;
  final int daysInWindow;
  final int daysLogged;

  /// False below a week of logging. The screen shows "not enough logged yet"
  /// rather than drawing four points as a trend line.
  final bool isRepresentative;
  final int loggingStreakDays;
  final int longestLoggingStreakDays;
}

class HouseholdProgress {
  const HouseholdProgress({
    required this.householdId,
    required this.start,
    required this.end,
    required this.disclaimer,
    this.members = const [],
  });

  factory HouseholdProgress.fromJson(Map<String, dynamic> json) =>
      HouseholdProgress(
        householdId: json['household'] as String? ?? '',
        start: json['start'] as String? ?? '',
        end: json['end'] as String? ?? '',
        disclaimer: json['disclaimer'] as String? ?? '',
        members: (json['members'] as List<dynamic>? ?? const [])
            .map((row) => MemberProgress.fromJson(row as Map<String, dynamic>))
            .toList(growable: false),
      );

  final String householdId;
  final String start;
  final String end;
  final String disclaimer;

  /// Totals only. The server sends no per-day detail on this endpoint, so the
  /// screen cannot show one member's pattern to another.
  final List<MemberProgress> members;
}

class RecoveryAdjustment {
  const RecoveryAdjustment({
    required this.day,
    required this.originalTargetKcal,
    required this.proposedTargetKcal,
    required this.deltaKcal,
    this.wasClamped = false,
  });

  factory RecoveryAdjustment.fromJson(Map<String, dynamic> json) =>
      RecoveryAdjustment(
        day: json['day'] as String? ?? '',
        originalTargetKcal: json['original_target_kcal'] as String? ?? '0',
        proposedTargetKcal: json['proposed_target_kcal'] as String? ?? '0',
        deltaKcal: json['delta_kcal'] as String? ?? '0',
        wasClamped: json['was_clamped'] as bool? ?? false,
      );

  final String day;
  final String originalTargetKcal;
  final String proposedTargetKcal;
  final String deltaKcal;
  final bool wasClamped;
}

class ClinicalReferralInfo {
  const ClinicalReferralInfo({required this.reason, this.goalKey = ''});

  factory ClinicalReferralInfo.fromJson(Map<String, dynamic> json) =>
      ClinicalReferralInfo(
        reason: json['reason'] as String? ?? '',
        goalKey: json['goal_key'] as String? ?? '',
      );

  final String reason;
  final String goalKey;
}

class RecoveryProposal {
  const RecoveryProposal({
    required this.id,
    required this.memberId,
    required this.trigger,
    required this.triggerDate,
    required this.status,
    required this.floorKcal,
    required this.ceilingKcal,
    required this.shortfallKcal,
    required this.redistributedKcal,
    required this.unrecoveredKcal,
    required this.rationale,
    this.adjustments = const [],
    this.needsClinician = false,
    this.referral,
  });

  factory RecoveryProposal.fromJson(Map<String, dynamic> json) =>
      RecoveryProposal(
        id: json['id'] as String? ?? '',
        memberId: json['member'] as String? ?? '',
        trigger: json['trigger'] as String? ?? '',
        triggerDate: json['trigger_date'] as String? ?? '',
        status: json['status'] as String? ?? '',
        floorKcal: json['floor_kcal'] as String? ?? '0',
        ceilingKcal: json['ceiling_kcal'] as String? ?? '0',
        shortfallKcal: json['shortfall_kcal'] as String? ?? '0',
        redistributedKcal: json['redistributed_kcal'] as String? ?? '0',
        unrecoveredKcal: json['unrecovered_kcal'] as String? ?? '0',
        rationale: json['rationale'] as String? ?? '',
        adjustments: (json['adjustments'] as List<dynamic>? ?? const [])
            .map(
              (row) => RecoveryAdjustment.fromJson(row as Map<String, dynamic>),
            )
            .toList(growable: false),
        needsClinician: json['needs_clinician'] as bool? ?? false,
        referral: json['referral'] == null
            ? null
            : ClinicalReferralInfo.fromJson(
                json['referral'] as Map<String, dynamic>,
              ),
      );

  final String id;
  final String memberId;
  final String trigger;
  final String triggerDate;
  final String status;

  /// The envelope the draft was built inside, rendered next to the advice so
  /// the guarantee is as visible as the suggestion.
  final String floorKcal;
  final String ceilingKcal;
  final String shortfallKcal;
  final String redistributedKcal;

  /// The part of the shortfall the draft deliberately does not make up.
  final String unrecoveredKcal;
  final String rationale;
  final List<RecoveryAdjustment> adjustments;
  final bool needsClinician;
  final ClinicalReferralInfo? referral;

  bool get isOpen => status == 'proposed';
}

/// One ingredient's share of a deduction proposal.
class PantryDeductionLine {
  const PantryDeductionLine({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.availableQuantity,
    this.exceedsAvailable = false,
  });

  factory PantryDeductionLine.fromJson(Map<String, dynamic> json) =>
      PantryDeductionLine(
        itemId: json['item'] as String? ?? '',
        itemName: json['item_name'] as String? ?? '',
        quantity: json['quantity'] as String? ?? '0',
        unit: json['unit'] as String? ?? '',
        availableQuantity: json['available_quantity'] as String? ?? '0',
        exceedsAvailable: json['exceeds_available'] as bool? ?? false,
      );

  final String itemId;
  final String itemName;
  final String quantity;
  final String unit;
  final String availableQuantity;

  /// True when the proposal asks for more than the cupboard holds. Shown, not
  /// silently clamped: the books and the kitchen disagreeing is worth knowing.
  final bool exceedsAvailable;
}

/// A draft "shall I take this out of the pantry?", awaiting a person.
class PantryDeductionProposal {
  const PantryDeductionProposal({
    required this.id,
    required this.status,
    this.summary = '',
    this.lines = const [],
  });

  factory PantryDeductionProposal.fromJson(Map<String, dynamic> json) =>
      PantryDeductionProposal(
        id: json['id'] as String? ?? '',
        status: json['status'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        lines: (json['lines'] as List<dynamic>? ?? const [])
            .map(
              (row) =>
                  PantryDeductionLine.fromJson(row as Map<String, dynamic>),
            )
            .toList(growable: false),
      );

  final String id;
  final String status;

  /// The dish and its slot, e.g. "Sambar Rice (lunch)". Never a goal, a
  /// condition or an allergen — a pantry screen is not a health screen.
  final String summary;
  final List<PantryDeductionLine> lines;

  bool get isOpen => status == 'proposed';
}
