/// Trends over a window. Descriptive, never a grade.
///
/// The server refuses to produce a composite score, and this screen refuses to
/// invent one. There is no total, no letter, no "you're doing well" — five
/// separate meters, each labelled with what it measures, and a streak reported
/// as a fact with nothing attached to breaking it.
///
/// Two pieces of restraint worth naming, because both are easy to add later
/// without noticing they were deliberate:
///
/// * **A window without enough logging is not drawn as a trend.**
///   `is_representative` is false below a week, and the screen says "not
///   enough logged yet" instead of rendering four points as a line.
/// * **The household view has no ordering.** Members appear in the order the
///   server sent them, which is by reference, not by any figure. A screen that
///   ranks siblings by adherence is a screen that starts an argument at dinner.
library;

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/nuvi_api.dart';
import '../theme/nuvi_tokens.dart';
import '../widgets/nuvi_scaffold.dart';
import '../widgets/request_state.dart';

double _fraction(String ratio) =>
    double.tryParse(ratio)?.clamp(0.0, 1.0) ?? 0.0;

class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({
    required this.api,
    required this.memberId,
    required this.start,
    required this.end,
    super.key,
  });

  final NuviApi api;
  final String memberId;
  final String start;
  final String end;

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  late Future<MemberProgress> _progress;

  @override
  void initState() {
    super.initState();
    _progress = _load();
  }

  Future<MemberProgress> _load() => widget.api.memberProgress(
    memberId: widget.memberId,
    start: widget.start,
    end: widget.end,
  );

  void _reload() => setState(() => _progress = _load());

  @override
  Widget build(BuildContext context) {
    return NuviPage(
      title: 'Progress',
      children: [
        NuviAsync<MemberProgress>(
          future: _progress,
          onRetry: _reload,
          loadingLabel: 'Working out your trends…',
          builder: (context, progress) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${progress.start} to ${progress.end}',
                  style: const TextStyle(color: NuviColors.onSurfaceMuted),
                ),
                const SizedBox(height: NuviSpacing.lg),
                if (!progress.isRepresentative)
                  const NuviNotice(
                    key: Key('not-representative'),
                    message:
                        'Not enough logged yet to show a trend. A few more days '
                        'and this will start to mean something.',
                    icon: Icons.timeline,
                  ),
                NuviStatRow(
                  label: 'Days logged',
                  value: '${progress.daysLogged} of ${progress.daysInWindow}',
                ),
                NuviStatRow(
                  label: 'Current run of logged days',
                  value: '${progress.loggingStreakDays}',
                ),
                const SizedBox(height: NuviSpacing.lg),
                if (progress.isRepresentative) ...[
                  _TrendBar(
                    label: 'Followed the plan',
                    ratio: progress.trends.adherence,
                  ),
                  _TrendBar(
                    label: 'Met your water target',
                    ratio: progress.trends.hydrationConsistency,
                  ),
                  _TrendBar(
                    label: 'Meals accounted for',
                    ratio: progress.trends.mealRegularity,
                  ),
                  _TrendBar(
                    label: 'Days with an entry',
                    ratio: progress.trends.loggingConsistency,
                  ),
                  _TrendBar(
                    label: 'Days close to plan',
                    ratio: progress.trends.macroConsistency,
                  ),
                ],
                const SizedBox(height: NuviSpacing.lg),
                NuviNotice(message: progress.disclaimer, emphasis: true),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({required this.label, required this.ratio});

  final String label;

  /// A 0–1 string from the server. Parsed only to feed a bar; the parsed value
  /// never becomes a displayed number, the same discipline `NuviMacroBar` uses.
  final String ratio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NuviSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: NuviColors.onSurfaceMuted)),
          const SizedBox(height: NuviSpacing.xs),
          NuviMeterBar(fraction: _fraction(ratio), semanticLabel: label),
        ],
      ),
    );
  }
}

/// The household view: one row per member, totals only.
///
/// The server sends no per-day detail on this endpoint, so this screen cannot
/// show one member's pattern to another even by accident — there is no field
/// on [MemberProgress] here that carries it.
class HouseholdProgressScreen extends StatefulWidget {
  const HouseholdProgressScreen({
    required this.api,
    required this.householdId,
    required this.start,
    required this.end,
    super.key,
  });

  final NuviApi api;
  final String householdId;
  final String start;
  final String end;

  @override
  State<HouseholdProgressScreen> createState() =>
      _HouseholdProgressScreenState();
}

class _HouseholdProgressScreenState extends State<HouseholdProgressScreen> {
  late Future<HouseholdProgress> _progress;

  @override
  void initState() {
    super.initState();
    _progress = _load();
  }

  Future<HouseholdProgress> _load() => widget.api.householdProgress(
    householdId: widget.householdId,
    start: widget.start,
    end: widget.end,
  );

  void _reload() => setState(() => _progress = _load());

  @override
  Widget build(BuildContext context) {
    return NuviPage(
      title: 'Household progress',
      children: [
        NuviAsync<HouseholdProgress>(
          future: _progress,
          onRetry: _reload,
          loadingLabel: 'Loading…',
          builder: (context, progress) {
            if (progress.members.isEmpty) {
              return const NuviEmpty(
                message: 'Nothing to show for this household yet.',
                icon: Icons.people_outline,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final member in progress.members)
                  Container(
                    key: Key('household-member-${member.memberId}'),
                    margin: const EdgeInsets.only(bottom: NuviSpacing.md),
                    padding: const EdgeInsets.all(NuviSpacing.lg),
                    decoration: BoxDecoration(
                      border: Border.all(color: NuviColors.border),
                      borderRadius: BorderRadius.circular(NuviRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          member.memberReference,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: NuviSpacing.sm),
                        NuviStatRow(
                          label: 'Days logged',
                          value:
                              '${member.daysLogged} of ${member.daysInWindow}',
                        ),
                      ],
                    ),
                  ),
                NuviNotice(message: progress.disclaimer, emphasis: true),
              ],
            );
          },
        ),
      ],
    );
  }
}
