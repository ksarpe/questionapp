import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';

/// Ergonomic access to the generated [AppLocalizations] from any widget:
/// `context.l10n.signIn` instead of `AppLocalizations.of(context).signIn`.
///
/// The localizations are generated from the ARB files in `lib/l10n/` (the single
/// source of truth for every user-facing string) — run `flutter gen-l10n` after
/// editing them. With `nullable-getter: false` set in `l10n.yaml`, `of` asserts
/// the delegate is present rather than returning null, so this getter is
/// non-nullable; every host that builds these widgets must register
/// [AppLocalizations.delegate] (see `app.dart`, and the test helpers).
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
