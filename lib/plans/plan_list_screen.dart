/// A member's issued meal plans, and one plan in detail. Read-only.
///
/// A plan is a record of advice already given, so nothing here edits one. The
/// detail view shows the exclusions the plan was built against, because "why is
/// there no dairy in this?" is a question somebody will ask months later and the
/// answer should be on the plan rather than in a support ticket.
library;

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/nuvi_api.dart';
import '../theme/nuvi_tokens.dart';
import '../widgets/nuvi_scaffold.dart';

class PlanListScreen extends StatefulWidget {
  const PlanListScreen({required this.api, super.key});

  final NuviApi api;

  @override
  State<PlanListScreen> createState() => _PlanListScreenState();
}

class _PlanListScreenState extends State<PlanListScreen> {
  late Future<List<MealPlanSummary>> _plans;

  @override
  void initState() {
    super.initState();
    _plans = widget.api.mealPlans();
  }

  void _retry() {
    setState(() {
      _plans = widget.api.mealPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MealPlanSummary>>(
      future: _plans,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const NuviPage(
            title: 'Plans',
            children: [
              Center(
                key: Key('plans-loading'),
                child: CircularProgressIndicator(),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return NuviPage(
            title: 'Plans',
            children: [
              const NuviNotice(
                key: Key('plans-error'),
                message:
                    'We could not load your plans just now. Please try again.',
                icon: Icons.cloud_off_outlined,
              ),
              const SizedBox(height: NuviSpacing.md),
              NuviPrimaryButton(
                key: const Key('plans-retry'),
                label: 'Try again',
                onPressed: _retry,
              ),
            ],
          );
        }

        final plans = snapshot.data ?? const <MealPlanSummary>[];
        if (plans.isEmpty) {
          return const NuviPage(
            title: 'Plans',
            children: [
              NuviNotice(
                key: Key('plans-empty'),
                message:
                    'You do not have a meal plan yet. One will appear here '
                    'once your dietitian assigns it.',
                icon: Icons.event_note_outlined,
              ),
            ],
          );
        }

        return NuviPage(
          title: 'Plans',
          children: [for (final plan in plans) _PlanRow(plan: plan)],
        );
      },
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan});

  final MealPlanSummary plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('plan-${plan.reference}'),
      margin: const EdgeInsets.only(bottom: NuviSpacing.sm),
      padding: const EdgeInsets.all(NuviSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: NuviColors.border),
        borderRadius: BorderRadius.circular(NuviRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.reference,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: NuviColors.onSurface,
            ),
          ),
          const SizedBox(height: NuviSpacing.xxs),
          Text(
            '${plan.goalKey} · ${plan.startsOn} to ${plan.endsOn}',
            style: const TextStyle(color: NuviColors.onSurfaceMuted),
          ),
          Text(
            plan.status,
            key: Key('plan-${plan.reference}-status'),
            style: const TextStyle(color: NuviColors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

/// One plan, day by day.
class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({required this.api, required this.planId, super.key});

  final NuviApi api;
  final String planId;

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  late Future<MealPlanDetail> _plan;

  @override
  void initState() {
    super.initState();
    _plan = widget.api.mealPlan(id: widget.planId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MealPlanDetail>(
      future: _plan,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const NuviPage(
            title: 'Plan',
            children: [
              Center(
                key: Key('plan-detail-loading'),
                child: CircularProgressIndicator(),
              ),
            ],
          );
        }
        if (snapshot.hasError) {
          return const NuviPage(
            title: 'Plan',
            children: [
              NuviNotice(
                key: Key('plan-detail-error'),
                message:
                    'We could not load this plan just now. Please try again.',
                icon: Icons.cloud_off_outlined,
              ),
            ],
          );
        }

        final plan = snapshot.data!;
        return NuviPage(
          title: 'Plan',
          children: [
            Text(
              plan.summary.reference,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              plan.macros.summary,
              key: const Key('plan-detail-macros'),
              style: const TextStyle(color: NuviColors.onSurfaceMuted),
            ),
            if (plan.excludedAllergenTags.isNotEmpty) ...[
              const SizedBox(height: NuviSpacing.xs),
              Text(
                'Built avoiding: ${plan.excludedAllergenTags.join(', ')}',
                key: const Key('plan-detail-exclusions'),
                style: const TextStyle(color: NuviColors.onSurfaceMuted),
              ),
            ],
            const SizedBox(height: NuviSpacing.md),
            for (final day in plan.days) _PlanDayCard(day: day),
          ],
        );
      },
    );
  }
}

class _PlanDayCard extends StatelessWidget {
  const _PlanDayCard({required this.day});

  final MenuDay day;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('plan-day-${day.dayIndex}'),
      margin: const EdgeInsets.only(bottom: NuviSpacing.md),
      padding: const EdgeInsets.all(NuviSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: NuviColors.border),
        borderRadius: BorderRadius.circular(NuviRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day ${day.dayIndex}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            day.macros.summary,
            key: Key('plan-day-${day.dayIndex}-macros'),
            style: const TextStyle(color: NuviColors.onSurfaceMuted),
          ),
          const SizedBox(height: NuviSpacing.sm),
          for (final dish in day.dishes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: NuviSpacing.xxs),
              child: Text(
                '${dish.slotLabel}: ${dish.dishName} — '
                '${dish.servingGrams} g, ${dish.macros.energyKcal} kcal',
                key: Key('plan-day-${day.dayIndex}-${dish.slot}'),
                style: const TextStyle(color: NuviColors.onSurface),
              ),
            ),
        ],
      ),
    );
  }
}
