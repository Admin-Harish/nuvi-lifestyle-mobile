/// One member's day: target against consumed, macro bars, water, budget left.
///
/// Read *and* write, which makes it the first screen in the app that changes
/// server state, and three consequences follow from that:
///
/// * **Every write carries an idempotency key**, generated once per tap and
///   reused if the tap is retried. A member on a train tapping "ate it" twice
///   because the first tap seemed not to land must not log two lunches.
/// * **Offline is a distinct state from error.** A [SocketException] means the
///   phone has no route to the server and the right words are "you appear to be
///   offline"; a 500 means something broke and the right words are different.
///   Collapsing them produces the message that tells somebody with full signal
///   to check their connection.
/// * **The screen never computes a nutrition figure.** Macros arrive as exact
///   decimal strings and are rendered as strings. The only arithmetic here is
///   the fraction feeding a progress bar, and it never becomes a displayed
///   number.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/nuvi_api.dart';
import '../theme/nuvi_tokens.dart';
import '../widgets/nuvi_scaffold.dart';

/// What went wrong, at the granularity the copy needs.
enum _Failure { none, offline, refused, other }

_Failure _classify(Object? error) {
  if (error == null) return _Failure.none;
  if (error is SocketException || error is HttpException) {
    return _Failure.offline;
  }
  if (error is ApiException) {
    return error.isForbidden || error.isUnauthorized
        ? _Failure.refused
        : _Failure.other;
  }
  return _Failure.other;
}

class DailyTrackerScreen extends StatefulWidget {
  const DailyTrackerScreen({
    required this.api,
    required this.memberId,
    required this.date,
    super.key,
  });

  final NuviApi api;
  final String memberId;

  /// ISO date. Passed in rather than computed from the device clock: the
  /// server buckets days in the market's timezone, and a phone set to another
  /// zone must not disagree with it about which day "today" is.
  final String date;

  @override
  State<DailyTrackerScreen> createState() => _DailyTrackerScreenState();
}

class _DailyTrackerScreenState extends State<DailyTrackerScreen> {
  late Future<DailySummary> _summary;

  /// The plan item currently being logged, so only its own row shows a spinner.
  String? _pendingPlanItemId;
  bool _pendingWater = false;
  String? _writeError;

  /// One key per logical action, regenerated only after it succeeds. A retry
  /// of the same tap reuses it, so the server absorbs the duplicate.
  final Map<String, String> _idempotencyKeys = <String, String>{};
  int _keyCounter = 0;

  @override
  void initState() {
    super.initState();
    _summary = widget.api.dailySummary(
      memberId: widget.memberId,
      date: widget.date,
    );
  }

  void _reload() {
    setState(() {
      _writeError = null;
      _summary = widget.api.dailySummary(
        memberId: widget.memberId,
        date: widget.date,
      );
    });
  }

  String _keyFor(String action) => _idempotencyKeys.putIfAbsent(
    action,
    () => '${widget.memberId}:${widget.date}:$action:${_keyCounter++}',
  );

