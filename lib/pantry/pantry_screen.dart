/// A household's cupboard: what is in it, and what needs using soon.
///
/// Two things this screen deliberately does not do:
///
/// * **It never edits a quantity in place.** Stock is a ledger on the server,
///   and the field a user changes is a *delta* — "used 200 g", "bought 1 kg" —
///   which becomes an adjustment row. A screen with an editable quantity box
///   would invite the client to overwrite a figure it did not compute.
/// * **It never discards anything.** "Use soon" is a list, and the only action
///   next to it is the same adjustment control as everywhere else. Whether food
///   is still good is a judgement about a physical object this app cannot see.
library;

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/nuvi_api.dart';
import '../theme/nuvi_tokens.dart';
import '../widgets/nuvi_scaffold.dart';
import '../widgets/request_state.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({required this.api, required this.householdId, super.key});

  final NuviApi api;
  final String householdId;

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  late Future<List<PantryItem>> _items;
  String? _pendingItemId;
  String? _writeError;

  /// One key per logical adjustment, kept across a retry of that same
  /// adjustment and dropped only once it succeeds — the shape
  /// `daily_tracker_screen.dart` established. Keyed by item *and* the change
  /// itself: a retry of "-50 spoilage" reuses the key (the server absorbs the
  /// duplicate), but a genuinely different change gets a fresh key so it is not
  /// mistaken for a replay — and cannot be rejected as a payload conflict.
  final Map<String, String> _idempotencyKeys = <String, String>{};
  int _keyCounter = 0;

  @override
  void initState() {
    super.initState();
    _items = widget.api.pantryItems(householdId: widget.householdId);
  }

  void _reload() {
    setState(() {
      _writeError = null;
      // Cleared here, not only on failure: a row left marked pending keeps an
      // indeterminate progress bar animating forever after a write succeeds.
      _pendingItemId = null;
      _items = widget.api.pantryItems(householdId: widget.householdId);
    });
  }

  String _keyFor(String action) => _idempotencyKeys.putIfAbsent(
    action,
    () => '${widget.householdId}:$action:${_keyCounter++}',
  );

  Future<void> _adjust(PantryItem item, String delta, String reason) async {
    setState(() {
      _pendingItemId = item.id;
      _writeError = null;
    });
    final action = 'adjust:${item.id}:$delta:$reason';
    try {
      await widget.api.adjustPantryItem(
        itemId: item.id,
        delta: delta,
        reason: reason,
        idempotencyKey: _keyFor(action),
      );
      // Only now the write has landed: drop the key so an identical change made
      // later is a new action, not a replay of this one.
      _idempotencyKeys.remove(action);
      if (!mounted) return;
      _reload();
    } catch (error) {
      // The key is deliberately kept: an explicit retry of this same adjustment
      // must carry the same key so the server recognises it as one write.
      if (!mounted) return;
      setState(() {
        _writeError = messageFor(classifyFailure(error));
        _pendingItemId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return NuviPage(
      title: 'Pantry',
      children: [
        if (_writeError != null)
          NuviNotice(message: _writeError!, icon: Icons.error_outline),
        NuviAsync<List<PantryItem>>(
          future: _items,
          onRetry: _reload,
          loadingLabel: 'Loading your pantry…',
          builder: (context, items) {
            if (items.isEmpty) {
              return const NuviEmpty(
                message:
                    'Nothing recorded yet.\nAdd what you have and the shopping '
                    'list will stop asking you to buy it again.',
                icon: Icons.kitchen_outlined,
              );
            }

            final useSoon = items.where((item) => item.isUseSoon).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (useSoon.isNotEmpty) ...[
                  Text(
                    'Use soon',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: NuviSpacing.sm),
                  const NuviNotice(
                    message:
                        'These are near or past a date you entered. Whether '
                        'they are still good is your call — nothing here throws '
                        'anything away.',
                    icon: Icons.schedule,
                  ),
                  for (final item in useSoon)
                    _PantryTile(
                      item: item,
                      busy: _pendingItemId == item.id,
                      onAdjust: _adjust,
                    ),
                  const SizedBox(height: NuviSpacing.xl),
                ],
                Text(
                  'Everything',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: NuviSpacing.sm),
                for (final item in items)
                  _PantryTile(
                    item: item,
                    busy: _pendingItemId == item.id,
                    onAdjust: _adjust,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PantryTile extends StatelessWidget {
  const _PantryTile({
    required this.item,
    required this.busy,
    required this.onAdjust,
  });

  final PantryItem item;
  final bool busy;
  final Future<void> Function(PantryItem item, String delta, String reason)
  onAdjust;

  String get _dateLine {
    final date = item.soonestDate;
    if (date == null) return '';
    final days = item.daysUntilDate;
    if (days == null) return date;
    if (days < 0) return '$date · ${-days} day(s) ago';
    if (days == 0) return '$date · today';
    return '$date · in $days day(s)';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: NuviSpacing.md),
      padding: const EdgeInsets.all(NuviSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: NuviColors.border),
        borderRadius: BorderRadius.circular(NuviRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text('${item.quantityOnHand} ${item.unit}'),
            ],
          ),
          if (_dateLine.isNotEmpty) ...[
            const SizedBox(height: NuviSpacing.xs),
            Text(
              _dateLine,
              style: const TextStyle(color: NuviColors.onSurfaceMuted),
            ),
          ],
          const SizedBox(height: NuviSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: Key('pantry-used-${item.id}'),
                  onPressed: busy
                      ? null
                      : () => onAdjust(item, '-100', 'other'),
                  child: const Text('Used some'),
                ),
              ),
              const SizedBox(width: NuviSpacing.md),
              Expanded(
                child: OutlinedButton(
                  key: Key('pantry-bought-${item.id}'),
                  onPressed: busy
                      ? null
                      : () => onAdjust(item, '100', 'purchase'),
                  child: const Text('Bought more'),
                ),
              ),
            ],
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: NuviSpacing.md),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}
