/// A household's day, one row of totals per member.
///
/// This screen is defined as much by what it cannot show as by what it does.
/// The server sends totals — energy, macros, water — and no dish names, no
/// labels and no allergen tags, because a sibling opening this screen has no
/// business reading what somebody else ate. The wire model
/// ([HouseholdMemberTotals]) has no field to hold that detail, so there is no
/// version of this widget that could render it by accident.
///
/// The roster is likewise the server's decision. A caregiver granted one of two
/// members is sent one row, and this screen shows what it is sent. It does not
/// know the household has a second member, and there is no count here that
/// would hint at one.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/nuvi_api.dart';
import '../theme/nuvi_tokens.dart';
import '../widgets/nuvi_scaffold.dart';

class HouseholdSummaryScreen extends StatefulWidget {
  const HouseholdSummaryScreen({
    required this.api,
    required this.householdId,
    required this.date,
    super.key,
  });

  final NuviApi api;
  final String householdId;

  /// ISO date, supplied rather than read from the device clock — the server
  /// buckets days in the market's timezone.
  final String date;

  @override
  State<HouseholdSummaryScreen> createState() => _HouseholdSummaryScreenState();
}

class _HouseholdSummaryScreenState extends State<HouseholdSummaryScreen> {
  late Future<HouseholdDailySummary> _summary;

  @override
  void initState() {
    super.initState();
    _summary = _load();
  }

  Future<HouseholdDailySummary> _load() => widget.api.householdDailySummary(
    householdId: widget.householdId,
    date: widget.date,
  );

  void _retry() {
    // A block body, not an arrow: `setState(() => _summary = _load())` returns
    // the assignment's value — a Future — and setState asserts on that.
    setState(() {
      _summary = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HouseholdDailySummary>(
      future: _summary,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const NuviPage(
            title: 'Household',
            children: [
              Center(
                key: Key('household-loading'),
                child: CircularProgressIndicator(),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          // Offline is its own state: telling somebody with full signal to
          // check their connection is worse than saying nothing.
          final offline =
              snapshot.error is SocketException ||
              snapshot.error is HttpException;
          return NuviPage(
            title: 'Household',
            children: [
              NuviNotice(
                key: Key(offline ? 'household-offline' : 'household-error'),
                message: offline
                    ? 'You appear to be offline. This will load once you have '
                          'a connection.'
                    : 'We could not load the household summary just now. '
                          'Please try again.',
                icon: offline
                    ? Icons.wifi_off_outlined
                    : Icons.cloud_off_outlined,
              ),
              const SizedBox(height: NuviSpacing.md),
              NuviPrimaryButton(
                key: const Key('household-retry'),
                label: 'Try again',
                onPressed: _retry,
              ),
            ],
          );
        }

        final summary = snapshot.data!;
        if (summary.members.isEmpty) {
          return const NuviPage(
            title: 'Household',
            children: [
              NuviNotice(
                key: Key('household-empty'),
                message:
                    'There is nobody in this household you can see totals '
                    'for yet.',
                icon: Icons.group_outlined,
              ),
            ],
          );
        }

        return NuviPage(
          title: 'Household',
          children: [
            _HouseholdTotalsCard(summary: summary),
            const SizedBox(height: NuviSpacing.lg),
            Text('Each member', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: NuviSpacing.sm),
            for (final member in summary.members) _MemberRow(member: member),
            const SizedBox(height: NuviSpacing.lg),
            Text(
              summary.disclaimer,
              key: const Key('household-disclaimer'),
              style: const TextStyle(color: NuviColors.onSurfaceMuted),
            ),
          ],
        );
      },
    );
  }
}

class _HouseholdTotalsCard extends StatelessWidget {
  const _HouseholdTotalsCard({required this.summary});

  final HouseholdDailySummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('household-totals'),
      padding: const EdgeInsets.all(NuviSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: NuviColors.border),
        borderRadius: BorderRadius.circular(NuviRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.date,
            style: const TextStyle(color: NuviColors.onSurfaceMuted),
          ),
          const SizedBox(height: NuviSpacing.xs),
          Text(
            '${summary.consumed.energyKcal} / ${summary.target.energyKcal} kcal',
            key: const Key('household-energy'),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: NuviColors.onSurface,
            ),
          ),
          Text(
            '${summary.memberCount} '
            '${summary.memberCount == 1 ? 'member' : 'members'} · '
            '${summary.waterConsumedMl} / ${summary.waterTargetMl} ml water',
            key: const Key('household-member-count'),
            style: const TextStyle(color: NuviColors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final HouseholdMemberTotals member;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('household-member-${member.memberReference}'),
      margin: const EdgeInsets.only(bottom: NuviSpacing.sm),
      padding: const EdgeInsets.all(NuviSpacing.md),
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
              Text(
                member.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: NuviColors.onSurface,
                ),
              ),
              Text(
                '${member.consumed.energyKcal} / ${member.target.energyKcal} kcal',
                key: Key('household-member-${member.memberReference}-energy'),
                style: const TextStyle(color: NuviColors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: NuviSpacing.xs),
          NuviMeterBar(
            fraction: _fraction,
            semanticLabel: '${member.displayName} energy against target',
          ),
          const SizedBox(height: NuviSpacing.xs),
          Text(
            member.hasPlan
                ? '${member.hydration.consumedMl} / ${member.hydration.targetMl} ml water'
                : 'No plan for this day',
            style: const TextStyle(color: NuviColors.onSurfaceMuted),
          ),
          if (member.includesEstimates)
            Text(
              'Includes estimates',
              key: Key('household-member-${member.memberReference}-estimates'),
              style: const TextStyle(color: NuviColors.onSurfaceMuted),
            ),
        ],
      ),
    );
  }

  double get _fraction {
    final consumed = double.tryParse(member.consumed.energyKcal) ?? 0;
    final target = double.tryParse(member.target.energyKcal) ?? 0;
    if (target <= 0) return 0;
    return consumed / target;
  }
}
