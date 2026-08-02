import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has a network path.
///
/// This is reachability, not connectivity to our API — a captive portal or a
/// dead backend both report [online]. It is accurate enough to decide whether to
/// warn the user, and deliberately not used to decide whether a request will
/// succeed. Requests fail on their own and are handled where they are made.
enum NetworkStatus { online, offline }

/// Tracks the device's network reachability.
///
/// Starts [NetworkStatus.online]. An app that flashes an offline banner during
/// the first frame of every cold start, before the platform has answered, trains
/// users to ignore the banner — so the pessimistic default is the wrong one here.
class ConnectivityController extends StateNotifier<NetworkStatus> {
  ConnectivityController({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity(),
        super(NetworkStatus.online) {
    _start();
  }

  /// A controller pinned to [status] that never touches the platform channel.
  ///
  /// For tests and for previews. Subscribing to real connectivity in a widget
  /// test produces async platform errors unrelated to what is being tested.
  ConnectivityController.fixed(super.status) : _connectivity = null;

  final Connectivity? _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<void> _start() async {
    final connectivity = _connectivity;
    if (connectivity == null) return;
    _subscription = connectivity.onConnectivityChanged.listen(_handle);
    try {
      _handle(await connectivity.checkConnectivity());
    } on Object {
      // A platform channel failure must not take the app down; staying on the
      // optimistic default degrades to "no banner", which is safe.
    }
  }

  void _handle(List<ConnectivityResult> results) {
    if (!mounted) return;
    // `none` alone means no path. An empty list is what some platforms report
    // before they have an answer, and is not evidence of being offline.
    final offline = results.isNotEmpty &&
        results.every((r) => r == ConnectivityResult.none);
    state = offline ? NetworkStatus.offline : NetworkStatus.online;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final connectivityControllerProvider =
    StateNotifierProvider<ConnectivityController, NetworkStatus>(
  (ref) => ConnectivityController(),
);
