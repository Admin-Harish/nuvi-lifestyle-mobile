import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'theme/nuvi_theme.dart';
import 'theme/nuvi_tokens.dart';

/// The application shell.
///
/// Phase 0 has no product screens — no food catalogue, no menus, no goals.
/// This exists to prove the flavor plumbing and the theme tokens are wired,
/// and to give Phase 1 something to hang the first real screen off.
class NuviLifestyleApp extends StatelessWidget {
  const NuviLifestyleApp({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nuvi Lifestyle',
      debugShowCheckedModeBanner: config.environment.showDebugBanner,
      theme: NuviTheme.light,
      darkTheme: NuviTheme.dark,
      home: BootstrapScreen(config: config),
    );
  }
}

/// Shows what this build is pointed at. Replaced by the first real screen in
/// Phase 1.
class BootstrapScreen extends StatelessWidget {
  const BootstrapScreen({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuvi Lifestyle')),
      body: Padding(
        padding: const EdgeInsets.all(NuviSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phase 0', style: textTheme.displayLarge),
            const SizedBox(height: NuviSpacing.sm),
            Text(
              'Bootstrap build. No product features yet.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: NuviSpacing.xl),
            _ConfigRow(label: 'Flavor', value: config.environment.label),
            _ConfigRow(label: 'API base URL', value: config.apiBaseUrl),
            _ConfigRow(
              label: 'Timeout',
              value: '${config.apiTimeout.inSeconds}s',
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({required this.label, required this.value});

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
