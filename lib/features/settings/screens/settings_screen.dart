import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/feedback/app_toast.dart';
import '../../../core/locale/app_locale.dart';
import '../../../core/locale/l10n_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/sub_screen_chrome.dart';
import '../../../data/models/question.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../services/notification_service.dart';
import '../../../services/reminder_scheduler.dart';
import '../../../services/purchases_service.dart';
import '../../../services/supabase_service.dart';
import '../../account/providers/session_providers.dart';
import '../../account/screens/auth_screen.dart';
import '../../onboarding/widgets/spark_logo.dart';
import '../../questions/providers/favorites_providers.dart';
import '../../questions/widgets/history_screen.dart';
import '../../questions/widgets/share_question_button.dart';
import '../providers/app_info_provider.dart';
import '../providers/reminder_providers.dart';
import '../widgets/account_action_buttons.dart';
import '../widgets/manage_subscription_sheet.dart';
import '../widgets/offline_download_row.dart';
import '../widgets/premium_active_row.dart';
import '../widgets/profile_header.dart';
import '../widgets/rank_card.dart';
import '../widgets/settings_nav_row.dart';
import '../widgets/settings_primitives.dart';
import '../widgets/settings_toggle_row.dart';
import '../widgets/streak_card.dart';

/// The signed-in user's profile hub: identity, gamification stats, app
/// preferences, subscription and account actions — all on one scrollable page.
///
/// Reached by tapping the person icon in the top-right of [QuestionScreen].
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  /// True while the user turned the reminder on but the OS hadn't granted the
  /// permission yet and we sent them to system settings. When they return with
  /// it granted, [_syncReminderToggle] finishes the enable without a second tap.
  bool _pendingEnable = false;

  /// True while a sign-out is in flight, so the button shows a spinner and
  /// can't be tapped twice (a slow global token revoke can take a moment).
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // After the first frame (context + providers ready), reconcile the stored
    // switch with the real OS permission — it may have been revoked elsewhere.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncReminderToggle());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check on return to the foreground — typically back from the system
    // notification settings the "Open settings" action opened.
    if (state == AppLifecycleState.resumed) _syncReminderToggle();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(sessionProvider).value;
    final hasAccount = account?.hasAccount ?? false;
    final isPremium = account?.isPremium ?? false;
    final localeCode = ref.watch(localeControllerProvider).languageCode;
    final reminder = ref.watch(reminderControllerProvider);
    final themeMode = ref.watch(themeControllerProvider);
    final appInfo = ref.watch(appInfoProvider).value;

    // Favorites entry: shown to premium (the feature is theirs) and to anyone
    // who still has saved questions — a lapsed-premium user keeps access to the
    // list they built (favorites are readable forever).
    final favoriteCount = ref.watch(favoriteIdsProvider).value?.length ?? 0;
    final showFavorites = isPremium || favoriteCount > 0;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          // Faint orange glow bleeding down from the top, behind the header.
          const TopGlow(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProfileHeader(
                        account: account,
                        hasAccount: hasAccount,
                        onClose: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 24),

                      // ---- Stats (live from sync_user_state) --------------
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: const [
                            Expanded(child: StreakCard()),
                            SizedBox(width: 14),
                            Expanded(child: RankCard()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ---- App settings -----------------------------------
                      SettingsSectionLabel(context.l10n.settingsSectionApp),
                      const SizedBox(height: 12),
                      SettingsCard(
                        children: [
                          SettingsToggleRow(
                            icon: Icons.notifications_none_rounded,
                            title: context.l10n.settingsReminders,
                            subtitle: context.l10n.settingsRemindersSubtitle,
                            value: reminder.enabled,
                            onChanged: _onReminderToggled,
                          ),
                          if (reminder.enabled) ...[
                            const SettingsRowDivider(),
                            SettingsNavRow(
                              icon: Icons.schedule_rounded,
                              title: context.l10n.settingsReminderTime,
                              trailingText: _formatTime(reminder.time),
                              onTap: _openReminderTimePicker,
                            ),
                          ],

                          const SettingsRowDivider(),
                          SettingsNavRow(
                            icon: Icons.language_rounded,
                            title: context.l10n.settingsLanguage,
                            trailingText: _languageName(localeCode),
                            onTap: _openLanguagePicker,
                          ),

                          const SettingsRowDivider(),
                          SettingsNavRow(
                            icon: _themeModeIcon(themeMode),
                            title: context.l10n.settingsAppearance,
                            trailingText: _themeModeName(context, themeMode),
                            onTap: _openAppearancePicker,
                          ),

                          // Premium-only: pull the whole (legitimately-readable)
                          // catalog + smaczki onto the device so it stays
                          // readable offline. Free users only get the daily +
                          // their reveals, so the action is meaningless for them.
                          if (isPremium) ...[
                            const SettingsRowDivider(),
                            OfflineDownloadRow(localeCode: localeCode),
                          ],

                          if (showFavorites) ...[
                            const SettingsRowDivider(),
                            SettingsNavRow(
                              icon: Icons.star_rounded,
                              iconColor: kGold,
                              title: context.l10n.settingsFavorites,
                              trailingText: favoriteCount > 0
                                  ? '$favoriteCount'
                                  : null,
                              onTap: _openFavorites,
                            ),
                          ],

                          // The PRO history of past dailies + how people voted.
                          // Shown to everyone; the screen gates premium itself,
                          // so a free user lands on the PRO upsell inside it.
                          const SettingsRowDivider(),
                          SettingsNavRow(
                            icon: Icons.history_rounded,
                            title: context.l10n.historyTitle,
                            onTap: () => openHistory(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // ---- Account ----------------------------------------
                      SettingsSectionLabel(context.l10n.settingsSectionAccount),
                      const SizedBox(height: 12),
                      SettingsCard(
                        children: [
                          if (isPremium)
                            PremiumActiveRow(
                              localeCode: localeCode,
                              onTap: _openManageSubscription,
                            )
                          else
                            SettingsNavRow(
                              icon: Icons.star_rounded,
                              iconColor: kGold,
                              title: context.l10n.settingsGoPremium,
                              titleColor: kGold,
                              onTap: _openPaywall,
                            ),
                          const SettingsRowDivider(),
                          SettingsNavRow(
                            icon: Icons.shield_outlined,
                            title: context.l10n.settingsPrivacy,
                            onTap: _openPrivacyData,
                          ),
                          const SettingsRowDivider(),
                          SettingsNavRow(
                            icon: Icons.restore_rounded,
                            title: context.l10n.restorePurchase,
                            onTap: _restorePurchases,
                          ),
                          const SettingsRowDivider(),
                          SettingsNavRow(
                            icon: Icons.info_outline_rounded,
                            title: context.l10n.settingsAbout,
                            trailingText: appInfo?.version,
                            onTap: _openAbout,
                          ),
                        ],
                      ),

                      // ---- Session actions --------------------------------
                      if (hasAccount) ...[
                        const SizedBox(height: 26),
                        SignOutButton(onTap: _signOut, loading: _signingOut),
                        const SizedBox(height: 8),
                        DeleteAccountButton(onTap: _confirmDeleteAccount),
                      ] else ...[
                        const SizedBox(height: 26),
                        SignInButton(onTap: _openAuth),
                      ],

                      // Quiet build stamp at the very bottom, the way mature
                      // apps sign off their settings page.
                      if (appInfo != null) ...[
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            'Debatly · v${appInfo.version} (${appInfo.build})',
                            style: TextStyle(
                              color: context.colors.subtle,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Actions ---------------------------------------------------------------

  /// Shows the RevenueCat paywall, then refreshes the session so the gate sees
  /// the upgrade immediately.
  Future<void> _openPaywall() async {
    final purchased = await PurchasesService.presentPaywall();
    if (!mounted) return;
    if (purchased) {
      await ref.read(sessionProvider.notifier).refresh();
      if (!mounted) return;
      _showMessage(
        context.l10n.settingsPremiumActiveToast,
        type: ToastType.success,
      );
    }
  }

  /// Opens the Manage-subscription sheet. The current entitlement details are
  /// already cached by [premiumStatusProvider]; the sheet refreshes them itself
  /// while it loads so a date that ticked over since open is still correct.
  Future<void> _openManageSubscription() async {
    final localeCode = ref.read(localeControllerProvider).languageCode;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.cardSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ManageSubscriptionSheet(localeCode: localeCode),
    );
  }

  Future<void> _restorePurchases() async {
    final restored = await PurchasesService.restorePurchases();
    if (!mounted) return;
    if (restored) {
      await ref.read(sessionProvider.notifier).refresh();
    }
    if (!mounted) return;
    _showMessage(
      restored ? context.l10n.purchaseRestored : context.l10n.noPreviousPurchase,
      type: restored ? ToastType.success : ToastType.info,
    );
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);

    // signOut() fires Supabase's `signedOut` event, which the session's auth
    // listener turns into a single flash-free refresh() — re-running
    // ensureSignedIn to mint a fresh guest. We deliberately do NOT also
    // `invalidate(sessionProvider)` here: invalidate flips the session to
    // AsyncValue.loading() (nulling userId mid-reload), so the QuestionScreen
    // identity listener fires on account→null→guest instead of a clean
    // account→guest — wiping the feed and flashing the spinner several times
    // before it settles. Letting the listener own the reload gives one smooth
    // transition with a single loader.
    try {
      await SupabaseService.signOut();
    } catch (e) {
      // signOut() already falls back to a local sign-out, so getting here means
      // even that failed — surface it instead of leaving a dead button.
      if (!mounted) return;
      setState(() => _signingOut = false);
      _showMessage(context.l10n.signOutError, type: ToastType.error);
      return;
    }

    if (!mounted) return;
    setState(() => _signingOut = false);
    Navigator.of(context).maybePop();
    _showMessage(context.l10n.signedOut);
  }

  /// Confirms then permanently deletes the account. The destructive action is
  /// behind an explicit two-button dialog; on confirm it runs the deletion under
  /// a blocking spinner, resets the session (so a fresh guest is minted) and
  /// leaves Settings.
  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.cardSurface,
        title: Text(context.l10n.deleteAccountTitle),
        content: Text(context.l10n.deleteAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: kDanger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.deleteAccount),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _performDeleteAccount();
  }

  Future<void> _performDeleteAccount() async {
    // Capture everything that needs `context` BEFORE the await, so we never
    // touch a possibly-unmounted context afterwards (the screen pops on success).
    // The toast rides the *root* overlay, so it survives leaving Settings.
    final navigator = Navigator.of(context);
    final overlay = AppToast.capture(context);
    final successMsg = context.l10n.deleteAccountSuccess;
    final errorMsg = context.l10n.deleteAccountError;

    // Blocking, non-dismissible progress overlay while the server works.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      await SupabaseService.deleteAccount();
      // deleteAccount() ends with a local signOut, whose `signedOut` event the
      // session's auth listener turns into a single flash-free refresh() —
      // re-running ensureSignedIn to mint a fresh guest and rebuild every
      // per-user cache from the new identity. We deliberately do NOT
      // `invalidate(sessionProvider)` here: that flips the session to loading
      // (null userId mid-reload) and trips the identity listener on
      // account→null→guest, flashing the feed instead of a clean transition.
      navigator.pop(); // dismiss the progress overlay
      navigator.maybePop(); // leave Settings, back to the question screen
      AppToast.showOn(overlay, successMsg, type: ToastType.success);
    } catch (e) {
      navigator.pop(); // dismiss the progress overlay
      AppToast.showOn(overlay, errorMsg, type: ToastType.error);
    }
  }

  void _openAuth() => showAuthSheet(context);

  /// Turns the daily reminder on/off. Enabling reuses an existing grant or asks
  /// for one, scheduling + persisting only when granted. A denial (or a system
  /// that no longer prompts) leaves the switch off and shows a message with a
  /// one-tap "Open settings" action; we remember the intent so returning with
  /// permission granted finishes the job. Disabling cancels the schedule.
  Future<void> _onReminderToggled(bool enabled) async {
    if (!enabled) {
      _pendingEnable = false;
      await NotificationService.cancelDailyReminder();
      await ref.read(reminderControllerProvider.notifier).setEnabled(false);
      return;
    }

    // Already granted? Don't prompt again — just schedule. Otherwise ask.
    var granted = await NotificationService.areNotificationsEnabled();
    if (!granted) granted = await NotificationService.requestPermission();
    if (!mounted) return;
    if (!granted) {
      // Remember the intent and route the user to settings; the lifecycle
      // re-check completes the enable when they come back with it granted.
      _pendingEnable = true;
      _showPermissionDeniedMessage();
      return; // leave the switch off — nothing persisted yet
    }

    await _scheduleAndEnable();
  }

  /// Flips the switch on and arms the reminder loop for the stored time. The loop
  /// builder reads the local state itself, so a day the user already voted on
  /// gets a post-vote nudge rather than a "go vote" one.
  Future<void> _scheduleAndEnable() async {
    final l10n = context.l10n;
    await ref.read(reminderControllerProvider.notifier).setEnabled(true);
    await rescheduleReminderLoop(
      prefs: ref.read(sharedPreferencesProvider),
      l10n: l10n,
    );
    _pendingEnable = false;
  }

  /// Reconciles the in-app reminder switch with the real OS permission, on entry
  /// and on every return to the foreground. Two cases it heals:
  ///   * permission revoked while the switch was on → turn it off + cancel, so
  ///     the UI never claims reminders are running when the OS blocks them;
  ///   * the user enabled, got sent to settings, granted, and came back
  ///     ([_pendingEnable]) → finish enabling without a second tap.
  /// No-ops where the plugin isn't live (desktop/web dev, tests).
  Future<void> _syncReminderToggle() async {
    if (!NotificationService.isInitialised) return;
    final enabledOs = await NotificationService.areNotificationsEnabled();
    if (!mounted) return;
    final pref = ref.read(reminderControllerProvider);
    if (_pendingEnable && enabledOs) {
      await _scheduleAndEnable();
      return;
    }
    if (pref.enabled && !enabledOs) {
      await NotificationService.cancelDailyReminder();
      await ref.read(reminderControllerProvider.notifier).setEnabled(false);
    }
  }

  /// Tells the user reminders need the OS permission and offers a one-tap jump to
  /// this app's notification settings — the actionable fix for the "nothing
  /// happened" case where the system no longer shows the permission prompt.
  void _showPermissionDeniedMessage() {
    if (!mounted) return;
    AppToast.show(
      context,
      context.l10n.remindersPermissionDenied,
      type: ToastType.error,
      duration: const Duration(seconds: 6),
      action: (
        label: context.l10n.remindersOpenSettings,
        onPressed: NotificationService.openNotificationSettings,
      ),
    );
  }

  /// Opens a time picker and reschedules the reminder for the chosen time.
  Future<void> _openReminderTimePicker() async {
    final current = ref.read(reminderControllerProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: current.time,
    );
    if (picked == null || !mounted) return;
    // Capture the localizations before the next await — using `context` after an
    // async gap is unsafe.
    final l10n = context.l10n;
    await ref.read(reminderControllerProvider.notifier).setTime(picked);
    await rescheduleReminderLoop(
      prefs: ref.read(sharedPreferencesProvider),
      l10n: l10n,
    );
  }

  /// 24-hour `HH:MM` for the reminder-time row — matches the app's clean numeric
  /// style and reads the same in both languages.
  static String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  /// Human-readable name for a language code, shown as the row's trailing label
  /// and the picker options. Each language is named in itself, the convention
  /// for language menus.
  static String _languageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'pl':
      default:
        return 'Polski';
    }
  }

  /// Opens the language picker and applies the choice.
  ///
  /// Switching the locale rebuilds the app into the new language and re-fetches
  /// the question content (the repository's `p_locale` follows the same source
  /// of truth — see [localeControllerProvider]).
  Future<void> _openLanguagePicker() async {
    final current = ref.read(localeControllerProvider);
    final picked = await showModalBottomSheet<Locale>(
      context: context,
      backgroundColor: context.colors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                context.l10n.chooseLanguage,
                style: TextStyle(
                  color: context.colors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final locale in kSupportedLocales)
              ListTile(
                title: Text(
                  _languageName(locale.languageCode),
                  style: TextStyle(color: context.colors.ink, fontSize: 15),
                ),
                trailing: locale.languageCode == current.languageCode
                    ? const Icon(Icons.check_rounded, color: AppTheme.spark)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(locale),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked != null) {
      await ref.read(localeControllerProvider.notifier).setLocale(picked);

      // Keep the scheduled reminders' text in the newly chosen language. Load
      // the strings for `picked` directly rather than via `context.l10n`, which
      // won't reflect the switch until the next frame.
      final l10n = await AppLocalizations.delegate.load(picked);
      await rescheduleReminderLoop(
        prefs: ref.read(sharedPreferencesProvider),
        l10n: l10n,
      );
    }
  }

  /// Icon mirroring the chosen appearance, shown as the row's leading glyph.
  static IconData _themeModeIcon(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Icons.brightness_auto_rounded,
    ThemeMode.light => Icons.light_mode_rounded,
    ThemeMode.dark => Icons.dark_mode_rounded,
  };

  /// Localized name for an appearance mode — the row's trailing label and the
  /// picker options.
  static String _themeModeName(BuildContext context, ThemeMode mode) =>
      switch (mode) {
        ThemeMode.system => context.l10n.settingsAppearanceSystem,
        ThemeMode.light => context.l10n.settingsAppearanceLight,
        ThemeMode.dark => context.l10n.settingsAppearanceDark,
      };

  /// Opens the appearance picker (System / Light / Dark) and applies the choice.
  ///
  /// Switching the mode rebuilds `MaterialApp`, which re-resolves `themeMode`
  /// and animates the whole UI to the new palette (see [themeControllerProvider]).
  Future<void> _openAppearancePicker() async {
    final current = ref.read(themeControllerProvider);
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: context.colors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                context.l10n.settingsChooseAppearance,
                style: TextStyle(
                  color: context.colors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final mode in ThemeMode.values)
              ListTile(
                leading: Icon(
                  _themeModeIcon(mode),
                  color: context.colors.subtle,
                ),
                title: Text(
                  _themeModeName(context, mode),
                  style: TextStyle(color: context.colors.ink, fontSize: 15),
                ),
                trailing: mode == current
                    ? const Icon(Icons.check_rounded, color: AppTheme.spark)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(mode),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked != null) {
      await ref.read(themeControllerProvider.notifier).setMode(picked);
    }
  }

  /// Pushes the Privacy & data screen — document links plus a plain-language
  /// summary of what the app stores.
  void _openPrivacyData() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PrivacyDataScreen()),
    );
  }

  /// Pushes the About screen — brand mark, version and a one-line summary.
  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
    );
  }

  /// Pushes the Favorites screen — the user's saved questions as cards.
  void _openFavorites() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()),
    );
  }

  void _showMessage(String message, {ToastType type = ToastType.info}) {
    if (!mounted) return;
    AppToast.show(context, message, type: type);
  }
}

