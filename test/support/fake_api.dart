/// A [NuviApi] that answers from memory.
///
/// Every screen takes its API as a constructor argument, so the widget tests
/// drive real widgets against this without a socket, a server or a timeout.
library;

import 'package:nuvi_lifestyle/api/models.dart';
import 'package:nuvi_lifestyle/api/nuvi_api.dart';

class FakeNuviApi implements NuviApi {
  FakeNuviApi({
    this.loginFailure,
    this.registerFailure,
    this.verifyFailure,
    this.goals = const [],
    this.consents = const [],
    this.consentWriteFailure,
    this.user,
    this.goalsFailure,
    this.delay,
    this.menuLibrary_,
    this.menuFailure,
    this.plans = const [],
    this.plansFailure,
    this.planDetail,
    this.planDetailFailure,
    this.dailySummary_,
    this.dailySummaryFailure,
    this.householdSummary_,
    this.householdSummaryFailure,
    this.logIntakeFailure,
    this.memberships_ = const [],
  });

  /// Makes a call take a frame, so a test can observe the in-flight state.
  final Duration? delay;

  /// Thrown by [login] when set. Used to prove the UI shows one message for
  /// every credential failure.
  final Object? loginFailure;
  final Object? registerFailure;
  final Object? verifyFailure;
  final Object? goalsFailure;
  final Object? consentWriteFailure;

  /// Phase 2 fixtures.
  MenuLibrary? menuLibrary_;

  /// Cleared by a test to model a retry that succeeds.
  Object? menuFailure;
  List<MealPlanSummary> plans;
  Object? plansFailure;
  final MealPlanDetail? planDetail;
  final Object? planDetailFailure;

  /// Phase 3 fixtures.
  ///
  /// [logged] records every write so a test can assert that a retried tap
  /// produced *one* call carrying the same idempotency key — which is the
  /// client half of the duplicate-submission guarantee. The server half is
  /// tested against the real database in the API suite.
  DailySummary? dailySummary_;
  Object? dailySummaryFailure;
  HouseholdDailySummary? householdSummary_;
  Object? householdSummaryFailure;
  Object? logIntakeFailure;
  List<MembershipRef> memberships_;

  final List<({String eventType, String idempotencyKey, int waterMl})> logged =
      <({String eventType, String idempotencyKey, int waterMl})>[];

  List<GoalCatalogueEntry> goals;
  List<ConsentSummaryEntry> consents;
  CurrentUser? user;

  final List<String> calls = <String>[];
  final List<(String purpose, String decision)> consentWrites =
      <(String, String)>[];

  @override
  Future<void> register({
    required String email,
    required String password,
    String fullName = '',
  }) async {
    calls.add('register:$email');
    if (registerFailure != null) throw registerFailure!;
  }

