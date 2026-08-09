import 'package:flutter/material.dart';

import 'api/nuvi_api.dart';
import 'auth/login_screen.dart';
import 'auth/session.dart';
import 'config/app_config.dart';
import 'consent/consent_screen.dart';
import 'goals/goal_catalogue_screen.dart';
import 'theme/nuvi_theme.dart';
import 'theme/nuvi_tokens.dart';

/// The application shell.
///
/// Phase 1 has three surfaces: sign in, goals, consent. There is still no food
/// catalogue and no plan — those are Phase 2, and nothing here pretends
/// otherwise.
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