  Future<void> _logPlannedMeal(PlannedItem item) async {
    setState(() {
      _pendingPlanItemId = item.planItemId;
      _writeError = null;
    });
    try {
      await widget.api.logIntake(
        memberId: widget.memberId,
        eventType: 'planned_meal',
        occurredAt: '${widget.date}T12:00:00+05:30',
        idempotencyKey: _keyFor('ate:${item.planItemId}'),
        planItemId: item.planItemId,
      );
      _idempotencyKeys.remove('ate:${item.planItemId}');
      if (!mounted) return;
      _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() => _writeError = _messageFor(_classify(error)));
    } finally {
      if (mounted) setState(() => _pendingPlanItemId = null);
    }
  }

  Future<void> _logWater(int millilitres) async {
    setState(() {
      _pendingWater = true;
      _writeError = null;
    });
    try {
      await widget.api.logIntake(
        memberId: widget.memberId,
        eventType: 'water',
        occurredAt: '${widget.date}T12:00:00+05:30',
        idempotencyKey: _keyFor('water:$millilitres:$_keyCounter'),
        waterMl: millilitres,
      );
      _idempotencyKeys.clear();
      if (!mounted) return;
      _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() => _writeError = _messageFor(_classify(error)));
    } finally {
      if (mounted) setState(() => _pendingWater = false);
    }
  }

  String _messageFor(_Failure failure) => switch (failure) {
    _Failure.offline =>
      'You appear to be offline. Nothing was saved — try again once you '
          'have a connection.',
    _Failure.refused => 'You do not have permission to log for this member.',
    _ => 'We could not save that just now. Please try again.',
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DailySummary>(
      future: _summary,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const NuviPage(
            title: 'Today',
            children: [
              Center(
                key: Key('tracker-loading'),
                child: CircularProgressIndicator(),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          final failure = _classify(snapshot.error);
          return NuviPage(
            title: 'Today',
            children: [
              NuviNotice(
                key: Key(
                  failure == _Failure.offline
                      ? 'tracker-offline'
                      : 'tracker-error',
                ),
                message: failure == _Failure.offline
                    ? 'You appear to be offline. Your day will load once you '
                          'have a connection.'
                    : 'We could not load your day just now. Please try again.',
                icon: failure == _Failure.offline
                    ? Icons.wifi_off_outlined
                    : Icons.cloud_off_outlined,
              ),
              const SizedBox(height: NuviSpacing.md),
              NuviPrimaryButton(
                key: const Key('tracker-retry'),
                label: 'Try again',
                onPressed: _reload,
              ),
            ],
          );
        }

        final summary = snapshot.data!;
        return NuviPage(
          title: 'Today',
          children: [
            if (_writeError != null) ...[
              NuviNotice(
                key: const Key('tracker-write-error'),
                message: _writeError!,
                icon: Icons.error_outline,
                emphasis: true,
              ),
            ],
            if (!summary.hasPlan)
              const NuviNotice(
                key: Key('tracker-no-plan'),
                message:
                    'You do not have a plan for this day, so there is no '
                    'target to track against. Anything you log still counts.',
                icon: Icons.event_note_outlined,
              ),
            _BudgetCard(summary: summary),
            const SizedBox(height: NuviSpacing.lg),
            _MacroSection(summary: summary),
            const SizedBox(height: NuviSpacing.lg),
            _WaterCard(
              hydration: summary.hydration,
              busy: _pendingWater,
              onLog: _logWater,
            ),
            const SizedBox(height: NuviSpacing.lg),
            if (summary.planned.isNotEmpty) ...[
              Text('Your plan', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: NuviSpacing.sm),
              for (final item in summary.planned)
                _PlannedRow(
                  item: item,
                  busy: _pendingPlanItemId == item.planItemId,
                  onAte: () => _logPlannedMeal(item),
                ),
            ],
            if (summary.unplanned.isNotEmpty) ...[
              const SizedBox(height: NuviSpacing.lg),
              Text(
                'Logged outside the plan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: NuviSpacing.sm),
              for (final entry in summary.unplanned)
                _UnplannedRow(entry: entry),
            ],
            const SizedBox(height: NuviSpacing.lg),
            Text(
              summary.disclaimer,
              key: const Key('tracker-disclaimer'),
              style: const TextStyle(color: NuviColors.onSurfaceMuted),
            ),
          ],
        );
      },
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('tracker-budget'),
      padding: const EdgeInsets.all(NuviSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: NuviColors.border),
        borderRadius: BorderRadius.circular(NuviRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Energy',
                style: TextStyle(color: NuviColors.onSurfaceMuted),
              ),
              Text(
                '${summary.consumed.energyKcal} / ${summary.target.energyKcal} kcal',
                key: const Key('tracker-consumed'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: NuviColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: NuviSpacing.sm),
          NuviMeterBar(
            fraction: _fraction,
            height: 12,
            semanticLabel: 'Energy consumed against target',
          ),
          const SizedBox(height: NuviSpacing.sm),
          Text(
            summary.isOverBudget
                // The server sends the sign; the app strips it for the copy so
                // the sentence reads "240 over" rather than "-240 left".
                ? '${summary.remaining.energyKcal.replaceFirst('-', '')} kcal over budget'
                : '${summary.remaining.energyKcal} kcal left today',
            key: const Key('tracker-remaining'),
            style: const TextStyle(color: NuviColors.onSurface),
          ),
          if (summary.includesEstimates) ...[
            const SizedBox(height: NuviSpacing.xs),
            const Text(
              'Includes estimated figures for food logged outside your plan.',
              key: Key('tracker-estimate-caveat'),
              style: TextStyle(color: NuviColors.onSurfaceMuted),
            ),
          ],
        ],
      ),
    );
  }

  double get _fraction {
    final consumed = double.tryParse(summary.consumed.energyKcal) ?? 0;
    final target = double.tryParse(summary.target.energyKcal) ?? 0;
    if (target <= 0) return 0;
    return consumed / target;
  }
}