  @override
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    calls.add('verify:$email:$code');
    if (verifyFailure != null) throw verifyFailure!;
  }

  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    calls.add('login:$email');
    if (delay != null) await Future<void>.delayed(delay!);
    if (loginFailure != null) throw loginFailure!;
    return const AuthTokens(access: 'access-token', refresh: 'refresh-token');
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    calls.add('reset:$email');
  }

  @override
  Future<CurrentUser> currentUser() async {
    calls.add('me');
    return user ??
        const CurrentUser(
          id: 'user-1',
          email: 'meera.nair@example.com',
          fullName: 'Meera Nair',
          isEmailVerified: true,
          roles: ['member', 'household_caregiver'],
          capabilities: ['self.profile_read', 'member.goal_read'],
        );
  }

  @override
  Future<List<GoalCatalogueEntry>> goalCatalogue() async {
    calls.add('goals');
    if (goalsFailure != null) throw goalsFailure!;
    return goals;
  }

  @override
  Future<List<ConsentSummaryEntry>> consentSummary() async {
    calls.add('consents');
    return consents;
  }

  @override
  Future<void> recordConsent({
    required String purpose,
    required String decision,
  }) async {
    calls.add('consent:$purpose:$decision');
    if (consentWriteFailure != null) throw consentWriteFailure!;
    consentWrites.add((purpose, decision));
    consents = consents
        .map(
          (entry) => entry.purpose == purpose
              ? ConsentSummaryEntry(
                  purpose: entry.purpose,
                  granted: decision == 'granted',
                  decision: decision,
                  documentVersion: entry.documentVersion,
                  documentStatus: entry.documentStatus,
                  isPresentable: entry.isPresentable,
                  withdrawable: entry.withdrawable,
                )
              : entry,
        )
        .toList(growable: false);
  }

  @override
  Future<MenuLibrary> menuLibrary({required String goalKey}) async {
    calls.add('menuLibrary:$goalKey');
    // Always yield at least one microtask. Throwing before any await
    // completes the future before FutureBuilder subscribes, and the
    // error surfaces as unhandled rather than as an error state.
    await Future<void>.delayed(delay ?? Duration.zero);
    if (menuFailure != null) throw menuFailure!;
    return menuLibrary_ ??
        MenuLibrary(
          goalKey: goalKey,
          days: const [],
          emptyReason: MenuLibraryEmptyReason.notGenerated,
          isGated: false,
        );
  }

  @override
  Future<List<MealPlanSummary>> mealPlans() async {
    calls.add('mealPlans');
    // Always yield at least one microtask. Throwing before any await
    // completes the future before FutureBuilder subscribes, and the
    // error surfaces as unhandled rather than as an error state.
    await Future<void>.delayed(delay ?? Duration.zero);
    if (plansFailure != null) throw plansFailure!;
    return plans;
  }

  @override
  Future<MealPlanDetail> mealPlan({required String id}) async {
    calls.add('mealPlan:$id');
    // Always yield at least one microtask. Throwing before any await
    // completes the future before FutureBuilder subscribes, and the
    // error surfaces as unhandled rather than as an error state.
    await Future<void>.delayed(delay ?? Duration.zero);
    if (planDetailFailure != null) throw planDetailFailure!;
    return planDetail!;
  }

  @override
  Future<DailySummary> dailySummary({
    required String memberId,
    required String date,
  }) async {
    calls.add('dailySummary:$memberId:$date');
    await Future<void>.delayed(delay ?? Duration.zero);
    if (dailySummaryFailure != null) throw dailySummaryFailure!;
    return dailySummary_ ?? sampleDailySummary();
  }

  @override
  Future<HouseholdDailySummary> householdDailySummary({
    required String householdId,
    required String date,
  }) async {
    calls.add('householdSummary:$householdId:$date');
    await Future<void>.delayed(delay ?? Duration.zero);
    if (householdSummaryFailure != null) throw householdSummaryFailure!;
    return householdSummary_ ?? sampleHouseholdSummary();
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
    calls.add('logIntake:$eventType:$idempotencyKey');
    await Future<void>.delayed(delay ?? Duration.zero);
    if (logIntakeFailure != null) throw logIntakeFailure!;
    logged.add((
      eventType: eventType,
      idempotencyKey: idempotencyKey,
      waterMl: waterMl,
    ));
    return IntakeEvent(
      id: 'event-${logged.length}',
      memberId: memberId,
      eventType: eventType,
      occurredAt: occurredAt,
      localDate: occurredAt.split('T').first,
      label: label,
      macros: const Macros(
        energyKcal: '0',
        proteinG: '0',
        carbohydrateG: '0',
        fatG: '0',
        fibreG: '0',
      ),
      isEstimate: false,
      waterMl: waterMl,
    );
  }

  @override
  Future<void> setWaterTarget({
    required String memberId,
    required String date,
    required int targetMl,
  }) async {
    calls.add('setWaterTarget:$memberId:$targetMl');
    await Future<void>.delayed(delay ?? Duration.zero);
  }

  @override
  Future<List<MembershipRef>> memberships() async {
    calls.add('memberships');
    await Future<void>.delayed(delay ?? Duration.zero);
    return memberships_;
  }
}

/// ---------------------------------------------------------------------------
/// Phase 3 sample payloads
///
/// The numbers mirror the API suite's `tracked_household` fixture: a 200 kcal
/// breakfast and a 400 kcal lunch against a 600 kcal target. Keeping the two
/// suites on the same figures means a screen assertion and a server assertion
/// describe the same day.
/// ---------------------------------------------------------------------------

Macros macros({
  String energy = '0',
  String protein = '0',
  String carbs = '0',
  String fat = '0',
  String fibre = '0',
}) => Macros(
  energyKcal: energy,
  proteinG: protein,
  carbohydrateG: carbs,
  fatG: fat,
  fibreG: fibre,
);

