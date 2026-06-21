import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pl'),
  ];

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orDivider;

  /// No description provided for @restorePurchase.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase'**
  String get restorePurchase;

  /// No description provided for @purchaseNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Purchase not completed.'**
  String get purchaseNotCompleted;

  /// No description provided for @purchaseRestored.
  ///
  /// In en, this message translates to:
  /// **'Purchase restored.'**
  String get purchaseRestored;

  /// No description provided for @purchaseRestoredCelebrate.
  ///
  /// In en, this message translates to:
  /// **'Purchase restored. 🎉'**
  String get purchaseRestoredCelebrate;

  /// No description provided for @noPreviousPurchase.
  ///
  /// In en, this message translates to:
  /// **'No previous purchase found.'**
  String get noPreviousPurchase;

  /// No description provided for @goPro.
  ///
  /// In en, this message translates to:
  /// **'Go PRO'**
  String get goPro;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signInShort.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInShort;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'EMAIL'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get authPasswordLabel;

  /// No description provided for @authConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'REPEAT PASSWORD'**
  String get authConfirmPasswordLabel;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get authForgotPassword;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get authNoAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authHaveAccount;

  /// No description provided for @authSignUpFree.
  ///
  /// In en, this message translates to:
  /// **'Sign up free'**
  String get authSignUpFree;

  /// No description provided for @authTabSignIn.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get authTabSignIn;

  /// No description provided for @authTabSignUp.
  ///
  /// In en, this message translates to:
  /// **'SIGN UP'**
  String get authTabSignUp;

  /// No description provided for @authEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email.'**
  String get authEnterEmail;

  /// No description provided for @authEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email.'**
  String get authEnterValidEmail;

  /// No description provided for @authEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get authEnterPassword;

  /// No description provided for @authMinPassword.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters.'**
  String get authMinPassword;

  /// No description provided for @authPasswordsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match.'**
  String get authPasswordsMismatch;

  /// No description provided for @authAccountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created.'**
  String get authAccountCreated;

  /// No description provided for @authConfirmEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email and confirm your account.'**
  String get authConfirmEmail;

  /// No description provided for @authAppleSoon.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple — coming soon.'**
  String get authAppleSoon;

  /// No description provided for @authPasswordResetSoon.
  ///
  /// In en, this message translates to:
  /// **'Password reset — coming soon.'**
  String get authPasswordResetSoon;

  /// No description provided for @authMissingSupabaseConfig.
  ///
  /// In en, this message translates to:
  /// **'Supabase configuration is missing. Run the app with SUPABASE_URL and SUPABASE_ANON_KEY.'**
  String get authMissingSupabaseConfig;

  /// No description provided for @authMissingGoogleConfig.
  ///
  /// In en, this message translates to:
  /// **'GOOGLE_SERVER_CLIENT_ID is missing, so Google is temporarily disabled.'**
  String get authMissingGoogleConfig;

  /// No description provided for @settingsSectionApp.
  ///
  /// In en, this message translates to:
  /// **'APP SETTINGS'**
  String get settingsSectionApp;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get settingsSectionAccount;

  /// No description provided for @settingsReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsReminders;

  /// No description provided for @settingsRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A reminder about the daily question'**
  String get settingsRemindersSubtitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get chooseLanguage;

  /// No description provided for @settingsPremiumActive.
  ///
  /// In en, this message translates to:
  /// **'Premium active'**
  String get settingsPremiumActive;

  /// No description provided for @settingsGoPremium.
  ///
  /// In en, this message translates to:
  /// **'Go Premium'**
  String get settingsGoPremium;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data'**
  String get settingsPrivacy;

  /// No description provided for @settingsPremiumActiveToast.
  ///
  /// In en, this message translates to:
  /// **'Premium active. 🎉'**
  String get settingsPremiumActiveToast;

  /// No description provided for @manageSubSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get manageSubSheetTitle;

  /// No description provided for @manageSubStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Premium active'**
  String get manageSubStatusActive;

  /// No description provided for @manageSubStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled — won\'t renew'**
  String get manageSubStatusCancelled;

  /// No description provided for @manageSubRenewsOn.
  ///
  /// In en, this message translates to:
  /// **'Renews on {date}'**
  String manageSubRenewsOn(String date);

  /// No description provided for @manageSubActiveUntil.
  ///
  /// In en, this message translates to:
  /// **'Active until {date}'**
  String manageSubActiveUntil(String date);

  /// No description provided for @manageSubBilledAppStore.
  ///
  /// In en, this message translates to:
  /// **'Billed through the App Store'**
  String get manageSubBilledAppStore;

  /// No description provided for @manageSubBilledPlayStore.
  ///
  /// In en, this message translates to:
  /// **'Billed through Google Play'**
  String get manageSubBilledPlayStore;

  /// No description provided for @manageSubBilledWeb.
  ///
  /// In en, this message translates to:
  /// **'Billed online'**
  String get manageSubBilledWeb;

  /// No description provided for @manageSubNoteAppStore.
  ///
  /// In en, this message translates to:
  /// **'Apple handles billing for your subscription. To change your plan or cancel, open Subscriptions in the App Store — you\'ll keep Premium until the end of the current period.'**
  String get manageSubNoteAppStore;

  /// No description provided for @manageSubNotePlayStore.
  ///
  /// In en, this message translates to:
  /// **'Google handles billing for your subscription. To change your plan or cancel, open Subscriptions in Google Play — you\'ll keep Premium until the end of the current period.'**
  String get manageSubNotePlayStore;

  /// No description provided for @manageSubNoteWeb.
  ///
  /// In en, this message translates to:
  /// **'Manage or cancel your subscription wherever you purchased it. You\'ll keep Premium until the end of the current period.'**
  String get manageSubNoteWeb;

  /// No description provided for @manageSubButtonAppStore.
  ///
  /// In en, this message translates to:
  /// **'Manage in the App Store'**
  String get manageSubButtonAppStore;

  /// No description provided for @manageSubButtonPlayStore.
  ///
  /// In en, this message translates to:
  /// **'Manage in Google Play'**
  String get manageSubButtonPlayStore;

  /// No description provided for @manageSubButtonGeneric.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get manageSubButtonGeneric;

  /// No description provided for @manageSubOpenFailedAppStore.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the App Store. Open Settings › your name › Subscriptions to manage it.'**
  String get manageSubOpenFailedAppStore;

  /// No description provided for @manageSubOpenFailedPlayStore.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open Google Play. Open Play Store › Menu › Subscriptions to manage it.'**
  String get manageSubOpenFailedPlayStore;

  /// No description provided for @manageSubOpenFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the subscription page. Manage it wherever you purchased Premium.'**
  String get manageSubOpenFailedGeneric;

  /// No description provided for @signedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out.'**
  String get signedOut;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account from within the app isn\'t available yet. We\'re working on it — soon you\'ll be able to delete your account and all related data here.'**
  String get deleteAccountBody;

  /// No description provided for @guestSession.
  ///
  /// In en, this message translates to:
  /// **'Guest session'**
  String get guestSession;

  /// No description provided for @signInToSaveProgress.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save your progress'**
  String get signInToSaveProgress;

  /// No description provided for @yourAccount.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get yourAccount;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @comingSoonNamed.
  ///
  /// In en, this message translates to:
  /// **'{label} — coming soon'**
  String comingSoonNamed(String label);

  /// No description provided for @daysInARow.
  ///
  /// In en, this message translates to:
  /// **'DAYS IN A ROW'**
  String get daysInARow;

  /// No description provided for @rankLabel.
  ///
  /// In en, this message translates to:
  /// **'RANK'**
  String get rankLabel;

  /// No description provided for @rankCardTopRank.
  ///
  /// In en, this message translates to:
  /// **'Highest rank'**
  String get rankCardTopRank;

  /// No description provided for @rankCardPromotionReady.
  ///
  /// In en, this message translates to:
  /// **'Promotion ready!'**
  String get rankCardPromotionReady;

  /// No description provided for @rankCardDaysToPromotion.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day to promotion} other{{count} days to promotion}}'**
  String rankCardDaysToPromotion(int count);

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @swipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe to see the next question'**
  String get swipeHint;

  /// No description provided for @dailyShort.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get dailyShort;

  /// No description provided for @loadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load questions'**
  String get loadErrorTitle;

  /// No description provided for @loadErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get loadErrorBody;

  /// No description provided for @goDeeper.
  ///
  /// In en, this message translates to:
  /// **'GO DEEPER'**
  String get goDeeper;

  /// No description provided for @dailyBadge.
  ///
  /// In en, this message translates to:
  /// **'DAILY'**
  String get dailyBadge;

  /// No description provided for @streakTooltip.
  ///
  /// In en, this message translates to:
  /// **'Your streak'**
  String get streakTooltip;

  /// No description provided for @freeUnlockTooltip.
  ///
  /// In en, this message translates to:
  /// **'Free unlock'**
  String get freeUnlockTooltip;

  /// No description provided for @freeUnlockExplain.
  ///
  /// In en, this message translates to:
  /// **'You have one free unlock — swipe to the next question and it unlocks automatically.'**
  String get freeUnlockExplain;

  /// No description provided for @voteYes.
  ///
  /// In en, this message translates to:
  /// **'YES'**
  String get voteYes;

  /// No description provided for @voteNo.
  ///
  /// In en, this message translates to:
  /// **'NO'**
  String get voteNo;

  /// No description provided for @voteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not record your vote.'**
  String get voteFailed;

  /// No description provided for @votesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} vote} other{{count} votes}}'**
  String votesCount(int count);

  /// No description provided for @revealFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reveal the question — please try again.'**
  String get revealFailed;

  /// No description provided for @adLoading.
  ///
  /// In en, this message translates to:
  /// **'The ad is still loading — try again in a moment.'**
  String get adLoading;

  /// No description provided for @adNoReward.
  ///
  /// In en, this message translates to:
  /// **'No reward — watch the whole video to unlock.'**
  String get adNoReward;

  /// No description provided for @noConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection — try again in a moment.'**
  String get noConnection;

  /// No description provided for @noMoreTitle.
  ///
  /// In en, this message translates to:
  /// **'That\'s all the questions for now'**
  String get noMoreTitle;

  /// No description provided for @noMoreBody.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow for a new daily question — or go PRO to read without limits.'**
  String get noMoreBody;

  /// No description provided for @backToDailyQuestion.
  ///
  /// In en, this message translates to:
  /// **'Back to the daily question'**
  String get backToDailyQuestion;

  /// No description provided for @nextQuestionWaiting.
  ///
  /// In en, this message translates to:
  /// **'The next question is waiting'**
  String get nextQuestionWaiting;

  /// No description provided for @watchAdToReveal.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad to reveal a new question.'**
  String get watchAdToReveal;

  /// No description provided for @unlockWithAd.
  ///
  /// In en, this message translates to:
  /// **'Unlock with an ad'**
  String get unlockWithAd;

  /// No description provided for @proActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'PRO active 🎉'**
  String get proActiveTitle;

  /// No description provided for @savePromptBody.
  ///
  /// In en, this message translates to:
  /// **'Your PRO is currently tied to a guest account. Create an account (email or Google) so you don\'t lose access after reinstalling or on another device — your progress will be kept.'**
  String get savePromptBody;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @smaczkiTitle.
  ///
  /// In en, this message translates to:
  /// **'Tidbits'**
  String get smaczkiTitle;

  /// No description provided for @smaczkiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tips to deepen the conversation around this question.'**
  String get smaczkiSubtitle;

  /// No description provided for @smaczkiLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load tidbits.\n{error}'**
  String smaczkiLoadError(String error);

  /// No description provided for @smaczkiEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tidbits for this question yet.'**
  String get smaczkiEmpty;

  /// No description provided for @ranksLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load ranks.'**
  String get ranksLoadError;

  /// No description provided for @rankLadder.
  ///
  /// In en, this message translates to:
  /// **'Rank ladder'**
  String get rankLadder;

  /// No description provided for @yourRankUpper.
  ///
  /// In en, this message translates to:
  /// **'YOUR RANK'**
  String get yourRankUpper;

  /// No description provided for @topRankRespect.
  ///
  /// In en, this message translates to:
  /// **'Top rank — respect.'**
  String get topRankRespect;

  /// No description provided for @streakDays.
  ///
  /// In en, this message translates to:
  /// **'Streak: {count, plural, one{{count} day} other{{count} days}}'**
  String streakDays(int count);

  /// No description provided for @longestStreakDays.
  ///
  /// In en, this message translates to:
  /// **'Longest streak: {count, plural, one{{count} day} other{{count} days}}'**
  String longestStreakDays(int count);

  /// No description provided for @daysToRank.
  ///
  /// In en, this message translates to:
  /// **'{remaining, plural, one{{remaining} more day to “{rankName}”} other{{remaining} more days to “{rankName}”}}'**
  String daysToRank(int remaining, String rankName);

  /// No description provided for @rankFrom.
  ///
  /// In en, this message translates to:
  /// **'{minStreak}+'**
  String rankFrom(int minStreak);

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Spark'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'One sharp question a day — and everything around it.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily question'**
  String get onboardingDailyTitle;

  /// No description provided for @onboardingDailyBody.
  ///
  /// In en, this message translates to:
  /// **'Every day brings a new free question to vote on and sit with.'**
  String get onboardingDailyBody;

  /// No description provided for @onboardingStreakTitle.
  ///
  /// In en, this message translates to:
  /// **'Hot streak'**
  String get onboardingStreakTitle;

  /// No description provided for @onboardingStreakBody.
  ///
  /// In en, this message translates to:
  /// **'Vote each day to keep your flame alive and climb the ranks.'**
  String get onboardingStreakBody;

  /// No description provided for @onboardingUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlocks'**
  String get onboardingUnlockTitle;

  /// No description provided for @onboardingUnlockBody.
  ///
  /// In en, this message translates to:
  /// **'Beyond the daily, reveal more questions with a free credit, an ad, or PRO.'**
  String get onboardingUnlockBody;

  /// No description provided for @onboardingDeeperTitle.
  ///
  /// In en, this message translates to:
  /// **'Go deeper'**
  String get onboardingDeeperTitle;

  /// No description provided for @onboardingDeeperBody.
  ///
  /// In en, this message translates to:
  /// **'Every question comes with tidbits to spark a real conversation.'**
  String get onboardingDeeperBody;

  /// No description provided for @onboardingChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'How do you want to start?'**
  String get onboardingChoiceTitle;

  /// No description provided for @onboardingChoiceBody.
  ///
  /// In en, this message translates to:
  /// **'You can sign in anytime later from settings.'**
  String get onboardingChoiceBody;

  /// No description provided for @onboardingSignInCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in / Sign up'**
  String get onboardingSignInCta;

  /// No description provided for @onboardingSignInHint.
  ///
  /// In en, this message translates to:
  /// **'Save your streak and progress'**
  String get onboardingSignInHint;

  /// No description provided for @onboardingStartAnon.
  ///
  /// In en, this message translates to:
  /// **'Start anonymously'**
  String get onboardingStartAnon;

  /// No description provided for @onboardingStartAnonHint.
  ///
  /// In en, this message translates to:
  /// **'With some limits'**
  String get onboardingStartAnonHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
