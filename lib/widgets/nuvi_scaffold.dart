/// Small shared pieces, so the screens stay about their own logic.
library;

import 'package:flutter/material.dart';

import '../theme/nuvi_tokens.dart';

/// A page with a title, a scrolling body and consistent padding.
class NuviPage extends StatelessWidget {
  const NuviPage({
    required this.title,
    required this.children,
    this.actions,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(NuviSpacing.xl),
          children: children,
        ),
      ),
    );
  }
}

/// An inline message. Monochrome by design: meaning is carried by the icon and
/// the words, not by a colour, which is what keeps the palette honest and the
/// message readable to someone who cannot distinguish red from grey.
class NuviNotice extends StatelessWidget {
  const NuviNotice({
    required this.message,
    this.icon = Icons.info_outline,
    this.emphasis = false,
    super.key,
  });

  final String message;
  final IconData icon;

  /// Draws a heavier border. Used for the draft-copy banner, which must be
  /// hard to skim past.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: NuviSpacing.lg),
      padding: const EdgeInsets.all(NuviSpacing.lg),
      decoration: BoxDecoration(
        color: NuviColors.surfaceMuted,
        borderRadius: BorderRadius.circular(NuviRadius.md),
        border: Border.all(
          color: emphasis ? NuviColors.onSurface : NuviColors.border,
          width: emphasis ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: NuviColors.onSurface),
          const SizedBox(width: NuviSpacing.md),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// A labelled text field with the platform keyboard the value deserves.
class NuviField extends StatelessWidget {
  const NuviField({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.helper,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NuviSpacing.lg),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        autocorrect: !obscure,
        enableSuggestions: !obscure,
        decoration: InputDecoration(labelText: label, helperText: helper),
      ),
    );
  }
}

/// The primary action on a screen, with a busy state that also disables it.
class NuviPrimaryButton extends StatelessWidget {
  const NuviPrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

/// A horizontal progress meter.
///
/// Monochrome, like everything else: the fill is solid ink on a muted track,
/// and how full it is carries the meaning. [fraction] is clamped, so a day
/// that has gone past its target fills the bar rather than overflowing it —
/// the *number* beside the bar is what says by how much, because a bar cannot
/// express "120 %" without a second visual language.
class NuviMeterBar extends StatelessWidget {
  const NuviMeterBar({
    required this.fraction,
    this.height = 8,
    this.semanticLabel,
    super.key,
  });

  final double fraction;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final clamped = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NuviRadius.pill),
        child: LinearProgressIndicator(
          value: clamped,
          minHeight: height,
          backgroundColor: NuviColors.surfaceMuted,
          valueColor: const AlwaysStoppedAnimation<Color>(NuviColors.onSurface),
        ),
      ),
    );
  }
}

/// One macro's name, its consumed-against-target figures and a meter.
class NuviMacroBar extends StatelessWidget {
  const NuviMacroBar({
    required this.label,
    required this.consumed,
    required this.target,
    required this.unit,
    super.key,
  });

  final String label;

  /// Strings, not numbers. The server sends exact decimals and the app renders
  /// them; parsing to a double here would reintroduce the binary rounding the
  /// server avoided. The only place a number is derived is [_fraction], which
  /// feeds a bar and never a displayed figure.
  final String consumed;
  final String target;
  final String unit;

  double get _fraction {
    final consumedValue = double.tryParse(consumed) ?? 0;
    final targetValue = double.tryParse(target) ?? 0;
    if (targetValue <= 0) return 0;
    return consumedValue / targetValue;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NuviSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: NuviColors.onSurfaceMuted),
              ),
              Text(
                '$consumed / $target $unit',
                style: const TextStyle(color: NuviColors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: NuviSpacing.xs),
          NuviMeterBar(fraction: _fraction, semanticLabel: label),
        ],
      ),
    );
  }
}
