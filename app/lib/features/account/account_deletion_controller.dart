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

class AccountDeletionController extends StateNotifier<AccountDeletionState> {
  AccountDeletionController({
    required AccountDeletionGateway gateway,
    required AppLogger logger,
  })  : _gateway = gateway,
        _logger = logger,
        super(const AccountDeletionIdle());

  final AccountDeletionGateway _gateway;
  final AppLogger _logger;

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
      if (mounted) state = const AccountDeletionFailed();
      return;
    }

    if (!mounted) return;
    state = purgeDueAt == null
        ? const AccountDeletionFailed()
        : AccountDeletionScheduled(purgeDueAt);
  }
}

final accountDeletionGatewayProvider = Provider<AccountDeletionGateway>(
  (ref) => const UnavailableAccountDeletionGateway(),
);

final accountDeletionControllerProvider =
    StateNotifierProvider<AccountDeletionController, AccountDeletionState>(
  (ref) => AccountDeletionController(
    gateway: ref.watch(accountDeletionGatewayProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);
