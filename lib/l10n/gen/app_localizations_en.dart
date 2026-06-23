// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get ok => 'OK';

  @override
  String get later => 'Later';

  @override
  String get cancel => 'Cancel';

  @override
  String get tryAgain => 'Try again';

  @override
  String get orDivider => 'OR';

  @override
  String get restorePurchase => 'Restore purchase';

  @override
  String get purchaseNotCompleted => 'Purchase not completed.';

  @override
  String get purchaseRestored => 'Purchase restored.';

  @override
  String get purchaseRestoredCelebrate => 'Purchase restored. 🎉';

  @override
  String get noPreviousPurchase => 'No previous purchase found.';

  @override
  String get goPro => 'Go PRO';

  @override
  String get signIn => 'Sign in';

  @override
  String get signInShort => 'Sign in';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authEmailLabel => 'EMAIL';

  @override
  String get authPasswordLabel => 'PASSWORD';

  @override
  String get authConfirmPasswordLabel => 'REPEAT PASSWORD';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authForgotPassword => 'Forgot your password?';

  @override
  String get authNoAccount => 'Don\'t have an account? ';

  @override
  String get authHaveAccount => 'Already have an account? ';

  @override
  String get authSignUpFree => 'Sign up free';

  @override
  String get authTabSignIn => 'SIGN IN';

  @override
  String get authTabSignUp => 'SIGN UP';

  @override
  String get authEnterEmail => 'Enter your email.';

  @override
  String get authEnterValidEmail => 'Enter a valid email.';

  @override
  String get authEnterPassword => 'Enter your password.';

  @override
  String get authMinPassword => 'At least 6 characters.';

  @override
  String get authPasswordsMismatch => 'Passwords don\'t match.';

  @override
  String get authAccountCreated => 'Account created.';

  @override
  String get authConfirmEmail => 'Check your email and confirm your account.';

  @override
  String get authAppleSoon => 'Sign in with Apple — coming soon.';

  @override
  String get authPasswordResetSoon => 'Password reset — coming soon.';

  @override
  String get authMissingSupabaseConfig =>
      'Supabase configuration is missing. Run the app with SUPABASE_URL and SUPABASE_ANON_KEY.';

  @override
  String get authMissingGoogleConfig =>
      'GOOGLE_SERVER_CLIENT_ID is missing, so Google is temporarily disabled.';

  @override
  String get settingsSectionApp => 'APP SETTINGS';

  @override
  String get settingsSectionAccount => 'ACCOUNT';

  @override
  String get settingsReminders => 'Reminders';

  @override
  String get settingsRemindersSubtitle => 'A reminder about the daily question';

  @override
  String get settingsReminderTime => 'Reminder time';

  @override
  String get remindersPermissionDenied =>
      'Turn on notifications in system settings to get reminders.';

  @override
  String get remindersOpenSettings => 'Open settings';

  @override
  String get notificationDailyTitle => 'Today\'s question is waiting 🔥';

  @override
  String get notificationDailyBody =>
      'Cast your vote and keep your streak alive.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsChooseAppearance => 'Choose appearance';

  @override
  String get settingsAppearanceSystem => 'System';

  @override
  String get settingsAppearanceLight => 'Light';

  @override
  String get settingsAppearanceDark => 'Dark';

  @override
  String get settingsPremiumActive => 'Premium active';

  @override
  String get settingsGoPremium => 'Go Premium';

  @override
  String get settingsPrivacy => 'Privacy & data';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsFavorites => 'Favorite questions';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesEmptyTitle => 'No favorites yet';

  @override
  String get favoritesEmptyBody =>
      'Tap the star on a question to save it here.';

  @override
  String get favoriteAddTooltip => 'Add to favorites';

  @override
  String get favoriteRemoveTooltip => 'Remove from favorites';

  @override
  String get favoriteAdded => 'Added to favorites';

  @override
  String get favoriteRemoved => 'Removed from favorites';

  @override
  String get favoritesPremiumOnly => 'Favorites are a Premium feature.';

  @override
  String get favoriteError => 'Couldn\'t update favorites.';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get aboutTagline =>
      'Thought-provoking questions to spark real conversation.';

  @override
  String get privacyDocsSection => 'DOCUMENTS';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get privacyTerms => 'Terms of service';

  @override
  String get privacyOpenInBrowser => 'Opens in your browser';

  @override
  String get privacyLinkFailed => 'Couldn\'t open the link.';

  @override
  String get privacyDataSection => 'WHAT WE STORE';

  @override
  String get privacyDataIntro =>
      'A quick overview of the data Spark keeps and why.';

  @override
  String get privacyDataAccountTitle => 'Account & sign-in';

  @override
  String get privacyDataAccountBody =>
      'Your email or sign-in identity — or an anonymous ID for guests — so your progress follows you across devices.';

  @override
  String get privacyDataActivityTitle => 'Activity';

  @override
  String get privacyDataActivityBody =>
      'Your daily votes, streak and rank, used to power the daily question and your progress.';

  @override
  String get privacyDataPurchasesTitle => 'Purchases';

  @override
  String get privacyDataPurchasesBody =>
      'Your Premium status, handled through the App Store or Google Play. We never see your card details.';

  @override
  String get privacyDataAdsTitle => 'Ads';

  @override
  String get privacyDataAdsBody =>
      'Free users see ads via Google AdMob, which may use device identifiers. Premium removes ads entirely.';

  @override
  String get settingsPremiumActiveToast => 'Premium active. 🎉';

  @override
  String get manageSubSheetTitle => 'Manage subscription';

  @override
  String get manageSubStatusActive => 'Premium active';

  @override
  String get manageSubStatusCancelled => 'Cancelled — won\'t renew';

  @override
  String manageSubRenewsOn(String date) {
    return 'Renews on $date';
  }

  @override
  String manageSubActiveUntil(String date) {
    return 'Active until $date';
  }

  @override
  String get manageSubBilledAppStore => 'Billed through the App Store';

  @override
  String get manageSubBilledPlayStore => 'Billed through Google Play';

  @override
  String get manageSubBilledWeb => 'Billed online';

  @override
  String get manageSubNoteAppStore =>
      'Apple handles billing for your subscription. To change your plan or cancel, open Subscriptions in the App Store — you\'ll keep Premium until the end of the current period.';

  @override
  String get manageSubNotePlayStore =>
      'Google handles billing for your subscription. To change your plan or cancel, open Subscriptions in Google Play — you\'ll keep Premium until the end of the current period.';

  @override
  String get manageSubNoteWeb =>
      'Manage or cancel your subscription wherever you purchased it. You\'ll keep Premium until the end of the current period.';

  @override
  String get manageSubButtonAppStore => 'Manage in the App Store';

  @override
  String get manageSubButtonPlayStore => 'Manage in Google Play';

  @override
  String get manageSubButtonGeneric => 'Manage subscription';

  @override
  String get manageSubOpenFailedAppStore =>
      'Couldn\'t open the App Store. Open Settings › your name › Subscriptions to manage it.';

  @override
  String get manageSubOpenFailedPlayStore =>
      'Couldn\'t open Google Play. Open Play Store › Menu › Subscriptions to manage it.';

  @override
  String get manageSubOpenFailedGeneric =>
      'Couldn\'t open the subscription page. Manage it wherever you purchased Premium.';

  @override
  String get signedOut => 'Signed out.';

  @override
  String get deleteAccountTitle => 'Delete account?';

  @override
  String get deleteAccountBody =>
      'This permanently deletes your account and all related data — your streak, votes and unlocks. This can\'t be undone. If you have an active Premium subscription, cancel it separately in the App Store or Google Play.';

  @override
  String get deleteAccountSuccess => 'Your account has been deleted.';

  @override
  String get deleteAccountError =>
      'Couldn\'t delete your account. Please check your connection and try again.';

  @override
  String get guestSession => 'Guest session';

  @override
  String get signInToSaveProgress => 'Sign in to save your progress';

  @override
  String get yourAccount => 'Your account';

  @override
  String get signOut => 'Sign out';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String comingSoonNamed(String label) {
    return '$label — coming soon';
  }

  @override
  String get daysInARow => 'DAYS IN A ROW';

  @override
  String get rankLabel => 'RANK';

  @override
  String get rankCardTopRank => 'Highest rank';

  @override
  String get rankCardPromotionReady => 'Promotion ready!';

  @override
  String rankCardDaysToPromotion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days to promotion',
      one: '$count day to promotion',
    );
    return '$_temp0';
  }

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get swipeHint => 'Swipe to see the next question';

  @override
  String get dailyShort => 'Daily';

  @override
  String get loadErrorTitle => 'Couldn\'t load questions';

  @override
  String get loadErrorBody => 'Check your internet connection and try again.';

  @override
  String get goDeeper => 'GO DEEPER';

  @override
  String get dailyBadge => 'DAILY';

  @override
  String get shareLabel => 'Share';

  @override
  String get shareTooltip => 'Share question';

  @override
  String get shareSubject => 'A question from Spark';

  @override
  String shareMessage(String question) {
    return '$question\n\nSpark — thought-provoking questions.';
  }

  @override
  String get shareCardTagline => 'One thought-provoking question a day';

  @override
  String get streakTooltip => 'Your streak';

  @override
  String get freeUnlockTooltip => 'Free unlock';

  @override
  String get freeUnlockExplain =>
      'You have one free unlock — swipe to the next question and it unlocks automatically.';

  @override
  String get voteYes => 'YES';

  @override
  String get voteNo => 'NO';

  @override
  String get voteFailed => 'Could not record your vote.';

  @override
  String votesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '$count vote',
    );
    return '$_temp0';
  }

  @override
  String get revealFailed =>
      'Couldn\'t reveal the question — please try again.';

  @override
  String get adLoading => 'The ad is still loading — try again in a moment.';

  @override
  String get adNoReward => 'No reward — watch the whole video to unlock.';

  @override
  String get noConnection => 'No connection — try again in a moment.';

  @override
  String get noMoreTitle => 'That\'s all the questions for now';

  @override
  String get noMoreBody =>
      'Come back tomorrow for a new daily question — or go PRO to read without limits.';

  @override
  String get backToDailyQuestion => 'Back to the daily question';

  @override
  String get nextQuestionWaiting => 'The next question is waiting';

  @override
  String get watchAdToReveal => 'Watch an ad to reveal a new question.';

  @override
  String get unlockWithAd => 'Unlock with an ad';

  @override
  String get proActiveTitle => 'PRO active 🎉';

  @override
  String get savePromptBody =>
      'Your PRO is currently tied to a guest account. Create an account (email or Google) so you don\'t lose access after reinstalling or on another device — your progress will be kept.';

  @override
  String get createAccount => 'Create account';

  @override
  String get smaczkiTitle => 'Arguments';

  @override
  String get smaczkiSubtitle =>
      'Tips to deepen the conversation around this question.';

  @override
  String smaczkiLoadError(String error) {
    return 'Couldn\'t load tidbits.\n$error';
  }

  @override
  String get smaczkiEmpty => 'No tidbits for this question yet.';

  @override
  String get ranksLoadError => 'Could not load ranks.';

  @override
  String get rankLadder => 'Rank ladder';

  @override
  String get yourRankUpper => 'YOUR RANK';

  @override
  String get topRankRespect => 'Top rank — respect.';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return 'Streak: $_temp0';
  }

  @override
  String longestStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return 'Longest streak: $_temp0';
  }

  @override
  String daysToRank(int remaining, String rankName) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '$remaining more days to “$rankName”',
      one: '$remaining more day to “$rankName”',
    );
    return '$_temp0';
  }

  @override
  String rankFrom(int minStreak) {
    return '$minStreak+';
  }

  @override
  String streakFreezeWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Freeze: rank drops in $count days',
      one: 'Freeze: rank drops in $count day',
    );
    return '$_temp0';
  }

  @override
  String get rankUpEyebrow => 'NEW RANK';

  @override
  String rankUpStreakLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-day streak 🔥',
      one: '$count-day streak 🔥',
    );
    return '$_temp0';
  }

  @override
  String get rankUpDismiss => 'Awesome!';

  @override
  String get rankShareHeadline => 'MY NEW RANK';

  @override
  String rankShareStreakLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-day streak',
      one: '$count-day streak',
    );
    return '$_temp0';
  }

  @override
  String get rankShareSubject => 'My rank in Spark';

  @override
  String rankShareMessage(String rank) {
    return 'My new rank in Spark: $rank 🔥\n\nSpark — thought-provoking questions.';
  }

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Spark';

  @override
  String get onboardingWelcomeBody =>
      'One sharp question a day — and everything around it.';

  @override
  String get onboardingDailyTitle => 'Daily question';

  @override
  String get onboardingDailyBody =>
      'Every day brings a new free question to vote on and sit with.';

  @override
  String get onboardingTasteKicker => 'YOUR TURN';

  @override
  String get onboardingTasteQuestion =>
      'Is emotional cheating worse than physical cheating?';

  @override
  String get onboardingTasteMajority => 'You\'re with the majority. 🙌';

  @override
  String get onboardingTasteMinority => 'You\'re in the minority. 👀';

  @override
  String get onboardingTasteContinue => 'Continue';

  @override
  String get onboardingChoiceTitle => 'How do you want to start?';

  @override
  String get onboardingChoiceBody =>
      'You can sign in anytime later from settings.';

  @override
  String get onboardingSignInCta => 'Sign in / Sign up';

  @override
  String get onboardingSignInHint => 'Save your streak and progress';

  @override
  String get onboardingStartAnon => 'Start anonymously';

  @override
  String get onboardingStartAnonHint => 'With some limits';
}
