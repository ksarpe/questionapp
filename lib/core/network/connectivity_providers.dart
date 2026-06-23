import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/connectivity_service.dart';

/// Live online/offline state, seeded with the current value so the first frame
/// already knows. Defaults to "online" while the first reading resolves so the
/// app never flashes an offline banner on a perfectly good launch.
///
/// Treat this as a HINT for the banner + auto-refresh only; the authoritative
/// signal that a request can't reach the backend is a thrown transport error
/// (see `isOfflineError`). [ConnectivityService] reports the network interface,
/// not real reachability.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  yield await ConnectivityService.isOnline();
  yield* ConnectivityService.onlineStream();
});

/// Convenience: the resolved online flag, optimistically `true` while the stream
/// is still warming up or has errored.
final isOnlineValueProvider = Provider<bool>(
  (ref) => ref.watch(isOnlineProvider).value ?? true,
);
