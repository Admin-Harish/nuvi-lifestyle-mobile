/// The goal catalogue.
///
/// Gated goals are **shown, not hidden**. Someone with hypertension should be
/// able to see that Nuvi knows about it and that support is awaiting clinical
/// review — hiding it would read as "we don't do that", which is a different
/// and less honest claim.
///
/// Two rules this screen follows:
///
/// * Availability is the server's decision. The app never reads a feature flag
///   and never infers that a goal "should" be usable; it renders
///   [GoalCatalogueEntry.available] as given.
/// * A gated goal is not selectable and says why, in the server's own words.
///   The UI does not invent an explanation for a clinical decision.
library;

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/nuvi_api.dart';
import '../theme/nuvi_tokens.dart';
import '../widgets/nuvi_scaffold.dart';

class GoalCatalogueScreen extends StatefulWidget {
  const GoalCatalogueScreen({required this.api, super.key});

  final NuviApi api;

  @override
  State<GoalCatalogueScreen> createState() => _GoalCatalogueScreenState();
}

class _GoalCatalogueScreenState extends State<GoalCatalogueScreen> {
  late Future<List<GoalCatalogueEntry>> _entries;
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _entries = widget.api.goalCatalogue();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GoalCatalogueEntry>>(
      future: _entries,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const NuviPage(
            title: 'Goals',
            children: [Center(child: CircularProgressIndicator())],
          );
        }
        if (snapshot.hasError) {
          return const NuviPage(
            title: 'Goals',
            children: [
              NuviNotice(
                key: Key('goals-error'),
                message:
                    'We could not load your goals just now. Please try again.',
                icon: Icons.cloud_off_outlined,
              ),
            ],
          );
        }

        final entries = snapshot.data ?? const <GoalCatalogueEntry>[];
        final available = entries.where((entry) => entry.available).toList();
        final gated = entries.where((entry) => !entry.available).toList();

        return NuviPage(
          title: 'Goals',
          children: [
            Text(
              'Choose what you are working towards. You can pick more than one, '
              'and change or pause any of them later.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: NuviSpacing.xl),
            ...available.map(_availableTile),
            if (gated.isNotEmpty) ...[
              const SizedBox(height: NuviSpacing.xl),
              Text(
                'Needs a clinician',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: NuviSpacing.sm),
              const NuviNotice(
                key: Key('goals-gated-explainer'),
                message:
                    'Nuvi supports these, but a qualified clinician has to review '
                    'them before they can be used. You can record one on your '
                    'profile now; nothing will be planned from it until that '
                    'review happens.',
                icon: Icons.medical_information_outlined,
              ),
              ...gated.map(_gatedTile),
            ],
          ],
        );
      },
    );
  }

  Widget _availableTile(GoalCatalogueEntry entry) {
    final selected = _selected.contains(entry.key);
    return Card(
      key: Key('goal-${entry.key}'),
      margin: const EdgeInsets.only(bottom: NuviSpacing.md),
      child: CheckboxListTile(
        value: selected,
        title: Text(entry.label),
        subtitle: entry.explanation.isEmpty ? null : Text(entry.explanation),
        onChanged: (checked) => setState(() {
          if (checked ?? false) {
            _selected.add(entry.key);
          } else {
            _selected.remove(entry.key);
          }
        }),
      ),
    );
  }

  Widget _gatedTile(GoalCatalogueEntry entry) {
    return Card(
      key: Key('goal-${entry.key}'),
      margin: const EdgeInsets.only(bottom: NuviSpacing.md),
      child: ListTile(
        // Not selectable, and not merely greyed out: there is no onTap, so the
        // control cannot be driven by a stray gesture either.
        enabled: false,
        leading: const Icon(Icons.lock_outline),
        title: Text(entry.label),
        subtitle: Text(
          entry.reason.isEmpty ? 'Awaiting clinical review.' : entry.reason,
        ),
        trailing: const Text('Awaiting review', textAlign: TextAlign.end),
      ),
    );
  }
}
