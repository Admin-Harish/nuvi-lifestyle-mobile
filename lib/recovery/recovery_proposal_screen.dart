/// A recovery suggestion, and three equally-weighted ways to answer it.
///
/// The three buttons are deliberately the same size. "Carry on as I am" is not
/// a dismissal hidden under a large accept — it is the right answer to most of
/// these, and a screen that treats it as a decline to be re-prompted is one
/// that nags somebody about a difficult week.
///
/// The screen shows the **envelope alongside the advice**: the floor and the
/// ceiling the draft respected, and the part of the shortfall it deliberately
/// did not make up. A suggestion shown without its limits asks to be trusted;
/// one shown with them can be checked.
///
/// When the member's goal is clinically gated the server sends a referral and
/// no numbers, and this screen renders exactly that — no adjustments, no
/// accept button, and the reason in the server's own words.
library;

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/nuvi_api.dart';
import '../theme/nuvi_tokens.dart';
import '../widgets/nuvi_scaffold.dart';
import '../widgets/request_state.dart';

class RecoveryProposalScreen extends StatefulWidget {
  const RecoveryProposalScreen({
    required this.api,
    required this.memberId,
    super.key,
  });

  final NuviApi api;
  final String memberId;

  @override
  State<RecoveryProposalScreen> createState() => _RecoveryProposalScreenState();
}

class _RecoveryProposalScreenState extends State<RecoveryProposalScreen> {
  late Future<List<RecoveryProposal>> _proposals;
  String? _pendingId;
  String? _writeError;

  @override
  void initState() {
    super.initState();
    _proposals = widget.api.recoveryProposals(memberId: widget.memberId);
  }

  void _reload() {
    setState(() {
      _writeError = null;
      _pendingId = null;
      _proposals = widget.api.recoveryProposals(memberId: widget.memberId);
    });
  }

  Future<void> _decide(RecoveryProposal proposal, String decision) async {
    setState(() {
      _pendingId = proposal.id;
      _writeError = null;
    });
    try {
      await widget.api.decideRecovery(
        proposalId: proposal.id,
        decision: decision,
      );
      if (!mounted) return;
      _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _writeError = messageFor(classifyFailure(error));
        _pendingId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return NuviPage(
      title: 'A suggestion',
      children: [
        if (_writeError != null)
          NuviNotice(message: _writeError!, icon: Icons.error_outline),
        NuviAsync<List<RecoveryProposal>>(
          future: _proposals,
          onRetry: _reload,
          loadingLabel: 'Checking…',
          builder: (context, proposals) {
            if (proposals.isEmpty) {
              return const NuviEmpty(
                message: 'Nothing to suggest. Your plan is unchanged.',
                icon: Icons.check_circle_outline,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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

  final RecoveryProposal proposal;
  final bool busy;
  final Future<void> Function(RecoveryProposal proposal, String decision)
  onDecide;

  @override
  Widget build(BuildContext context) {
    if (proposal.needsClinician) {
      return Container(
        key: Key('referral-${proposal.id}'),
        padding: const EdgeInsets.all(NuviSpacing.lg),
        decoration: BoxDecoration(
          border: Border.all(color: NuviColors.onSurface, width: 2),
          borderRadius: BorderRadius.circular(NuviRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This one needs a professional',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: NuviSpacing.sm),
            Text(proposal.referral?.reason ?? proposal.rationale),
          ],
        ),
      );
    }

    return Container(
      key: Key('recovery-${proposal.id}'),
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
            'About ${proposal.triggerDate}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: NuviSpacing.sm),
          Text(proposal.rationale),
          const SizedBox(height: NuviSpacing.lg),
          if (proposal.adjustments.isEmpty)
            const NuviNotice(
              message: 'No change to the days ahead is suggested.',
            )
          else
            for (final adjustment in proposal.adjustments)
              NuviStatRow(
                label: adjustment.day,
                value:
                    '${adjustment.originalTargetKcal} → '
                    '${adjustment.proposedTargetKcal} kcal',
              ),
          const SizedBox(height: NuviSpacing.md),
          const Divider(height: 1, color: NuviColors.border),
          const SizedBox(height: NuviSpacing.sm),
          NuviStatRow(
            label: 'Never goes below',
            value: '${proposal.floorKcal} kcal',
          ),
          NuviStatRow(
            label: 'Never goes above',
            value: '${proposal.ceilingKcal} kcal',
          ),
          NuviStatRow(
            label: 'Not made up',
            value: '${proposal.unrecoveredKcal} kcal',
          ),
          const SizedBox(height: NuviSpacing.lg),
          // Three equal buttons. See the library docstring.
          NuviPrimaryButton(
            key: Key('accept-${proposal.id}'),
            label: 'Use this suggestion',
            busy: busy,
            onPressed: () => onDecide(proposal, 'accept'),
          ),
          const SizedBox(height: NuviSpacing.sm),
          OutlinedButton(
            key: Key('override-${proposal.id}'),
            onPressed: busy ? null : () => onDecide(proposal, 'override'),
            child: const Text('Carry on as I am'),
          ),
          const SizedBox(height: NuviSpacing.sm),
          OutlinedButton(
            key: Key('replace-${proposal.id}'),
            onPressed: busy ? null : () => onDecide(proposal, 'replace'),
            child: const Text("I'll do my own thing"),
          ),
        ],
      ),
    );
  }
}
