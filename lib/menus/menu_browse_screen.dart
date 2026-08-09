/// Browsing a goal's menu library. Read-only.
///
/// Every day shows its own macro rollup, and every dish shows the weight of the
/// serving those macros describe. That pairing is the point: "412 kcal" means
/// nothing without "180 g", and a nutrition screen that shows one without the
/// other is inviting somebody to eat the wrong amount.
///
/// Three rules, the same ones the goal catalogue follows:
///
/// * The server decides what is servable. The app never reads a feature flag,
///   and an empty library is rendered with the server's own reason.
/// * "Awaiting clinical review" and "nothing generated yet" are different
///   messages, because they are different facts.
/// * Macros stay strings end to end. They are exact decimals from the server;
///   parsing them into doubles here would reintroduce the rounding the server
///   avoided.
library;

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/nuvi_api.dart';
import '../theme/nuvi_tokens.dart';
import '../widgets/nuvi_scaffold.dart';

class MenuBrowseScreen extends StatefulWidget {
  const MenuBrowseScreen({required this.api, required this.goalKey, super.key});

  final NuviApi api;
  final String goalKey;

  @override
  State<MenuBrowseScreen> createState() => _MenuBrowseScreenState();
}

class _MenuBrowseScreenState extends State<MenuBrowseScreen> {
  late Future<MenuLibrary> _library;

  @override
  void initState() {
    super.initState();
    _library = widget.api.menuLibrary(goalKey: widget.goalKey);
  }

  void _retry() {
    setState(() {
      _library = widget.api.menuLibrary(goalKey: widget.goalKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MenuLibrary>(
      future: _library,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const NuviPage(
            title: 'Menus',
            children: [
              Center(
                key: Key('menu-loading'),
                child: CircularProgressIndicator(),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return NuviPage(
            title: 'Menus',
            children: [
              const NuviNotice(
                key: Key('menu-error'),
                message:
                    'We could not load these menus just now. Please try again.',
                icon: Icons.cloud_off_outlined,
              ),
              const SizedBox(height: NuviSpacing.md),
              NuviPrimaryButton(
                key: const Key('menu-retry'),
                label: 'Try again',
                onPressed: _retry,
              ),
            ],
          );
        }

        final library = snapshot.data;
        if (library == null || library.isEmpty) {
          return NuviPage(
            title: 'Menus',
            children: [_emptyNotice(library)],
          );
        }

        return NuviPage(
          title: 'Menus',
          children: [
            Text(
              '${library.days.length} days',
              key: const Key('menu-day-count'),
              style: const TextStyle(color: NuviColors.onSurfaceMuted),
            ),
            const SizedBox(height: NuviSpacing.md),
            for (final day in library.days) _MenuDayCard(day: day),
          ],
        );
      },
    );
  }

  Widget _emptyNotice(MenuLibrary? library) {
    final reason = library?.emptyReason ?? MenuLibraryEmptyReason.notGenerated;
    return switch (reason) {
      // Deliberately not "unavailable". The content exists; a clinician has not
      // signed the protocol off yet, and saying so is both true and kinder than
      // implying the product does not support the condition.
      MenuLibraryEmptyReason.flagOff => const NuviNotice(
        key: Key('menu-empty-gated'),
        message:
            'Menus for this goal are awaiting clinical review. They will '
            'appear here once a clinician has approved them.',
        icon: Icons.medical_information_outlined,
      ),
      MenuLibraryEmptyReason.notGenerated => const NuviNotice(
        key: Key('menu-empty-none'),
        message: 'There are no menus for this goal yet.',
        icon: Icons.restaurant_menu_outlined,
      ),
      MenuLibraryEmptyReason.none => const NuviNotice(
        key: Key('menu-empty-none'),
        message: 'There are no menus for this goal yet.',
        icon: Icons.restaurant_menu_outlined,
      ),
    };
  }
}

class _MenuDayCard extends StatelessWidget {
  const _MenuDayCard({required this.day});

  final MenuDay day;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('menu-day-${day.dayIndex}'),
      margin: const EdgeInsets.only(bottom: NuviSpacing.md),
      padding: const EdgeInsets.all(NuviSpacing.md),
      decoration: BoxDecoration(
        color: NuviColors.surface,
        border: Border.all(color: NuviColors.border),
        borderRadius: BorderRadius.circular(NuviRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day ${day.dayIndex}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: NuviColors.onSurface,
            ),
          ),
          const SizedBox(height: NuviSpacing.xs),
          Text(
            day.macros.summary,
            key: Key('menu-day-${day.dayIndex}-macros'),
            style: const TextStyle(color: NuviColors.onSurfaceMuted),
          ),
          if (day.allergenTags.isNotEmpty) ...[
            const SizedBox(height: NuviSpacing.xs),
            Text(
              'Contains: ${day.allergenTags.join(', ')}',
              key: Key('menu-day-${day.dayIndex}-allergens'),
              style: const TextStyle(color: NuviColors.onSurfaceMuted),
            ),
          ],
          const SizedBox(height: NuviSpacing.sm),
          for (final dish in day.dishes) _DishRow(dish: dish),
        ],
      ),
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({required this.dish});

  final MenuDish dish;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // One label per dish so a screen reader announces the food, the amount
      // and the energy together rather than as three loose fragments.
      label:
          '${dish.slotLabel}: ${dish.dishName}, '
          '${dish.servingGrams} grams, ${dish.macros.energyKcal} kilocalories',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: NuviSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dish.slotLabel,
              style: const TextStyle(
                fontSize: 12,
                color: NuviColors.onSurfaceMuted,
              ),
            ),
            Text(
              dish.dishName,
              style: const TextStyle(color: NuviColors.onSurface),
            ),
            Text(
              '${dish.servingGrams} g · ${dish.macros.summary}',
              key: Key('dish-${dish.slot}-detail'),
              style: const TextStyle(
                fontSize: 12,
                color: NuviColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
