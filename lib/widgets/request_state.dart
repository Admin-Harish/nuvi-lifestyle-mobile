/// Loading, error and offline states, in one place.
///
/// `daily_tracker_screen.dart` established the rule this module generalises:
/// **offline is a distinct state from error.** A [SocketException] means the
/// phone has no route to the server and the right words are "you appear to be
/// offline"; a 500 means something broke and the right words are different.
/// Collapsing them produces the message that tells somebody with full signal to
/// check their connection.
///
/// Phase 4 adds five screens that each need the same four states, and five
/// copies of the classification is five places for one of them to start showing
/// the wrong message.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../api/nuvi_api.dart';
import '../theme/nuvi_tokens.dart';
import 'nuvi_scaffold.dart';

/// What went wrong, at the granularity the copy needs.
enum RequestFailure {
  none,

  /// No route to the server. The user's connection, not our fault.
  offline,

  /// 401 or 403. The server declined; retrying will not help.
  refused,

  /// 409. The write conflicts with the current state — a key reused with a
  /// different payload, or a decision against an already-decided object.
  /// Retrying the same request cannot win, so the screen shows current state
  /// rather than inviting a retry.
  conflict,

  /// Anything else.
  other,
}

RequestFailure classifyFailure(Object? error) {
  if (error == null) return RequestFailure.none;
  if (error is SocketException || error is HttpException) {
    return RequestFailure.offline;
  }
  if (error is ApiException) {
    if (error.isForbidden || error.isUnauthorized) {
      return RequestFailure.refused;
    }
    if (error.isConflict) return RequestFailure.conflict;
    return RequestFailure.other;
  }
  return RequestFailure.other;
}

String messageFor(RequestFailure failure) => switch (failure) {
  RequestFailure.offline =>
    'You appear to be offline. Your data is safe; this screen will fill in '
        'once you have a connection.',
  RequestFailure.refused =>
    'You do not have access to this. If that seems wrong, ask whoever manages '
        'your household.',
  RequestFailure.conflict =>
    'This was already updated, so nothing changed just now. The latest is '
        'shown above.',
  RequestFailure.other =>
    'Something went wrong loading this. Please try again.',
  RequestFailure.none => '',
};

/// A [FutureBuilder] that renders the four states consistently.
///
/// [onRetry] is required for every failure except [RequestFailure.refused] and
/// [RequestFailure.conflict], where a retry button would invite somebody to
/// hammer an endpoint that is never going to say yes (refused) or whose answer
/// has already moved on (conflict).
class NuviAsync<T> extends StatelessWidget {
  const NuviAsync({
    required this.future,
    required this.builder,
    required this.onRetry,
    this.loadingLabel = 'Loading…',
    super.key,
  });

  final Future<T> future;
  final Widget Function(BuildContext context, T value) builder;
  final VoidCallback onRetry;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: NuviSpacing.xxl),
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: NuviSpacing.lg),
                Text(
                  loadingLabel,
                  style: const TextStyle(color: NuviColors.onSurfaceMuted),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          final failure = classifyFailure(snapshot.error);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NuviNotice(
                message: messageFor(failure),
                icon: failure == RequestFailure.offline
                    ? Icons.cloud_off
                    : Icons.error_outline,
              ),
              if (failure != RequestFailure.refused &&
                  failure != RequestFailure.conflict)
                NuviPrimaryButton(label: 'Try again', onPressed: onRetry),
            ],
          );
        }

        return builder(context, snapshot.data as T);
      },
    );
  }
}

/// An empty state that says what would fill it, rather than just "nothing".
class NuviEmpty extends StatelessWidget {
  const NuviEmpty({required this.message, this.icon = Icons.inbox, super.key});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NuviSpacing.xxl),
      child: Column(
        children: [
          Icon(icon, size: 32, color: NuviColors.onSurfaceMuted),
          const SizedBox(height: NuviSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: NuviColors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

/// A label/value row, used by every Phase 4 screen for its figures.
class NuviStatRow extends StatelessWidget {
  const NuviStatRow({
    required this.label,
    required this.value,
    this.emphasis = false,
    super.key,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NuviSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: NuviColors.onSurfaceMuted),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: NuviColors.onSurface,
              fontWeight: emphasis ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
