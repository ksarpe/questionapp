import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper over `connectivity_plus`, reduced to a single boolean: is there
/// any network interface up?
///
/// This is a HINT, not proof of reachability — the OS can report Wi-Fi while the
/// router has no uplink — so the app still treats a failed request as the real
/// offline signal (see `isOfflineError`). What this gives us cheaply is the
/// "offline" banner and an auto-refresh trigger the moment a connection returns.
class ConnectivityService {
  ConnectivityService._();

  static final Connectivity _connectivity = Connectivity();

  /// Emits `true` whenever at least one network interface is available, `false`
  /// when all are gone. connectivity_plus v6 reports a LIST of results (a device
  /// can be on Wi-Fi and mobile at once), so we collapse it to "any non-none".
  static Stream<bool> onlineStream() =>
      _connectivity.onConnectivityChanged.map(_isOnline);

  /// A one-shot read of the current connectivity, for the initial banner state.
  static Future<bool> isOnline() async =>
      _isOnline(await _connectivity.checkConnectivity());

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
