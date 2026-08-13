/// Session state.
///
/// One [ChangeNotifier], deliberately, rather than a state-management package:
/// Phase 1 has three screens and no dependency budget to spend on a library
/// that would shape every later decision.
///
/// The one rule this class enforces is the same one the API enforces: **every
/// credential failure produces the same message**. [genericAuthFailure] is the
/// only string the login screen ever shows for a rejected sign-in, whatever
/// the server said, so a helpful error added later cannot reintroduce account
/// enumeration in the UI after the API was careful to avoid it.
library;

import 'package:flutter/foundation.dart';

import '../api/models.dart';
import '../api/nuvi_api.dart';

/// The single message shown for any rejected sign-in.
const String genericAuthFailure =
    'That email address and password combination was not recognised.';

/// Shown when the app cannot reach the API at all. Distinct from a rejected
/// credential, because "we could not reach the server" reveals nothing about
/// any account and a user genuinely needs to know it.
const String networkFailure =
    'We could not reach Nuvi. Check your connection and try again.';

/// Shown when the server rate-limits. Also account-neutral.
const String throttledFailure =
    'Too many attempts. Wait a minute and try again.';

enum SessionStatus { signedOut, working, signedIn }

class Session extends ChangeNotifier {
  // The field is private but the parameter is `api`, which is the name callers
  // should type; an initializing formal would force a private parameter name.
  // ignore: prefer_initializing_formals
  Session({required NuviApi api}) : _api = api;

  final NuviApi _api;

  SessionStatus _status = SessionStatus.signedOut;
  CurrentUser? _user;
  String? _error;

  SessionStatus get status => _status;
  CurrentUser? get user => _user;
  String? get error => _error;
  bool get isBusy => _status == SessionStatus.working;
  bool get isSignedIn => _status == SessionStatus.signedIn;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    return _run(() async {
      await _api.login(email: email, password: password);
      _user = await _api.currentUser();
      _status = SessionStatus.signedIn;
    });
  }

  /// Registration reports the same outcome whether or not the address existed.
  /// The screen that calls this says "check your inbox" either way.
  Future<bool> register({
    required String email,
    required String password,
    String fullName = '',
  }) async {
    return _run(() async {
      await _api.register(email: email, password: password, fullName: fullName);
      _status = SessionStatus.signedOut;
    });
  }

  Future<bool> verifyEmail({
    required String email,
    required String code,
  }) async {
    return _run(() async {
      await _api.verifyEmail(email: email, code: code);
      _status = SessionStatus.signedOut;
    });
  }

  Future<bool> requestPasswordReset({required String email}) async {
    return _run(() async {
      await _api.requestPasswordReset(email: email);
      _status = SessionStatus.signedOut;
    });
  }

  void signOut() {
    _user = null;
    _error = null;
    _status = SessionStatus.signedOut;
    notifyListeners();
  }

  /// Runs [action], mapping every failure onto an account-neutral message.
  Future<bool> _run(Future<void> Function() action) async {
    _status = SessionStatus.working;
    _error = null;
    notifyListeners();

    try {
      await action();
      notifyListeners();
      return true;
    } on ApiException catch (exception) {
      _status = SessionStatus.signedOut;
      _error = exception.isThrottled ? throttledFailure : genericAuthFailure;
      notifyListeners();
      return false;
    } catch (_) {
      // Anything that is not an API response is a transport problem. It is
      // reported as such and never as a credential failure — telling somebody
      // their password is wrong when the network is down is its own bug.
      _status = SessionStatus.signedOut;
      _error = networkFailure;
      notifyListeners();
      return false;
    }
  }
}
