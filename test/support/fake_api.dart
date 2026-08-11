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
}

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