DailySummary sampleDailySummary({
  String consumedEnergy = '200',
  String remainingEnergy = '400',
  bool includesEstimates = false,
  List<PlannedItem>? planned,
  List<UnplannedItem> unplanned = const [],
  Hydration? hydration,
}) => DailySummary(
  memberId: 'member-1',
  date: '2026-03-01',
  planReference: 'MP-TRACK-0001',
  goalKey: 'maintenance',
  hasPlan: true,
  target: macros(
    energy: '600',
    protein: '30',
    carbs: '90',
    fat: '12',
    fibre: '9',
  ),
  consumed: macros(
    energy: consumedEnergy,
    protein: '10',
    carbs: '30',
    fat: '4',
    fibre: '3',
  ),
  remaining: macros(energy: remainingEnergy),
  projected: macros(energy: '600'),
  includesEstimates: includesEstimates,
  hydration:
      hydration ??
      const Hydration(
        targetMl: 2000,
        consumedMl: 750,
        remainingMl: 1250,
        isTargetMet: false,
      ),
  planned:
      planned ??
      [
        PlannedItem(
          planItemId: 'item-breakfast',
          slot: 'breakfast',
          dishName: 'Upma',
          servingGrams: '100.00',
          plannedMacros: macros(energy: '200'),
          countedMacros: macros(energy: '200'),
          fraction: '1',
          basis: AttributionBasis.eaten,
        ),
        PlannedItem(
          planItemId: 'item-lunch',
          slot: 'lunch',
          dishName: 'Sambar Rice',
          servingGrams: '100.00',
          plannedMacros: macros(energy: '400'),
          countedMacros: macros(energy: '400'),
          fraction: '1',
          basis: AttributionBasis.outstanding,
        ),
      ],
  unplanned: unplanned,
  disclaimer:
      'Macro figures are unreviewed estimates pending clinical sign-off. '
      'Not medical advice.',
);

HouseholdDailySummary sampleHouseholdSummary({int memberCount = 2}) =>
    HouseholdDailySummary(
      householdId: 'household-1',
      date: '2026-03-01',
      memberCount: memberCount,
      target: macros(energy: '900'),
      consumed: macros(energy: '200'),
      waterTargetMl: 4000,
      waterConsumedMl: 750,
      members: [
        HouseholdMemberTotals(
          memberId: 'member-1',
          memberReference: 'M1',
          displayName: 'Meena',
          hasPlan: true,
          target: macros(energy: '600'),
          consumed: macros(energy: '200'),
          remaining: macros(energy: '400'),
          includesEstimates: false,
          hydration: const Hydration(
            targetMl: 2000,
            consumedMl: 750,
            remainingMl: 1250,
            isTargetMet: false,
          ),
        ),
        if (memberCount > 1)
          HouseholdMemberTotals(
            memberId: 'member-2',
            memberReference: 'M2',
            displayName: 'Aditya',
            hasPlan: true,
            target: macros(energy: '300'),
            consumed: macros(energy: '0'),
            remaining: macros(energy: '300'),
            includesEstimates: false,
            hydration: const Hydration(
              targetMl: 2000,
              consumedMl: 0,
              remainingMl: 2000,
              isTargetMet: false,
            ),
          ),
      ],
      disclaimer:
          'Macro figures are unreviewed estimates pending clinical sign-off. '
          'Not medical advice.',
    );

/// The wellness/gated split the server actually returns.
List<GoalCatalogueEntry> sampleGoals() => const [
  GoalCatalogueEntry(
    key: 'weight_loss',
    label: 'Weight loss',
    category: 'wellness',
    available: true,
    statusIfSelected: 'active',
    reason: '',
    explanation: 'Plans aim for a gradual, sustainable reduction.',
  ),
  GoalCatalogueEntry(
    key: 'general_wellness',
    label: 'General wellness',
    category: 'wellness',
    available: true,
    statusIfSelected: 'active',
    reason: '',
    explanation: 'Plans emphasise variety, fibre and regular meals.',
  ),
  GoalCatalogueEntry(
    key: 'diabetes_type_2',
    label: 'Diabetes — type 2',
    category: 'clinical',
    available: false,
    statusIfSelected: 'clinical_review_required',
    reason:
        'This goal needs review by a qualified clinician before it can be used.',
    explanation: '',
  ),
  GoalCatalogueEntry(
    key: 'maternity_trimester_2',
    label: 'Maternity — trimester 2',
    category: 'maternity',
    available: false,
    statusIfSelected: 'clinical_review_required',
    reason:
        'This goal needs review by a qualified clinician before it can be used.',
    explanation: '',
  ),
];

/// The consent summary as it looks while the copy is still DRAFT.
List<ConsentSummaryEntry> sampleDraftConsents() => const [
  ConsentSummaryEntry(
    purpose: 'data_processing',
    granted: true,
    decision: 'granted',
    documentVersion: 1,
    documentStatus: 'draft',
    isPresentable: false,
    withdrawable: false,
  ),
  ConsentSummaryEntry(
    purpose: 'communications',
    granted: false,
    decision: null,
    documentVersion: 1,
    documentStatus: 'draft',
    isPresentable: false,
    withdrawable: true,
  ),
  ConsentSummaryEntry(
    purpose: 'health_data',
    granted: true,
    decision: 'granted',
    documentVersion: 1,
    documentStatus: 'draft',
    isPresentable: false,
    withdrawable: true,
  ),
];