class _MacroSection extends StatelessWidget {
  const _MacroSection({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('tracker-macros'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NuviMacroBar(
          label: 'Protein',
          consumed: summary.consumed.proteinG,
          target: summary.target.proteinG,
          unit: 'g',
        ),
        NuviMacroBar(
          label: 'Carbohydrate',
          consumed: summary.consumed.carbohydrateG,
          target: summary.target.carbohydrateG,
          unit: 'g',
        ),
        NuviMacroBar(
          label: 'Fat',
          consumed: summary.consumed.fatG,
          target: summary.target.fatG,
          unit: 'g',
        ),
        NuviMacroBar(
          label: 'Fibre',
          consumed: summary.consumed.fibreG,
          target: summary.target.fibreG,
          unit: 'g',
        ),
      ],
    );
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({
    required this.hydration,
    required this.busy,
    required this.onLog,
  });

  final Hydration hydration;
  final bool busy;
  final ValueChanged<int> onLog;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('tracker-water'),
      padding: const EdgeInsets.all(NuviSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: NuviColors.border),
        borderRadius: BorderRadius.circular(NuviRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Water',
                style: TextStyle(color: NuviColors.onSurfaceMuted),
              ),
              Text(
                '${hydration.consumedMl} / ${hydration.targetMl} ml',
                key: const Key('tracker-water-figures'),
                style: const TextStyle(color: NuviColors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: NuviSpacing.sm),
          NuviMeterBar(
            fraction: hydration.fraction,
            semanticLabel: 'Water drunk against target',
          ),
          const SizedBox(height: NuviSpacing.md),
          Row(
            children: [
              for (final volume in const [200, 500])
                Padding(
                  padding: const EdgeInsets.only(right: NuviSpacing.sm),
                  child: OutlinedButton(
                    key: Key('tracker-water-add-$volume'),
                    onPressed: busy ? null : () => onLog(volume),
                    child: Text('+$volume ml'),
                  ),
                ),
              if (busy)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    key: Key('tracker-water-busy'),
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlannedRow extends StatelessWidget {
  const _PlannedRow({
    required this.item,
    required this.busy,
    required this.onAte,
  });

  final PlannedItem item;
  final bool busy;
  final VoidCallback onAte;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('planned-${item.planItemId}'),
      margin: const EdgeInsets.only(bottom: NuviSpacing.sm),
      padding: const EdgeInsets.all(NuviSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: NuviColors.border),
        borderRadius: BorderRadius.circular(NuviRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.slotLabel}: ${item.dishName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: NuviColors.onSurface,
                  ),
                ),
                Text(
                  '${item.servingGrams} g · ${item.plannedMacros.energyKcal} kcal',
                  style: const TextStyle(color: NuviColors.onSurfaceMuted),
                ),
                Text(
                  item.basis.label,
                  key: Key('planned-${item.planItemId}-basis'),
                  style: const TextStyle(color: NuviColors.onSurfaceMuted),
                ),
              ],
            ),
          ),
          if (item.basis == AttributionBasis.outstanding)
            busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : OutlinedButton(
                    key: Key('planned-${item.planItemId}-ate'),
                    onPressed: onAte,
                    child: const Text('Ate it'),
                  ),
        ],
      ),
    );
  }
}

class _UnplannedRow extends StatelessWidget {
  const _UnplannedRow({required this.entry});

  final UnplannedItem entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NuviSpacing.xxs),
      child: Text(
        '${entry.label.isEmpty ? entry.eventType : entry.label} — '
        '${entry.macros.energyKcal} kcal'
        '${entry.isEstimate ? ' (estimate)' : ''}',
        key: Key('unplanned-${entry.eventId}'),
        style: const TextStyle(color: NuviColors.onSurface),
      ),
    );
  }
}
