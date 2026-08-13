/// Consent.
///
/// Two things this screen must get right, and both are tested:
///
/// * **Draft copy is labelled.** While the wording is awaiting legal sign-off
///   the API returns `is_presentable: false`, and the screen shows a banner
///   saying so. Rendering unreviewed text as if it were the final agreement
///   would be worse than showing nothing.
/// * **Each purpose stands alone.** Five separate switches, never one "I
///   agree". Withdrawing one leaves the others exactly as they were, and a
///   purpose the account cannot operate without says so rather than silently
///   refusing the toggle.
library;

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/nuvi_api.dart';
import '../theme/nuvi_tokens.dart';
import '../widgets/nuvi_scaffold.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({required this.api, super.key});

  final NuviApi api;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  late Future<List<ConsentSummaryEntry>> _entries;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _entries = widget.api.consentSummary();
  }

  void _reload() {
    setState(() {
      _failure = null;
      _entries = widget.api.consentSummary();
    });
  }

  Future<void> _record(ConsentSummaryEntry entry, bool granted) async {
    try {
      await widget.api.recordConsent(
        purpose: entry.purpose,
        decision: granted ? 'granted' : 'withdrawn',
      );
      _reload();
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() => _failure = exception.detail);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failure = 'We could not save that. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConsentSummaryEntry>>(
      future: _entries,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const NuviPage(
            title: 'Your consent',
            children: [Center(child: CircularProgressIndicator())],
          );
        }

        final entries = snapshot.data ?? const <ConsentSummaryEntry>[];
        final anyDraft = entries.any((entry) => !entry.isPresentable);

        return NuviPage(
          title: 'Your consent',
          children: [
            if (anyDraft)
              const NuviNotice(
                key: Key('consent-draft-banner'),
                emphasis: true,
                icon: Icons.edit_note_outlined,
                message:
                    'DRAFT — this wording has not been approved yet. It is '
                    'placeholder text for development and is not the agreement '
                    'you will be asked to accept.',
              ),
            if (_failure != null)
              NuviNotice(message: _failure!, icon: Icons.error_outline),
            Text(
              'You decide each of these separately, and you can change your '
              'mind at any time.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: NuviSpacing.xl),
            ...entries.map(_tile),
          ],
        );
      },
    );
  }

  Widget _tile(ConsentSummaryEntry entry) {
    final locked = !entry.withdrawable && entry.granted;

    return Card(
      key: Key('consent-${entry.purpose}'),
      margin: const EdgeInsets.only(bottom: NuviSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            value: entry.granted,
            title: Text(entry.label),
            subtitle: Text(
              locked
                  // Said plainly rather than by a disabled control with no
                  // explanation: withdrawing this means closing the account,
                  // which is a different decision and a different flow.
                  ? 'Nuvi cannot run your account without this. To withdraw it, '
                        'close your account.'
                  : entry.isPresentable
                  ? 'Version ${entry.documentVersion ?? '—'}'
                  : 'Draft wording, version ${entry.documentVersion ?? '—'}',
            ),
            onChanged: locked ? null : (value) => _record(entry, value),
          ),
          if (!entry.isPresentable)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NuviSpacing.lg,
                0,
                NuviSpacing.lg,
                NuviSpacing.md,
              ),
              child: Text(
                'Not final — awaiting review.',
                key: Key('consent-draft-${entry.purpose}'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