// ---- About -----------------------------------------------------------------

/// Reached from the "About" account row: the brand mark, the running version /
/// build (from [appInfoProvider]) and a one-line summary of what the app is.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final info = ref.watch(appInfoProvider).value;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          const TopGlow(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SubScreenHeader(
                        title: l10n.settingsAbout,
                        onClose: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 56),
                      const Center(child: SparkLogo(size: 46)),
                      const SizedBox(height: 22),
                      if (info != null)
                        Center(
                          child: Text(
                            l10n.aboutVersion(info.version, info.build),
                            style: TextStyle(
                              color: context.colors.subtle,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          l10n.aboutTagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.colors.subtle,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Center(
                        child: Text(
                          '© 2026 Debatly',
                          style: TextStyle(color: context.colors.subtle, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Favorites -------------------------------------------------------------

/// Reached from the premium "Favorite questions" row: the user's saved questions
/// as readable cards, each with a share action and a star to remove it.
///
/// The list text comes from [favoriteQuestionsProvider] (favorites are readable
/// forever, so nothing here is ever locked); membership is read live from
/// [favoriteIdsProvider] so removing a card drops it instantly without a refetch.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final favoritesAsync = ref.watch(favoriteQuestionsProvider);
    final liveIds = ref.watch(
      favoriteIdsProvider.select((s) => s.value ?? const <String>{}),
    );

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          const TopGlow(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SubScreenHeader(
                        title: l10n.favoritesTitle,
                        onClose: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 24),
                      favoritesAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (_, _) => _FavoritesEmpty(
                          title: l10n.favoritesEmptyTitle,
                          body: l10n.favoritesEmptyBody,
                        ),
                        data: (questions) {
                          // Honour live membership: a just-removed card is gone
                          // before the provider re-fetches.
                          final visible = questions
                              .where((q) => liveIds.contains(q.id))
                              .toList();
                          if (visible.isEmpty) {
                            return _FavoritesEmpty(
                              title: l10n.favoritesEmptyTitle,
                              body: l10n.favoritesEmptyBody,
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final q in visible) ...[
                                _FavoriteCard(question: q),
                                const SizedBox(height: 14),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One saved question: its full text, a share pill and a filled star that
/// removes it from favorites. Removal is always allowed (curating a list you
/// own), so this never routes through the paywall the way the home star does.
class _FavoriteCard extends ConsumerWidget {
  const _FavoriteCard({required this.question});

  final Question question;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final overlay = AppToast.capture(context);
    final removedMsg = context.l10n.favoriteRemoved;
    final errorMsg = context.l10n.favoriteError;
    try {
      await ref.read(favoriteIdsProvider.notifier).toggle(question.id);
      AppToast.showOn(
        overlay,
        removedMsg,
        type: ToastType.info,
        icon: Icons.star_border_rounded,
      );
    } catch (_) {
      AppToast.showOn(overlay, errorMsg, type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.questionText,
            style: TextStyle(
              color: context.colors.ink,
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShareQuestionButton(questionText: question.questionText),
              IconButton(
                onPressed: () => _remove(context, ref),
                tooltip: context.l10n.favoriteRemoveTooltip,
                icon: const Icon(Icons.star_rounded, color: kGold, size: 26),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Empty/error state for the favorites screen: a muted star and a one-line
/// nudge toward the home-screen star.
class _FavoritesEmpty extends StatelessWidget {
  const _FavoritesEmpty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Icon(
            Icons.star_border_rounded,
            size: 48,
            color: context.colors.subtle,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.subtle,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Privacy & data --------------------------------------------------------

/// Reached from the "Privacy & data" account row. Two parts:
///
/// 1. **Documents** — outbound links to the privacy policy, terms, and the web
///    account-deletion page, opened in the system browser. The URLs default to
///    the live marketing site ([AppConfig.privacyPolicyUrl] /
///    [AppConfig.termsOfServiceUrl] / [AppConfig.deleteAccountUrl]) but each row
///    is still guarded on a non-empty URL, so blanking one via `--dart-define`
///    hides that row rather than showing a dead link.
/// 2. **What we store** — a plain-language summary of the data the app keeps and
///    why, mirroring the categories actually collected (account, activity,
///    purchases, ads).
class PrivacyDataScreen extends StatelessWidget {
  const PrivacyDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasPolicy = AppConfig.hasPrivacyPolicy;
    final hasTerms = AppConfig.hasTermsOfService;
    final hasDeleteUrl = AppConfig.hasDeleteAccountUrl;
    final hasDocs = hasPolicy || hasTerms || hasDeleteUrl;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          const TopGlow(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SubScreenHeader(
                        title: l10n.settingsPrivacy,
                        onClose: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 24),

                      // ---- Documents (only when URLs are configured) --------
                      if (hasDocs) ...[
                        SettingsSectionLabel(l10n.privacyDocsSection),
                        const SizedBox(height: 12),
                        SettingsCard(
                          children: [
                            if (hasPolicy)
                              SettingsNavRow(
                                icon: Icons.description_outlined,
                                title: l10n.privacyPolicy,
                                subtitle: l10n.privacyOpenInBrowser,
                                onTap: () => _openUrl(
                                  context,
                                  AppConfig.privacyPolicyUrl,
                                ),
                              ),
                            if (hasPolicy && hasTerms) const SettingsRowDivider(),
                            if (hasTerms)
                              SettingsNavRow(
                                icon: Icons.gavel_rounded,
                                title: l10n.privacyTerms,
                                subtitle: l10n.privacyOpenInBrowser,
                                onTap: () => _openUrl(
                                  context,
                                  AppConfig.termsOfServiceUrl,
                                ),
                              ),
                            if ((hasPolicy || hasTerms) && hasDeleteUrl)
                              const SettingsRowDivider(),
                            if (hasDeleteUrl)
                              SettingsNavRow(
                                icon: Icons.person_remove_outlined,
                                title: l10n.privacyDeleteAccount,
                                subtitle: l10n.privacyOpenInBrowser,
                                onTap: () => _openUrl(
                                  context,
                                  AppConfig.deleteAccountUrl,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 28),
                      ],

                      // ---- What we store ------------------------------------
                      SettingsSectionLabel(l10n.privacyDataSection),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                        child: Text(
                          l10n.privacyDataIntro,
                          style: TextStyle(
                            color: context.colors.subtle,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                      SettingsCard(
                        children: [
                          _PrivacyDataRow(
                            icon: Icons.person_outline_rounded,
                            title: l10n.privacyDataAccountTitle,
                            body: l10n.privacyDataAccountBody,
                          ),
                          const SettingsRowDivider(),
                          _PrivacyDataRow(
                            icon: Icons.insights_rounded,
                            title: l10n.privacyDataActivityTitle,
                            body: l10n.privacyDataActivityBody,
                          ),
                          const SettingsRowDivider(),
                          _PrivacyDataRow(
                            icon: Icons.workspace_premium_outlined,
                            title: l10n.privacyDataPurchasesTitle,
                            body: l10n.privacyDataPurchasesBody,
                          ),
                          const SettingsRowDivider(),
                          _PrivacyDataRow(
                            icon: Icons.campaign_outlined,
                            title: l10n.privacyDataAdsTitle,
                            body: l10n.privacyDataAdsBody,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens [url] in the system browser, surfacing a snackbar if it can't be
  /// launched (mirrors [_ManageSubscriptionSheet]'s deep-link handling).
  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    final overlay = AppToast.capture(context);
    final failed = context.l10n.privacyLinkFailed;
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened) {
      AppToast.showOn(overlay, failed, type: ToastType.error);
    }
  }
}

/// Left-aligned screen title with a floating close button, matching the
/// profile header but for pushed sub-screens.
/// Non-interactive informational row: icon, title and a wrapping body. Used by
/// the "What we store" summary, so it deliberately has no chevron.
class _PrivacyDataRow extends StatelessWidget {
  const _PrivacyDataRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.colors.subtle, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.colors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    color: context.colors.subtle,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
