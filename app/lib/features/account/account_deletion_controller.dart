/// Requesting account deletion from the app (US-015).
///
/// The state machine is small because the interesting decisions are the
/// server's: the grace period, what is erased, what tax law obliges us to
/// keep. This side's job is to make the request once, and to show the user the
/// concrete date the erasure happens rather than a reassuring adjective.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/observability/app_logger.dart';
import '../../core/observability/observability_providers.dart';

sealed class AccountDeletionState {
  const AccountDeletionState();
}

class AccountDeletionIdle extends AccountDeletionState {
  const AccountDeletionIdle();
}

class AccountDeletionInProgress extends AccountDeletionState {
  const AccountDeletionInProgress();
}

class AccountDeletionScheduled extends AccountDeletionState {
  const AccountDeletionScheduled(this.purgeDueAt);

  /// When the data is actually erased. Shown as a date, not "in seven days" —
  /// a date can be checked against a calendar and does not drift if the screen
  /// is reopened a week later.
  final DateTime purgeDueAt;
}

class AccountDeletionFailed extends AccountDeletionState {
  const AccountDeletionFailed();
}

/// Port to the API's deletion endpoint.
///
/// Unimplemented, because the API has no HTTP layer yet: `api/src/main.ts` is
/// a stub. `UnavailableAccountDeletionGateway` is what ships.
abstract interface class AccountDeletionGateway {
  /// Returns when the purge falls due, or null if the request was refused.
  Future<DateTime?> requestDeletion();
}

/// The gateway until the API exists.
///
/// Returns null rather than throwing, so the screen shows its ordinary error
/// state instead of crashing — and so nothing here can be mistaken for a
/// deletion that actually happened. Reporting success without a server would
/// be the worst possible lie for this particular feature.
class UnavailableAccountDeletionGateway implements AccountDeletionGateway {
  const UnavailableAccountDeletionGateway();

  @override
  Future<DateTime?> requestDeletion() async => null;
}

class AccountDeletionController extends Notifier<AccountDeletionState> {
  /// Dependencies are optional so the provider can read them from `ref` in
  /// [build]; a Notifier factory has no ref of its own.
  AccountDeletionController({
    AccountDeletionGateway? gateway,
    AppLogger? logger,
  })  : _injectedGateway = gateway,
        _injectedLogger = logger;

  final AccountDeletionGateway? _injectedGateway;
  final AppLogger? _injectedLogger;

  late AccountDeletionGateway _gateway;
  late AppLogger _logger;

  @override
  AccountDeletionState build() {
    _gateway = _injectedGateway ?? ref.watch(accountDeletionGatewayProvider);
    _logger = _injectedLogger ?? ref.watch(appLoggerProvider);
    return const AccountDeletionIdle();
  }

  Future<void> requestDeletion() async {
    // A second tap while the first request is in flight would schedule nothing
    // twice and confuse the screen. The server is idempotent; the UI should
    // not rely on that to stay coherent.
    if (state is AccountDeletionInProgress) return;
    state = const AccountDeletionInProgress();

    final DateTime? purgeDueAt;
    try {
      purgeDueAt = await _gateway.requestDeletion();
    } catch (_) {
      _logger.warn('account deletion request failed', const {
        'operation': 'account_deletion_request',
      });
      if (ref.mounted) state = const AccountDeletionFailed();
      return;
    }

    if (!ref.mounted) return;
    state = purgeDueAt == null
        ? const AccountDeletionFailed()
        : AccountDeletionScheduled(purgeDueAt);
  }
}

final accountDeletionGatewayProvider = Provider<AccountDeletionGateway>(
  (ref) => const UnavailableAccountDeletionGateway(),
);

final accountDeletionControllerProvider =
    NotifierProvider<AccountDeletionController, AccountDeletionState>(
  AccountDeletionController.new,
);
