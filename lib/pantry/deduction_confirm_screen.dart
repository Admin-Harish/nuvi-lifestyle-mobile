/// "Shall I take this out of the pantry?" — the confirm step, as a screen.
///
/// This screen exists because the server refuses to deduct without it. Logging
/// a meal produces a *draft*; nothing changes in the cupboard until somebody
/// answers. The reason is not caution for its own sake: the quantities come
/// from a recipe, and a recipe is a statement about a typical portion rather
/// than a measurement of what came out of this household's jar.
///
/// So the screen shows what it proposes to remove *and* what is currently
/// there, and it offers "not this time" as an equal-weight option rather than
/// a small grey link under a large confirm button.
library;

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/nuvi_api.dart';
import '../theme/nuvi_tokens.dart';
import '../widgets/nuvi_scaffold.dart';
import '../widgets/request_state.dart';

class DeductionConfirmScreen extends StatefulWidget {
  const DeductionConfirmScreen({
    required this.api,
    required this.householdId,
    super.key,
  });

  final NuviApi api;
  final String householdId;

  @override
  State<DeductionConfirmScreen> createState() => _DeductionConfirmScreenState();
}

class _DeductionConfirmScreenState extends State<DeductionConfirmScreen> {
  late Future<List<PantryDeductionProposal>> _proposals;
  String? _pendingId;
  String? _writeError;

  @override
  void initState() {
    super.initState();
    _proposals = widget.api.pantryDeductions(householdId: widget.householdId);
  }

  void _reload() {
    setState(() {
      _writeError = null;
      _pendingId = null;
      _proposals = widget.api.pantryDeductions(householdId: widget.householdId);
    });
  }

  Future<void> _decide(
    PantryDeductionProposal proposal, {
    required bool confirm,
  }) async {
    setState(() {
      _pendingId = proposal.id;
      _writeError = null;
    });
    try {
      if (confirm) {
        await widget.api.confirmPantryDeduction(proposalId: proposal.id);
      } else {
        await widget.api.rejectPantryDeduction(proposalId: proposal.id);
      }
      if (!mounted) return;
      _reload();
    } catch (error) {
      if (!mounted) return;
      final failure = classifyFailure(error);
      if (failure == RequestFailure.conflict) {
        // Someone already answered this proposal. A repeat of the *same* answer
        // came back 200 and reloaded above; this is the *other* answer arriving
        // late. Show the current state rather than a false failure — the
        // proposal is settled and will drop from the list.
        _reload();
        return;
      }
      setState(() {
        _writeError = messageFor(failure);
        _pendingId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return NuviPage(
      title: 'Update the pantry?',
      children: [
        if (_writeError != null)
          NuviNotice(message: _writeError!, icon: Icons.error_outline),
        NuviAsync<List<PantryDeductionProposal>>(
          future: _proposals,
          onRetry: _reload,
          loadingLabel: 'Checking…',
          builder: (context, proposals) {
            if (proposals.isEmpty) {
              return const NuviEmpty(
                message: 'Nothing to confirm right now.',
                icon: Icons.check_circle_outline,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const NuviNotice(
                  message:
                      'These are estimates from the recipe, not a measurement. '
                      'Nothing changes in your pantry unless you say so.',
                ),
                for (final proposal in proposals)
                  _ProposalCard(
                    proposal: proposal,
                    busy: _pendingId == proposal.id,
                    onDecide: _decide,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.busy,
    required this.onDecide,
  });

  final PantryDeductionProposal proposal;
  final bool busy;
  final Future<void> Function(
    PantryDeductionProposal proposal, {
    required bool confirm,
  })
  onDecide;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('proposal-${proposal.id}'),
      margin: const EdgeInsets.only(bottom: NuviSpacing.lg),
      padding: const EdgeInsets.all(NuviSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: NuviColors.border),
        borderRadius: BorderRadius.circular(NuviRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            proposal.summary.isEmpty ? 'A cooked dish' : proposal.summary,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: NuviSpacing.md),
          for (final line in proposal.lines) ...[
            NuviStatRow(
              label: line.itemName,
              value: '−${line.quantity} ${line.unit}',
              emphasis: true,
            ),
            NuviStatRow(
              label: '  currently',
              value: '${line.availableQuantity} ${line.unit}',
            ),
            if (line.exceedsAvailable)
              const Padding(
                padding: EdgeInsets.only(bottom: NuviSpacing.sm),
                child: NuviNotice(
                  message:
                      'This is more than we have recorded. Your records may be '
                      'behind — confirming will simply take it to zero.',
                  icon: Icons.info_outline,
                ),
              ),
          ],
          const SizedBox(height: NuviSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: Key('reject-${proposal.id}'),
                  onPressed: busy
                      ? null
                      : () => onDecide(proposal, confirm: false),
                  child: const Text('Not this time'),
                ),
              ),
              const SizedBox(width: NuviSpacing.md),
              Expanded(
                child: NuviPrimaryButton(
                  key: Key('confirm-${proposal.id}'),
                  label: 'Update pantry',
                  busy: busy,
                  onPressed: () => onDecide(proposal, confirm: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
