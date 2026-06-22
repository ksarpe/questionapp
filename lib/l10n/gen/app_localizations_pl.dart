// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get ok => 'OK';

  @override
  String get later => 'Później';

  @override
  String get cancel => 'Anuluj';

  @override
  String get tryAgain => 'Spróbuj ponownie';

  @override
  String get orDivider => 'LUB';

  @override
  String get restorePurchase => 'Przywróć zakup';

  @override
  String get purchaseNotCompleted => 'Zakup nie został dokończony.';

  @override
  String get purchaseRestored => 'Zakup przywrócony.';

  @override
  String get purchaseRestoredCelebrate => 'Zakup przywrócony. 🎉';

  @override
  String get noPreviousPurchase => 'Nie znaleziono wcześniejszego zakupu.';

  @override
  String get goPro => 'Przejdź na PRO';

  @override
  String get signIn => 'Zaloguj się';

  @override
  String get signInShort => 'Zaloguj';

  @override
  String get authCreateAccount => 'Utwórz konto';

  @override
  String get authEmailLabel => 'EMAIL';

  @override
  String get authPasswordLabel => 'HASŁO';

  @override
  String get authConfirmPasswordLabel => 'POWTÓRZ HASŁO';

  @override
  String get authShowPassword => 'Pokaż hasło';

  @override
  String get authHidePassword => 'Ukryj hasło';

  @override
  String get authForgotPassword => 'Nie pamiętasz hasła?';

  @override
  String get authNoAccount => 'Nie masz konta? ';

  @override
  String get authHaveAccount => 'Masz już konto? ';

  @override
  String get authSignUpFree => 'Załóż za darmo';

  @override
  String get authTabSignIn => 'ZALOGUJ SIĘ';

  @override
  String get authTabSignUp => 'ZAŁÓŻ KONTO';

  @override
  String get authEnterEmail => 'Podaj email.';

  @override
  String get authEnterValidEmail => 'Podaj poprawny email.';

  @override
  String get authEnterPassword => 'Podaj hasło.';

  @override
  String get authMinPassword => 'Minimum 6 znaków.';

  @override
  String get authPasswordsMismatch => 'Hasła nie są takie same.';

  @override
  String get authAccountCreated => 'Konto utworzone.';

  @override
  String get authConfirmEmail => 'Sprawdź email i potwierdź konto.';

  @override
  String get authAppleSoon => 'Logowanie przez Apple — wkrótce.';

  @override
  String get authPasswordResetSoon => 'Reset hasła — wkrótce.';

  @override
  String get authMissingSupabaseConfig =>
      'Brakuje konfiguracji Supabase. Uruchom aplikację z SUPABASE_URL i SUPABASE_ANON_KEY.';

  @override
  String get authMissingGoogleConfig =>
      'Brakuje GOOGLE_SERVER_CLIENT_ID, więc Google jest chwilowo wyłączone.';

  @override
  String get settingsSectionApp => 'USTAWIENIA APLIKACJI';

  @override
  String get settingsSectionAccount => 'KONTO';

  @override
  String get settingsReminders => 'Przypomnienia';

  @override
  String get settingsRemindersSubtitle => 'Przypomnienie o codziennym pytaniu';

  @override
  String get settingsReminderTime => 'Godzina przypomnienia';

  @override
  String get remindersPermissionDenied =>
      'Włącz powiadomienia w ustawieniach systemu, aby otrzymywać przypomnienia.';

  @override
  String get notificationDailyTitle => 'Pytanie dnia czeka 🔥';

  @override
  String get notificationDailyBody => 'Oddaj głos i przedłuż swoją serię.';

  @override
  String get settingsLanguage => 'Język';

  @override
  String get chooseLanguage => 'Wybierz język';

  @override
  String get settingsPremiumActive => 'Premium aktywne';

  @override
  String get settingsGoPremium => 'Przejdź na Premium';

  @override
  String get settingsPrivacy => 'Prywatność i dane';

  @override
  String get privacyDocsSection => 'DOKUMENTY';

  @override
  String get privacyPolicy => 'Polityka prywatności';

  @override
  String get privacyTerms => 'Regulamin';

  @override
  String get privacyOpenInBrowser => 'Otwiera się w przeglądarce';

  @override
  String get privacyLinkFailed => 'Nie udało się otworzyć linku.';

  @override
  String get privacyDataSection => 'CO PRZECHOWUJEMY';

  @override
  String get privacyDataIntro =>
      'Krótki przegląd danych, które przechowuje Spark, i po co.';

  @override
  String get privacyDataAccountTitle => 'Konto i logowanie';

  @override
  String get privacyDataAccountBody =>
      'Twój e-mail lub tożsamość logowania — albo anonimowy identyfikator dla gości — aby Twoje postępy były z Tobą na różnych urządzeniach.';

  @override
  String get privacyDataActivityTitle => 'Aktywność';

  @override
  String get privacyDataActivityBody =>
      'Twoje codzienne głosy, passa i ranga — napędzają pytanie dnia i Twoje postępy.';

  @override
  String get privacyDataPurchasesTitle => 'Zakupy';

  @override
  String get privacyDataPurchasesBody =>
      'Twój status Premium, obsługiwany przez App Store lub Google Play. Nigdy nie widzimy danych Twojej karty.';

  @override
  String get privacyDataAdsTitle => 'Reklamy';

  @override
  String get privacyDataAdsBody =>
      'Użytkownicy darmowi widzą reklamy przez Google AdMob, które mogą używać identyfikatorów urządzenia. Premium całkowicie usuwa reklamy.';

  @override
  String get settingsPremiumActiveToast => 'Premium aktywne. 🎉';

  @override
  String get manageSubSheetTitle => 'Zarządzaj subskrypcją';

  @override
  String get manageSubStatusActive => 'Premium aktywne';

  @override
  String get manageSubStatusCancelled => 'Anulowano — nie odnowi się';

  @override
  String manageSubRenewsOn(String date) {
    return 'Odnowi się $date';
  }

  @override
  String manageSubActiveUntil(String date) {
    return 'Aktywne do $date';
  }

  @override
  String get manageSubBilledAppStore => 'Rozliczane przez App Store';

  @override
  String get manageSubBilledPlayStore => 'Rozliczane przez Google Play';

  @override
  String get manageSubBilledWeb => 'Rozliczane online';

  @override
  String get manageSubNoteAppStore =>
      'Twoją subskrypcją zarządza Apple. Aby zmienić plan lub anulować, otwórz Subskrypcje w App Store — Premium zachowasz do końca bieżącego okresu.';

  @override
  String get manageSubNotePlayStore =>
      'Twoją subskrypcją zarządza Google. Aby zmienić plan lub anulować, otwórz Subskrypcje w Google Play — Premium zachowasz do końca bieżącego okresu.';

  @override
  String get manageSubNoteWeb =>
      'Subskrypcją zarządzaj lub anuluj ją tam, gdzie ją kupiono. Premium zachowasz do końca bieżącego okresu.';

  @override
  String get manageSubButtonAppStore => 'Zarządzaj w App Store';

  @override
  String get manageSubButtonPlayStore => 'Zarządzaj w Google Play';

  @override
  String get manageSubButtonGeneric => 'Zarządzaj subskrypcją';

  @override
  String get manageSubOpenFailedAppStore =>
      'Nie udało się otworzyć App Store. Wejdź w Ustawienia › Twoje imię › Subskrypcje, aby nią zarządzać.';

  @override
  String get manageSubOpenFailedPlayStore =>
      'Nie udało się otworzyć Google Play. Wejdź w Sklep Play › Menu › Subskrypcje, aby nią zarządzać.';

  @override
  String get manageSubOpenFailedGeneric =>
      'Nie udało się otworzyć strony subskrypcji. Zarządzaj nią tam, gdzie kupiono Premium.';

  @override
  String get signedOut => 'Wylogowano.';

  @override
  String get deleteAccountTitle => 'Usunąć konto?';

  @override
  String get deleteAccountBody =>
      'To trwale usunie Twoje konto i wszystkie powiązane dane — serię, głosy i odblokowania. Tej operacji nie można cofnąć. Jeśli masz aktywną subskrypcję Premium, anuluj ją osobno w App Store lub Google Play.';

  @override
  String get deleteAccountSuccess => 'Twoje konto zostało usunięte.';

  @override
  String get deleteAccountError =>
      'Nie udało się usunąć konta. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get guestSession => 'Sesja gościa';

  @override
  String get signInToSaveProgress => 'Zaloguj się, aby zapisać postępy';

  @override
  String get yourAccount => 'Twoje konto';

  @override
  String get signOut => 'Wyloguj się';

  @override
  String get deleteAccount => 'Usuń konto';

  @override
  String comingSoonNamed(String label) {
    return '$label — wkrótce';
  }

  @override
  String get daysInARow => 'DNI Z RZĘDU';

  @override
  String get rankLabel => 'RANGA';

  @override
  String get rankCardTopRank => 'Najwyższa ranga';

  @override
  String get rankCardPromotionReady => 'Awans gotowy!';

  @override
  String rankCardDaysToPromotion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dni do awansu',
      many: '$count dni do awansu',
      few: '$count dni do awansu',
      one: '$count dzień do awansu',
    );
    return '$_temp0';
  }

  @override
  String get settingsTooltip => 'Ustawienia';

  @override
  String get swipeHint => 'Przesuń, aby zobaczyć następne pytanie';

  @override
  String get dailyShort => 'Daily';

  @override
  String get loadErrorTitle => 'Nie udało się załadować pytań';

  @override
  String get loadErrorBody =>
      'Sprawdź połączenie z internetem i spróbuj ponownie.';

  @override
  String get goDeeper => 'WEJDŹ GŁĘBIEJ';

  @override
  String get dailyBadge => 'PYTANIE DNIA';

  @override
  String get streakTooltip => 'Twoja seria';

  @override
  String get freeUnlockTooltip => 'Darmowe odblokowanie';

  @override
  String get freeUnlockExplain =>
      'Masz jedno darmowe odblokowanie — przesuń na kolejne pytanie, a odblokuje się automatycznie.';

  @override
  String get voteYes => 'TAK';

  @override
  String get voteNo => 'NIE';

  @override
  String get voteFailed => 'Nie udało się zagłosować.';

  @override
  String votesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count głosów',
      many: '$count głosów',
      few: '$count głosy',
      one: '$count głos',
    );
    return '$_temp0';
  }

  @override
  String get revealFailed =>
      'Nie udało się odsłonić pytania — spróbuj ponownie.';

  @override
  String get adLoading => 'Reklama jeszcze się ładuje — spróbuj za chwilę.';

  @override
  String get adNoReward =>
      'Brak nagrody — obejrzyj całe wideo, aby odblokować.';

  @override
  String get noConnection => 'Brak połączenia — spróbuj ponownie za chwilę.';

  @override
  String get noMoreTitle => 'To wszystkie pytania na teraz';

  @override
  String get noMoreBody =>
      'Wróć jutro po nowe pytanie dnia — albo przejdź na PRO, by czytać bez limitu.';

  @override
  String get backToDailyQuestion => 'Wróć do pytania dnia';

  @override
  String get nextQuestionWaiting => 'Kolejne pytanie czeka';

  @override
  String get watchAdToReveal => 'Obejrzyj reklamę, aby odsłonić nowe pytanie.';

  @override
  String get unlockWithAd => 'Odblokuj reklamą';

  @override
  String get proActiveTitle => 'PRO aktywne 🎉';

  @override
  String get savePromptBody =>
      'Twoje PRO jest na razie przypisane do konta-gościa. Załóż konto (e-mail lub Google), aby nie stracić dostępu po reinstalacji albo na innym urządzeniu — Twój postęp zostanie zachowany.';

  @override
  String get createAccount => 'Załóż konto';

  @override
  String get smaczkiTitle => 'Smaczki';

  @override
  String get smaczkiSubtitle =>
      'Podpowiedzi, jak pogłębić rozmowę wokół tego pytania.';

  @override
  String smaczkiLoadError(String error) {
    return 'Nie udało się wczytać smaczków.\n$error';
  }

  @override
  String get smaczkiEmpty => 'Do tego pytania nie ma jeszcze smaczków.';

  @override
  String get ranksLoadError => 'Nie udało się wczytać rang.';

  @override
  String get rankLadder => 'Drabinka rang';

  @override
  String get yourRankUpper => 'TWOJA RANGA';

  @override
  String get topRankRespect => 'Najwyższa ranga — szacun.';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dni',
      many: '$count dni',
      few: '$count dni',
      one: '$count dzień',
    );
    return 'Seria: $_temp0';
  }

  @override
  String longestStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dni',
      many: '$count dni',
      few: '$count dni',
      one: '$count dzień',
    );
    return 'Najdłuższa seria: $_temp0';
  }

  @override
  String daysToRank(int remaining, String rankName) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: 'Jeszcze $remaining dni do rangi „$rankName”',
      many: 'Jeszcze $remaining dni do rangi „$rankName”',
      few: 'Jeszcze $remaining dni do rangi „$rankName”',
      one: 'Jeszcze $remaining dzień do rangi „$rankName”',
    );
    return '$_temp0';
  }

  @override
  String rankFrom(int minStreak) {
    return 'od $minStreak';
  }

  @override
  String streakFreezeWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zamrożenie: ranga spadnie za $count dnia',
      many: 'Zamrożenie: ranga spadnie za $count dni',
      few: 'Zamrożenie: ranga spadnie za $count dni',
      one: 'Zamrożenie: ranga spadnie za $count dzień',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'Pomiń';

  @override
  String get onboardingNext => 'Dalej';

  @override
  String get onboardingWelcomeTitle => 'Witaj w Spark';

  @override
  String get onboardingWelcomeBody =>
      'Jedno mocne pytanie dziennie — i wszystko, co je otacza.';

  @override
  String get onboardingDailyTitle => 'Pytanie dnia';

  @override
  String get onboardingDailyBody =>
      'Każdego dnia nowe darmowe pytanie — zagłosuj i zatrzymaj się przy nim na chwilę.';

  @override
  String get onboardingStreakTitle => 'Gorąca passa';

  @override
  String get onboardingStreakBody =>
      'Głosuj każdego dnia, by podtrzymać płomień i piąć się w rankingu.';

  @override
  String get onboardingFreezeTitle => 'Zamrożenie passy';

  @override
  String get onboardingFreezeBody =>
      'Pominiesz dzień? Passa nie przepadnie. Zamrożenie łagodzi przerwę — masz kilka dni, by wrócić, zanim ranga zacznie spadać.';

  @override
  String get onboardingUnlockTitle => 'Odblokowania';

  @override
  String get onboardingUnlockBody =>
      'Poza pytaniem dnia odkrywaj kolejne — darmowym kredytem, reklamą lub z PRO.';

  @override
  String get onboardingDeeperTitle => 'Wejdź głębiej';

  @override
  String get onboardingDeeperBody =>
      'Do każdego pytania dostajesz smaczki, które rozkręcą prawdziwą rozmowę.';

  @override
  String get onboardingChoiceTitle => 'Jak chcesz zacząć?';

  @override
  String get onboardingChoiceBody =>
      'Zalogować się możesz w każdej chwili później, w ustawieniach.';

  @override
  String get onboardingSignInCta => 'Zaloguj / Załóż konto';

  @override
  String get onboardingSignInHint => 'Zapisz passę i postępy';

  @override
  String get onboardingStartAnon => 'Zacznij anonimowo';

  @override
  String get onboardingStartAnonHint => 'Z pewnymi ograniczeniami';
}
