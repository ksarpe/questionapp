import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The bits of the build the "About" screen and the settings footer show.
class AppInfo {
  const AppInfo({
    required this.appName,
    required this.version,
    required this.build,
  });

  final String appName;

  /// Marketing version, e.g. `1.0.0` (from `pubspec.yaml`'s `version`).
  final String version;

  /// Build number, e.g. `1` (the `+N` suffix of `version`).
  final String build;
}

/// Resolves the running app's name + version once, from the platform. Read it
/// with `.value` (null while loading or if the platform channel is unavailable,
/// e.g. in tests) so callers can fall back gracefully rather than throwing.
final appInfoProvider = FutureProvider<AppInfo>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppInfo(
    appName: info.appName,
    version: info.version,
    build: info.buildNumber,
  );
});
