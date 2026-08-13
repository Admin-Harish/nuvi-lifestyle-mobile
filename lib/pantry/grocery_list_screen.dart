/// The shopping list, reconciled against the cupboard.
///
/// Three figures per grocery, and the screen shows all three rather than only
/// the one you shop from. "Buy 60 g" on its own is a number to be trusted or
/// not; "needs 100, you have 40, buy 60" is a number that can be checked
/// against a cupboard, which is the difference between a list somebody follows
/// and one they stop believing.
///
/// Per-member lines are rendered under each grocery and never summed into a
/// single anonymous figure. Two members' shares of the same ingredient stop
/// being interchangeable the moment one of them has an allergy the other does
/// not, and the goal and excluded allergens travel with the line so the list
/// stays checkable per person.
///
/// The on-hand figure is **not** broken down per member, because the server
/// does not send one: a shared cupboard has no owner, and an invented
/// allocation would sit next to four measured numbers looking just as real.
library;

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/nuvi_api.dart';
import '../theme/nuvi_tokens.dart';
import '../widgets/nuvi_scaffold.dart';
import '../widgets/request_state.dart';

class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({
    required this.api,
    required this.householdId,
    required this.start,
    required this.end,
    super.key,
  });

  final NuviApi api;
  final String householdId;

  /// ISO dates, passed in rather than computed from the device clock: the
  /// server buckets days in the market's timezone and a phone set to another
  /// zone must not disagree with it about which week this is.
  final String start;
  final String end;

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  late Future<GroceryReconciliation> _reconciliation;

  @override
  void initState() {
    super.initState();
    _reconciliation = _load();
  }

  Future<GroceryReconciliation> _load() => widget.api.groceryReconciliation(
    householdId: widget.householdId,
    start: widget.start,
    end: widget.end,
  );

  void _reload() => setState(() => _reconciliation = _load());

  @override
  Widget build(BuildContext context) {
    return NuviPage(
      title: 'Shopping list',
      children: [
        NuviAsync<GroceryReconciliation>(
          future: _reconciliation,
          onRetry: _reload,
          loadingLabel: 'Working out what you need…',
          builder: (context, data) {
            if (data.groceries.isEmpty) {
              return const NuviEmpty(
                message:
                    'No plans cover these dates yet, so there is nothing to '
                    'shop for.',
                icon: Icons.shopping_basket_outlined,
              );
            }

            final toBuy = data.toBuy;
            final covered = data.alreadyCovered;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NuviNotice(message: data.disclaimer, emphasis: true),
                if (data.useSoon.isNotEmpty)
                  NuviNotice(
                    message:
                        'Use soon: ${data.useSoon.join(', ')}. Worth cooking '
                        'with before you buy more.',
                    icon: Icons.schedule,
                  ),
                Text('To buy', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: NuviSpacing.sm),
                if (toBuy.isEmpty)
                  const NuviEmpty(
                    message:
                        'Nothing to buy — the cupboard already covers these '
                        'plans.',
                    icon: Icons.check_circle_outline,
                  )
                else
                  for (final grocery in toBuy) _GroceryTile(grocery: grocery),
                if (covered.isNotEmpty) ...[
                  const SizedBox(height: NuviSpacing.xl),
                  Text(
                    'Already covered',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: NuviSpacing.sm),
                  for (final grocery in covered) _GroceryTile(grocery: grocery),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GroceryTile extends StatelessWidget {
  const _GroceryTile({required this.grocery});

  final ReconciledGrocery grocery;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('grocery-${grocery.canonicalKey}'),
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
            grocery.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: NuviSpacing.sm),
          NuviStatRow(label: 'Needed', value: '${grocery.requiredGrams} g'),
          NuviStatRow(label: 'Already have', value: '${grocery.onHandGrams} g'),
          NuviStatRow(
            label: 'Buy',
            value: '${grocery.netToBuyGrams} g',
            emphasis: true,
          ),
          if (grocery.unconvertible.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: NuviSpacing.sm),
              child: NuviNotice(
                message:
                    'You also have ${grocery.unconvertible.map((u) => '${u.quantity} ${u.unit}').join(', ')} '
                    'of this, which we could not weigh, so it is not counted '
                    'above. You may need less than shown.',
                icon: Icons.help_outline,
              ),
            ),
          if (grocery.members.isNotEmpty) ...[
            const SizedBox(height: NuviSpacing.md),
            const Divider(height: 1, color: NuviColors.border),
            const SizedBox(height: NuviSpacing.sm),
            Text(
              "Who it's for",
              style: const TextStyle(color: NuviColors.onSurfaceMuted),
            ),
            for (final line in grocery.members)
              Padding(
                padding: const EdgeInsets.only(top: NuviSpacing.xs),
                child: Text(
                  '${line.memberReference}: ${line.grams} g'
                  '${line.excludedAllergenTags.isEmpty ? '' : ' · avoids ${line.excludedAllergenTags.join(', ')}'}',
                ),
              ),
          ],
        ],
      ),
    );
  }
}
