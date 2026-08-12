import 'package:flutter/material.dart';

import 'api/nuvi_api.dart';
import 'auth/login_screen.dart';
import 'auth/session.dart';
import 'config/app_config.dart';
import 'api/models.dart';
import 'consent/consent_screen.dart';
import 'goals/goal_catalogue_screen.dart';
import 'theme/nuvi_theme.dart';
import 'theme/nuvi_tokens.dart';
import 'tracking/daily_tracker_screen.dart';
import 'tracking/household_summary_screen.dart';
import 'widgets/nuvi_scaffold.dart';

/// The application shell.
///
/// Phase 3 adds two surfaces to the signed-in shell: today's tracker and the
/// household summary. Both need a *member* id, which is not the same thing as
/// the signed-in user id — a caregiver holds an account and may cover several
/// member profiles — so the shell resolves the membership once and passes it
/// down rather than letting each screen guess.
class NuviLifestyleApp extends StatelessWidget {
  const NuviLifestyleApp({
    required this.config,
    required this.api,
    required this.session,
    super.key,
  });

  final AppConfig config;
  final NuviApi api;
  final Session session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nuvi Lifestyle',
      debugShowCheckedModeBanner: config.environment.showDebugBanner,
      theme: NuviTheme.light,
      darkTheme: NuviTheme.dark,
      home: AnimatedBuilder(
        animation: session,
        builder: (context, _) => session.isSignedIn
            ? HomeScreen(api: api, session: session, config: config)
            : LoginScreen(session: session),
      ),
    );
  }
}

/// What a signed-in member sees.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.api,
    required this.session,
    required this.config,
    super.key,
  });

  final NuviApi api;
  final Session session;
  final AppConfig config;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  late Future<List<MembershipRef>> _memberships;

  @override
  void initState() {
    super.initState();
    _memberships = widget.api.memberships();
  }

  /// The date the tracker opens on.
  ///
  /// The pilot market is Asia/Kolkata (UTC+05:30) and the device may be
  /// anywhere, so "today" is computed in the market's offset rather than read
  /// from the device's local date. The server buckets days the same way; a
  /// phone in another zone must not disagree with it about which day this is.
  static String todayInMarket() {
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _ProfileTab(
            session: widget.session,
            config: widget.config,
            greeting: user?.fullName.isNotEmpty ?? false
                ? user!.fullName
                : user?.email ?? '',
          ),
          _MembershipGate(
            memberships: _memberships,
            title: 'Today',
            builder: (membership) => DailyTrackerScreen(
              api: widget.api,
              memberId: membership.memberId,
              date: todayInMarket(),
            ),
          ),
          _MembershipGate(
            memberships: _memberships,
            title: 'Household',
            builder: (membership) => HouseholdSummaryScreen(
              api: widget.api,
              householdId: membership.householdId,
              date: todayInMarket(),
            ),
          ),
          GoalCatalogueScreen(api: widget.api),
          ConsentScreen(api: widget.api),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            label: 'Household',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            label: 'Goals',
          ),
          NavigationDestination(
            icon: Icon(Icons.privacy_tip_outlined),
            label: 'Consent',
          ),
        ],
      ),
    );
  }
}

/// Resolves which member a tracking screen is about, before showing it.
///
/// An account with no member profile is a real state — a dietitian with no
/// grants, an account mid-onboarding — and it gets a sentence rather than an
/// empty tracker that looks broken.
class _MembershipGate extends StatelessWidget {
  const _MembershipGate({
    required this.memberships,
    required this.title,
    required this.builder,
  });

  final Future<List<MembershipRef>> memberships;
  final String title;
  final Widget Function(MembershipRef membership) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MembershipRef>>(
      future: memberships,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return NuviPage(
            title: title,
            children: const [
              Center(
                key: Key('membership-loading'),
                child: CircularProgressIndicator(),
              ),
            ],
          );
        }
        final rows = snapshot.data ?? const <MembershipRef>[];
        if (snapshot.hasError || rows.isEmpty) {
          return NuviPage(
            title: title,
            children: const [
              NuviNotice(
                key: Key('membership-none'),
                message:
                    'We could not find a member profile for your account. '
                    'Your household caregiver can add one.',
                icon: Icons.person_search_outlined,
              ),
            ],
          );
        }
        return builder(rows.first);
      },
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.session,
    required this.config,
    required this.greeting,
  });

  final Session session;
  final AppConfig config;
  final String greeting;

  @override
  Widget build(BuildContext context) {
    final user = session.user;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuvi Lifestyle'),
        actions: [
          IconButton(
            key: const Key('sign-out'),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: session.signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(NuviSpacing.xl),
          children: [
            Text(greeting, style: textTheme.displayLarge),
            const SizedBox(height: NuviSpacing.sm),
            if (user != null && !user.isEmailVerified)
              const _Row(
                label: 'Email',
                value: 'Not verified yet',
                key: Key('profile-unverified'),
              ),
            _Row(label: 'Flavor', value: config.environment.label),
            _Row(label: 'API base URL', value: config.apiBaseUrl),
            // Roles are shown for transparency, never used as authority: every
            // action is authorised server-side regardless of what this says.
            _Row(
              label: 'Roles',
              value: (user?.roles ?? const []).join(', '),
              key: const Key('profile-roles'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NuviSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
