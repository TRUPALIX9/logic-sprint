import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Whether the device has a network connection. Offline play is ad-free:
/// no ads, no ad buttons, no revives (hearts wait until you're back online).
///
/// This reports a connected network interface, not proven internet access;
/// ads and the leaderboard still handle a dead connection on their own.
class Network {
  Network() : _connectivity = Connectivity();

  /// Fixed state, for tests and previews.
  Network.fixed(bool online) : _connectivity = null {
    this.online.value = online;
  }

  final Connectivity? _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _changes;

  /// True while a network connection is available.
  final ValueNotifier<bool> online = ValueNotifier(true);

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  /// Reads the current state and follows changes. Safe to call once.
  Future<void> start() async {
    final connectivity = _connectivity;
    if (connectivity == null || _changes != null) {
      return;
    }
    try {
      online.value = _isOnline(await connectivity.checkConnectivity());
      _changes = connectivity.onConnectivityChanged.listen(
        (results) => online.value = _isOnline(results),
      );
    } on Object catch (e) {
      // No plugin (tests) or a platform error: assume online.
      debugPrint('Network: connectivity unavailable: $e');
    }
  }

  void dispose() {
    _changes?.cancel();
    online.dispose();
  }
}
