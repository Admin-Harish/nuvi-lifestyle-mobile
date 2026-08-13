/// Reminder settings: what is off, and what it would take to turn it on.
///
/// The switch here is **not symmetric**, and the asymmetry is the feature:
///
/// * Turning a reminder **off** is one tap and never asks anything.
/// * Turning one **on** requires a named approver, because the server does.
///   `requires_approval_to_enable` arrives on every schedule row and the screen
///   renders that decision rather than making its own.
///
/// The app cannot enable anything by toggling a boolean, because there is no
/// call that would carry one — `enableReminder` takes `approvedBy` as a
/// required argument. This screen is where a pilot operator records who signed
/// off; in the product as shipped, every row reads "off".
library;

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../api/nuvi_api.dart';
import '../theme/nuvi_tokens.dart';
import '../widgets/nuvi_scaffold.dart';
import '../widgets/request_state.dart';

class RemindersSettingsScreen extends StatefulWidget {
  const RemindersSettingsScreen({
    required this.api,
    required this.memberId,
    super.key,
  });

  final NuviApi api;
  final String memberId;

  @override
  State<RemindersSettingsScreen> createState() =>
      _RemindersSettingsScreenState();
}

class _RemindersSettingsScreenState extends State<RemindersSettingsScreen> {
  late Future<List<ReminderSchedule>> _schedules;
  String? _pendingId;
  String? _writeError;

  @override
  void initState() {
    super.initState();
    _schedules = widget.api.reminderSchedules(memberId: widget.memberId);
  }

  void _reload() {
    setState(() {
      _writeError = null;
      _pendingId = null;
      _schedules = widget.api.reminderSchedules(memberId: widget.memberId);
    });
  }

  Future<void> _disable(ReminderSchedule schedule) async {
    setState(() {
      _pendingId = schedule.id;
      _writeError = null;
    });
    try {
      await widget.api.disableReminder(scheduleId: schedule.id);
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

  Future<void> _enable(ReminderSchedule schedule) async {
    final approver = await showDialog<String>(
      context: context,
      builder: (context) => const _ApproverDialog(),
    );
    if (approver == null || approver.trim().isEmpty) return;

    setState(() {
      _pendingId = schedule.id;
      _writeError = null;
    });
    try {
      await widget.api.enableReminder(
        scheduleId: schedule.id,
        approvedBy: approver.trim(),
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
      title: 'Reminders',
      children: [
        if (_writeError != null)
          NuviNotice(message: _writeError!, icon: Icons.error_outline),
        const NuviNotice(
          message:
              'Reminders are off. Turning one on needs a named approver, and '
              'nothing is sent outside 9am–9pm.',
          emphasis: true,
        ),
        NuviAsync<List<ReminderSchedule>>(
          future: _schedules,
          onRetry: _reload,
          loadingLabel: 'Loading your reminders…',
          builder: (context, schedules) {
            if (schedules.isEmpty) {
              return const NuviEmpty(
                message: 'No reminders are set up for this member.',
                icon: Icons.notifications_none,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final schedule in schedules)
                  _ScheduleTile(
                    schedule: schedule,
                    busy: _pendingId == schedule.id,
                    onEnable: _enable,
                    onDisable: _disable,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.schedule,
    required this.busy,
    required this.onEnable,
    required this.onDisable,
  });

  final ReminderSchedule schedule;
  final bool busy;
  final Future<void> Function(ReminderSchedule schedule) onEnable;
  final Future<void> Function(ReminderSchedule schedule) onDisable;

  String get _title => switch (schedule.kind) {
    'meal' =>
      schedule.slot.isEmpty
          ? 'Meal reminder'
          : 'Meal reminder · ${schedule.slot}',
    'hydration' => 'Water reminder',
    'logging' => 'Logging reminder',
    _ => 'Reminder',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('schedule-${schedule.id}'),
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
                  _title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                schedule.isEnabled ? 'On' : 'Off',
                style: const TextStyle(color: NuviColors.onSurfaceMuted),
              ),
            ],
          ),
          const SizedBox(height: NuviSpacing.xs),
          Text(
            'At ${schedule.sendAtLocal}',
            style: const TextStyle(color: NuviColors.onSurfaceMuted),
          ),
          if (schedule.isEnabled && schedule.approvedBy.isNotEmpty)
            Text(
              'Approved by ${schedule.approvedBy}',
              style: const TextStyle(color: NuviColors.onSurfaceMuted),
            ),
          const SizedBox(height: NuviSpacing.md),
          if (schedule.isEnabled)
            OutlinedButton(
              key: Key('disable-${schedule.id}'),
              onPressed: busy ? null : () => onDisable(schedule),
              child: const Text('Turn off'),
            )
          else
            NuviPrimaryButton(
              key: Key('enable-${schedule.id}'),
              label: 'Turn on (needs an approver)',
              busy: busy,
              onPressed: () => onEnable(schedule),
            ),
        ],
      ),
    );
  }
}

/// Collects the approver's name. There is no way past this dialog without one,
/// which mirrors the server's check constraint rather than duplicating it as a
/// client-side rule that could drift.
class _ApproverDialog extends StatefulWidget {
  const _ApproverDialog();

  @override
  State<_ApproverDialog> createState() => _ApproverDialogState();
}

class _ApproverDialogState extends State<_ApproverDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Who is approving this?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Turning on messages to a person is recorded against a name. This '
            'is stored with the schedule.',
          ),
          const SizedBox(height: NuviSpacing.lg),
          NuviField(
            key: const Key('approver-field'),
            label: 'Approver',
            controller: _controller,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('approver-submit'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Turn on'),
        ),
      ],
    );
  }
}
